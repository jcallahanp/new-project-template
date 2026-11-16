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

unset HARNESS_MODEL HARNESS_EFFORT HARNESS_ESCALATE_MODEL HARNESS_FALLBACK_MODEL
for k in DESIGN PLAN WORK VERIFY AUDIT; do unset "HARNESS_MODEL_$k" "HARNESS_EFFORT_$k"; done
export MOCK_STATE="$tmp/mock" HARNESS_CLAUDE="$src/harness/tests/mock_claude" HARNESS_RETRY_WAITS=0,0 HARNESS_LIMIT_POLL=1 \
       HARNESS_EFFORT_VERIFY=medium HARNESS_FALLBACK_MODEL=claude-opus-5-5   # = the Opus legs' own model: they must fall back to Fable
set +e; python3 -I harness/loop.py run --no-push > "$tmp/run.log" 2>&1; rc=$?; set -e
fail() { echo "SELFTEST FAIL: $1"; echo "--- run log ---"; cat "$tmp/run.log"; exit 1; }
[ "$rc" = 0 ] || fail "loop exited $rc, expected 0"
grep -q "DELIVERED" "$tmp/run.log" || fail "no DELIVERED line"
grep -q "Requirements met (acceptance check passes): \*\*2 of 2\*\*" DELIVERY.md || fail "DELIVERY.md does not report 2 of 2"
grep -q "provider error, will retry" "$tmp/run.log" || fail "the provider error was not retried"
grep -q '"FAKE"' ledger.jsonl && fail "a worker's edit to the ledger survived"
grep -q '^exit 0' checks/tasks/M1.T2.sh && fail "a worker's edit to a task check survived"
grep -q '^exit 0' checks/acceptance/R1.sh && fail "a planner's edit to a frozen acceptance check survived"
grep -q "no VERDICT line" "$tmp/run.log" && fail "a VERDICT line wrapped in markdown was not parsed"
[ -f plan/M1.r2.jsonl ] || fail "M1 was not planned again after its acceptance check failed"
grep -q "  -> rejected" "$tmp/run.log" && fail "a plan was rejected (a frozen acceptance check that already passes is not a plan problem)"
grep -q '"id": "M2"' ledger.jsonl || fail "the audit gap did not create a fix milestone"
[ "$(python3 app/sub.py 2 5)" = "-3" ] || fail "the audit gap was not fixed"
[ "$(git branch --show-current)" = "build/selftest-calc" ] || fail "the run did not work on a build branch"
[ -z "$(git status --porcelain)" ] || fail "the run left uncommitted changes"
bash checks/run_gates.sh >/dev/null || fail "gates fail after delivery"
# models per leg kind, escalation on a retried task, fallback on a usage limit, usage on every leg
python3 -I - > "$tmp/legs.txt" 2>&1 <<'PY' || fail "leg records: $(cat "$tmp/legs.txt")"
import json
F, O = "claude-fable-5-2", "claude-opus-5-5"
cards = {c["id"]: c for c in map(json.loads, open("ledger.jsonl"))}
legs = [g for c in cards.values() for g in c.get("legs", [])]
assert {g["kind"] for g in legs} == {"design", "plan", "work", "verify", "audit"}, "not every leg kind was recorded"
for g in legs:
    assert set(g) >= {"kind", "model", "effort", "fallback", "secs", "turns", "input", "output", "cache_read", "cache_write", "cost_usd"}, g
    assert g["model"] == (F if g["kind"] in ("design", "plan", "audit") else O) or g["kind"] == "work" or g["fallback"], f"{g['kind']} leg ran on {g['model']}"
    assert g["effort"] == ("medium" if g["kind"] == "verify" else "high"), f"{g['kind']} effort {g['effort']}"
    if g["kind"] == "audit":
        assert (g["output"], g["cost_usd"]) == (0, None), "absent usage fields were not recorded as 0 / None"
    else:
        assert (g["input"], g["output"], g["cache_read"], g["cache_write"], g["cost_usd"]) == (1000, 200, 5000, 300, 0.125), g
