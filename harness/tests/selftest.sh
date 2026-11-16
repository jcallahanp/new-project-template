#!/usr/bin/env bash
# Proves the loop's state machine without calling a model: copies the harness into a temp repo, approves
# a two-requirement spec, runs the whole loop against harness/tests/mock_claude and checks the outcome.
# The mock misbehaves on purpose (see its docstring), so this also proves the loop's defences.
set -euo pipefail
src="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"; mkdir -p "$repo/spec" "$repo/plan" "$repo/notes" "$repo/checks/tasks" "$repo/checks/acceptance"
cp -r "$src/harness" "$src/.claude" "$src/CLAUDE.md" "$src/.gitignore" "$repo/"
cp "$src"/checks/run_gates.sh "$src"/checks/check_scope.sh "$src"/checks/check_progress.sh "$src"/checks/check_protected.sh "$repo/checks/"
git -C "$src" show HEAD:checks/check_project.sh > "$repo/checks/check_project.sh" 2>/dev/null || cp "$src/checks/check_project.sh" "$repo/checks/check_project.sh"
grep -q "written by the design session" "$repo/checks/check_project.sh" || printf '#!/usr/bin/env bash\necho "  placeholder"; exit 0\n' > "$repo/checks/check_project.sh"
cd "$repo"; : > ledger.jsonl; printf '# Progress log\n' > PROGRESS.md
cat > spec/requirements.json <<'JSON'
{"project": "selftest-calc", "summary": "Two tiny command-line calculators used only to prove that the build loop works from an approved spec to a delivery report.",
 "users": ["the harness self-test"],
 "requirements": [
  {"id": "R1", "priority": "must", "story": "As a tester, I want to add two integers so that I can see a sum.",
   "statement": "When app/add.py is run with two integers, the system shall print their sum on one line.",
   "examples": [{"given": "the program exists", "when": "it is run with 2 and 3", "then": "it prints 5"}],
   "verify": "Run python3 app/add.py 2 3 and compare the output with 5."},
  {"id": "R2", "priority": "must", "story": "As a tester, I want to subtract two integers so that I can see a difference.",
   "statement": "When app/sub.py is run with two integers, the system shall print the first minus the second on one line.",
   "examples": [{"given": "the program exists", "when": "it is run with 2 and 5", "then": "it prints -3"}],
   "verify": "Run python3 app/sub.py 2 5 and compare the output with -3."}],
 "non_goals": ["anything beyond integers"], "constraints": ["Python 3 standard library only"], "assumptions": [],
 "deploy": {"target": "none (self-test)", "ready_when": ["both programs run from a fresh clone"]},
 "secrets": [], "human_gates": [], "open_questions": []}
JSON
git init -q -b main; git config user.name selftest; git config user.email selftest@example.invalid
git add -A; git commit -q -m "template"
python3 -I harness/spec.py approve >/dev/null
git init -q --bare "$tmp/origin.git"; git remote add origin "$tmp/origin.git"; git push -q -u origin main

export MOCK_STATE="$tmp/mock" HARNESS_CLAUDE="$src/harness/tests/mock_claude" HARNESS_RETRY_WAITS=0,0 HARNESS_EFFORT=
set +e; python3 -I harness/loop.py run --no-push > "$tmp/run.log" 2>&1; rc=$?; set -e
fail() { echo "SELFTEST FAIL: $1"; echo "--- run log ---"; cat "$tmp/run.log"; exit 1; }
[ "$rc" = 0 ] || fail "loop exited $rc, expected 0"
grep -q "DELIVERED" "$tmp/run.log" || fail "no DELIVERED line"
grep -q "Requirements met (acceptance check passes): \*\*2 of 2\*\*" DELIVERY.md || fail "DELIVERY.md does not report 2 of 2"
grep -q "provider error, will retry" "$tmp/run.log" || fail "the provider error was not retried"
grep -q '"FAKE"' ledger.jsonl && fail "a worker's edit to the ledger survived"
grep -q '^exit 0' checks/tasks/M1.T2.sh && fail "a worker's edit to a task check survived"
grep -q '^exit 0' checks/acceptance/R1.sh && fail "a planner's edit to a frozen acceptance check survived"
grep -q '"id": "M2"' ledger.jsonl || fail "the audit gap did not create a fix milestone"
[ "$(python3 app/sub.py 2 5)" = "-3" ] || fail "the audit gap was not fixed"
[ "$(git branch --show-current)" = "build/selftest-calc" ] || fail "the run did not work on a build branch"
[ -z "$(git status --porcelain)" ] || fail "the run left uncommitted changes"
bash checks/run_gates.sh >/dev/null || fail "gates fail after delivery"
# a spec edited after approval must stop the next run before it starts
sed -i 's/"anything beyond integers"/"anything beyond whole numbers"/' spec/requirements.json; git commit -q -am "edit spec"
if python3 -I harness/loop.py run --no-push >/dev/null 2>&1; then fail "the loop started with a spec that changed after approval"; fi
echo "SELFTEST PASS ($(grep -c '^[0-9:]* leg ' "$tmp/run.log") legs: design, plan, work, verify, audit gap, fix, audit, deliver)"
