#!/usr/bin/env bash
# Secrets and size guard: no secret-shaped strings, no value from .env, no .env file and no file
# over 5 MB in git.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
rc=0
files=$(git ls-files 2>/dev/null)

# 1. No secret-shaped strings in tracked files (this file holds the patterns, so it is skipped).
if [[ -n "$files" ]]; then
  if printf '%s\n' "$files" | grep -vx 'checks/check_scope.sh' | tr '\n' '\0' | xargs -0 -r grep -I -nE \
      'sk-ant-(oat|api)[0-9A-Za-z_-]{6,}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|ghp_[0-9A-Za-z]{20,}|github_pat_[0-9A-Za-z_]{20,}|hf_[0-9A-Za-z]{30,}|AKIA[0-9A-Z]{16}|sk-[0-9A-Za-z]{40,}|xox[baprs]-[0-9A-Za-z-]{10,}' \
      2>/dev/null; then
    echo "  secret-shaped content found in tracked files"; rc=1
  fi
fi

# 2. .env stays out of git, and none of its values appears in a tracked file.
for f in .env .env.local .env.production; do
  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then echo "  $f is tracked by git"; rc=1; fi
done
if [[ -f .env && -n "$files" ]]; then
  python3 -I - <<'PY' || rc=1
import re, subprocess, sys
vals = {}
for line in open(".env", errors="replace"):
    m = re.match(r"\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$", line)
    if m and not line.lstrip().startswith("#"):
        v = m.group(2).strip().strip("\"'")
        if len(v) >= 12:                      # short values (ports, flags, hostnames) are not secrets
            vals[m.group(1)] = v
bad = []
for path in subprocess.run(["git", "ls-files", "-z"], capture_output=True, text=True).stdout.split("\0"):
    if not path:
        continue
    try:
        data = open(path, errors="replace").read()
    except OSError:
        continue
    bad += [f"{path}: contains the value of {k}" for k, v in vals.items() if v in data]
if bad:
    print("  " + "\n  ".join(bad[:10])); sys.exit(1)
PY
fi

# 3. Nothing over 5 MB in git.
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  if (( $(stat -c %s "$f") > 5242880 )); then echo "  file over 5 MB tracked: $f"; rc=1; fi
done <<<"$files"

[[ $rc -eq 0 ]] && echo "  scope clean"
exit $rc