work = lambda tid: [(g["model"], g["fallback"]) for g in cards[tid]["legs"] if g["kind"] == "work"]
assert work("M1.T1") == [(O, False), (F, False)], f"M1.T1 work legs {work('M1.T1')}: want Opus, then Fable on the retry"
assert work("M1.T2") == [(F, True)], f"M1.T2 work legs {work('M1.T2')}: want Fable after the Opus usage limit"
assert work("M1.T3") == [(O, False)], f"M1.T3 work legs {work('M1.T3')}: a short 429 must retry on Opus"
assert work("M2.T1") == [(O, False)], f"M2.T1 work legs {work('M2.T1')}: after a wait with both models limited, back to Opus"
ver = [(g["model"], g["fallback"]) for g in cards["M1.T3"]["legs"] if g["kind"] == "verify"]
assert ver == [(F, True)], f"M1.T3 verify legs {ver}: want Fable after the Opus usage limit"
assert all((g["model"], g["fallback"]) == (O, False) for c in cards.values() if c["id"] != "M1.T3" for g in c.get("legs", []) if g["kind"] == "verify")
others = [w for c in cards.values() if c.get("kind") == "task" and c["id"] not in ("M1.T1", "M1.T2") for w in work(c["id"])]
assert others and all(w == (O, False) for w in others), f"other work legs {others}"
PY
grep -q "usage limit on claude-opus-5-5: running this work leg on claude-fable-5-2" "$tmp/run.log" || fail "the work leg did not fall back on a usage limit"
grep -q "usage limit on claude-opus-5-5: running this verify leg on claude-fable-5-2" "$tmp/run.log" || fail "the verify leg did not fall back on a usage limit"
[ "$(grep -c 'waiting 1s: usage limit' "$tmp/run.log")" = 2 ] || fail "want two usage-limit waits (the plan leg, M2.T1 with both models limited), none for a fallback or a 429"
[ "$(grep '^PLANNER' "$MOCK_STATE/calls" | head -2 | sort -u)" = "PLANNER claude-fable-5-2 high -" ] || fail "the plan leg did not wait and retry on Fable"
[ "$(grep '^WORKER .* M2.T1$' "$MOCK_STATE/calls" | cut -d' ' -f2 | tr '\n' ' ')" = "claude-opus-5-5 claude-fable-5-2 claude-opus-5-5 " ] || fail "M2.T1: want Opus, Fable (both limited), then Opus after the wait"
[ "$(grep '^WORKER .* M1.T3$' "$MOCK_STATE/calls" | cut -d' ' -f2 | tr '\n' ' ')" = "claude-opus-5-5 claude-opus-5-5 " ] || fail "M1.T3: a short 429 must be retried on the same model"
grep -q "provider error, will retry (API Error: 429" "$tmp/run.log" || fail "the short 429 was not retried as a provider error"
grep -q '^- usage: work claude-opus-5-5 effort high: in 1000, out 200, cache read 5000, cache write 300 tokens, ~\$0.12' PROGRESS.md || fail "PROGRESS.md has no usage line for a work leg"
grep -q '^- usage: work claude-fable-5-2 (fallback after a usage limit)' PROGRESS.md || fail "PROGRESS.md does not show the fallback"
python3 -I harness/loop.py status > "$tmp/status.txt" 2>&1
grep -Eq '^  work +claude-opus-5-5 +[0-9]+ legs +[0-9,]+ output tokens +~\$' "$tmp/status.txt" || fail "status shows no usage per leg kind and model: $(cat "$tmp/status.txt")"
grep -Eq '^  audit +claude-fable-5-2 +2 legs' "$tmp/status.txt" || fail "status does not count the audit legs: $(cat "$tmp/status.txt")"
# env precedence: kind variable > HARNESS_MODEL > default; escalation unless HARNESS_MODEL_WORK is set
python3 -I - > "$tmp/env.txt" 2>&1 <<'PY' || fail "model/effort env precedence: $(cat "$tmp/env.txt")"
import os, sys
sys.path.insert(0, "harness")
import loop
F, O = loop.FABLE, loop.OPUS
def with_env(env, fn, *a):
    for k in [k for k in os.environ if k.startswith(("HARNESS_MODEL", "HARNESS_EFFORT", "HARNESS_ESCALATE", "HARNESS_FALLBACK"))]:
        del os.environ[k]
    os.environ.update(env)
    return fn(*a)
m = loop.model_for
assert [with_env({}, m, k) for k in ("design", "plan", "work", "verify", "audit")] == [F, F, O, O, F]
assert with_env({"HARNESS_MODEL": O}, m, "plan") == O and with_env({"HARNESS_MODEL": O}, m, "audit") == O
assert with_env({"HARNESS_MODEL": O, "HARNESS_MODEL_PLAN": F}, m, "plan") == F
assert with_env({"HARNESS_MODEL": O}, m, "work", 2) == F, "HARNESS_MODEL alone must not stop escalation"
assert with_env({"HARNESS_MODEL_WORK": O}, m, "work", 3) == O, "HARNESS_MODEL_WORK must stop escalation"
assert with_env({"HARNESS_ESCALATE_MODEL": "x"}, m, "work", 2) == "x"
assert with_env({}, loop.effort_for, "work") == "high" and with_env({"HARNESS_EFFORT": ""}, loop.effort_for, "plan") == ""
assert with_env({"HARNESS_EFFORT": "low", "HARNESS_EFFORT_AUDIT": "max"}, loop.effort_for, "audit") == "max"
assert with_env({}, loop.fallback_model, F) == O and with_env({}, loop.fallback_model, O) == F
assert with_env({"HARNESS_FALLBACK_MODEL": "y"}, loop.fallback_model, O) == "y"
assert with_env({"HARNESS_FALLBACK_MODEL": F}, loop.fallback_model, F) == O, "an escalated Fable leg must still fall back to Opus"
assert loop.classify('API Error: 429 {"error":{"type":"rate_limit_error"}}') == "transient" and loop.classify("Rate limit reached") == "transient"
assert loop.classify("Claude AI usage limit reached · resets 3am") == "limit" and loop.classify("5-hour limit reached ∙ resets 3am") == "limit"
PY
# a spec edited after approval must stop the next run before it starts
sed -i 's/"anything beyond integers"/"anything beyond whole numbers"/' spec/requirements.json; git commit -q -am "edit spec"
if python3 -I harness/loop.py run --no-push >/dev/null 2>&1; then fail "the loop started with a spec that changed after approval"; fi
echo "SELFTEST PASS ($(grep -c '^[0-9:]* leg ' "$tmp/run.log") legs: design, plan after a limit wait, work with escalation, 429 retry and limit fallback, verify with fallback, replan, audit gap, fix, audit, deliver; usage recorded)"
