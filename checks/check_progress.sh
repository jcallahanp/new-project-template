#!/usr/bin/env bash
# Record invariants: nothing is `done` without a commit and a passing check on record, nothing is
# `blocked` without a reason, and PROGRESS.md is append-only.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
rc=0
python3 -I - <<'PY' || rc=1
import json, sys
states = {"todo", "doing", "blocked", "done"}
ids, bad, rows = set(), [], []
for n, line in enumerate(open("ledger.jsonl"), 1):
    if not line.strip():
        continue
    try:
        t = json.loads(line)
    except ValueError:
        bad.append(f"ledger line {n}: not valid JSON"); continue
    rows.append(t)
    if t.get("id") in ids:
        bad.append(f"{t.get('id')}: duplicate id")
    ids.add(t.get("id"))
for t in rows:
    tid, st = t.get("id"), t.get("state")
    if st not in states:
        bad.append(f"{tid}: invalid state {st!r}")
    if t.get("kind") == "task" and st == "done" and (not t.get("commit") or t.get("checks") != "pass"):
        bad.append(f"{tid}: done without a commit and checks==pass")
    if st == "blocked" and not t.get("note"):
        bad.append(f"{tid}: blocked without a reason in note")
    for dep in t.get("depends_on", []):
        if dep not in ids:
            bad.append(f"{tid}: depends_on unknown task {dep}")
    if t.get("kind") == "task" and t.get("parent") not in ids:
        bad.append(f"{tid}: parent milestone missing")
if bad:
    print("  " + "\n  ".join(bad)); sys.exit(1)
print(f"  {len(rows)} ledger entries, invariants hold")
PY
if git rev-parse -q --verify origin/main >/dev/null 2>&1 && git cat-file -e origin/main:PROGRESS.md 2>/dev/null; then
  base=$(git show origin/main:PROGRESS.md | wc -c)
  if ! cmp -s <(git show origin/main:PROGRESS.md) <(head -c "$base" PROGRESS.md); then
    echo "  PROGRESS.md was rewritten: entries already on origin/main changed (append only)"; rc=1
  else echo "  PROGRESS.md append-only ok"; fi
fi
exit $rc
