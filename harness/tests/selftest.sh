#!/usr/bin/env bash
# Proves the loop's state machine without calling a model: copies the harness into a temp repo, approves
# a two-requirement spec, runs the whole loop against harness/tests/mock_claude and checks the outcome.
# The mock misbehaves on purpose (see its docstring), so this also proves the loop's defences.
set -euo pipefail
src="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
grep -q -- '--template jcallahanp/new-project-template ' "$src/README.md" || { echo "SELFTEST FAIL: README.md does not create projects from jcallahanp/new-project-template"; exit 1; }
make_repo() {   # $1: a new directory; ends inside it with the template committed on main, the spec approved
repo="$1"; mkdir -p "$repo/spec" "$repo/plan" "$repo/notes" "$repo/checks/tasks" "$repo/checks/acceptance"
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
python3 -I harness/spec.py approve >/dev/null || { echo "SELFTEST FAIL: the self-test spec does not pass spec.py check:"; python3 -I harness/spec.py check; exit 1; }
git init -q --bare "$repo.origin.git"; git remote add origin "$repo.origin.git"; git push -q -u origin main
}
make_repo "$tmp/repo"

# numbers with a unit in a statement need a limits entry (hard or target, margin, measure); the self-test spec has none.
# Numbers in examples need none; "3 s" matches a limit in "seconds"; a number named twice is reported once.
mkdir -p "$tmp/lim/spec"; cp -r harness "$tmp/lim/"
lim_spec() {   # $1: the R1 limits as JSON, or "" for none; writes the self-test spec with "600 MB" (twice) and "3 s" in R1
python3 -I - "$1" > "$tmp/lim/spec/requirements.json" <<'PY'
import json, sys
s = json.load(open("spec/requirements.json"))
r = s["requirements"][0]
r["statement"] = "When app/add.py is run with two integers, the system shall print their sum within 3 s using under 600 MB of memory (600 MB in total)."
r["examples"][0]["then"] = "it prints 5 and the memory banner shows 1040 MB"
if sys.argv[1]:
    r["limits"] = json.loads(sys.argv[1])
print(json.dumps(s))
PY
}
lim_spec ""
python3 -I "$tmp/lim/harness/spec.py" check > "$tmp/lim.txt" 2>&1 && { echo "SELFTEST FAIL: \"under 600 MB\" with no limits entry passed spec.py check"; exit 1; }
grep -q 'R1: "600 MB" needs a `limits` entry' "$tmp/lim.txt" || { echo "SELFTEST FAIL: no clear problem for 600 MB: $(cat "$tmp/lim.txt")"; exit 1; }
[ "$(grep -c '"600 MB" needs' "$tmp/lim.txt")" = 1 ] || { echo "SELFTEST FAIL: 600 MB is not reported exactly once: $(cat "$tmp/lim.txt")"; exit 1; }
lim_spec '[{"name": "memory", "value": 600, "unit": "MB", "kind": "target", "measure": "peak RSS during a 2-minute run, median of 3 runs"}]'
python3 -I "$tmp/lim/harness/spec.py" check > "$tmp/lim.txt" 2>&1 && { echo "SELFTEST FAIL: a target limit without a margin passed spec.py check"; exit 1; }
lim_spec '[{"name": "memory", "value": 600, "unit": "MB", "kind": "target", "margin": "10%", "measure": "peak RSS during a 2-minute run, median of 3 runs"},
          {"name": "time", "value": 3, "unit": "seconds", "kind": "hard", "margin": 0, "measure": "wall time of one run, taken once"}]'
python3 -I "$tmp/lim/harness/spec.py" render > "$tmp/lim.txt" 2>&1 || { echo "SELFTEST FAIL: a proper target limit was rejected: $(cat "$tmp/lim.txt")"; exit 1; }
grep -q '^- memory: 600 MB, target (passes up to 600 MB + 10%); measured: peak RSS' "$tmp/lim/spec/REQUIREMENTS.md" || { echo "SELFTEST FAIL: render does not show the limit"; exit 1; }

unset HARNESS_MODEL HARNESS_EFFORT HARNESS_ESCALATE_MODEL HARNESS_FALLBACK_MODEL
unset BAO_TOKEN SECRET_PROJECT        # the state-machine runs use .env; the vault part below sets up its own fake
for k in DESIGN PLAN WORK VERIFY JUDGE AUDIT; do unset "HARNESS_MODEL_$k" "HARNESS_EFFORT_$k"; done
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
assert work("M2.T1") == [(O, False)], f"M2.T1 work legs {work('M2.T1')}: after a persistent 429, a limited fallback and a wait, back to Opus"
ver = [(g["model"], g["fallback"]) for g in cards["M1.T3"]["legs"] if g["kind"] == "verify"]
assert ver == [(F, True)], f"M1.T3 verify legs {ver}: want Fable after the Opus usage limit"
assert all((g["model"], g["fallback"]) == (O, False) for c in cards.values() if c["id"] != "M1.T3" for g in c.get("legs", []) if g["kind"] == "verify")
others = [w for c in cards.values() if c.get("kind") == "task" and c["id"] not in ("M1.T1", "M1.T2") for w in work(c["id"])]
assert others and all(w == (O, False) for w in others), f"other work legs {others}"
PY
grep -q "usage limit on claude-opus-5-5: running this work leg on claude-fable-5-2" "$tmp/run.log" || fail "the work leg did not fall back on a usage limit"
grep -q "usage limit on claude-opus-5-5: running this verify leg on claude-fable-5-2" "$tmp/run.log" || fail "the verify leg did not fall back on a usage limit"
[ "$(grep -c 'waiting 1s: usage limit' "$tmp/run.log")" = 2 ] || fail "want two usage-limit waits (the plan leg, M2.T1 with both models limited), none for a fallback or a 429"
[ "$(grep -c 'waiting 1s: rate limit that outlasted the retries' "$tmp/run.log")" = 1 ] || fail "the M1 round-2 plan leg did not wait out a persistent 429"
grep -q "provider error, will retry (API Error: 529 overloaded" "$tmp/run.log" || fail "the 529 after the long wait was not retried"
grep -q "rate limit that outlasted the retries on claude-opus-5-5: running this work leg on claude-fable-5-2" "$tmp/run.log" || fail "a persistent 429 on a work leg did not fall back"
[ "$(grep '^PLANNER' "$MOCK_STATE/calls" | head -2 | sort -u)" = "PLANNER claude-fable-5-2 high -" ] || fail "the plan leg did not wait and retry on Fable"
[ "$(grep '^WORKER .* M2.T1$' "$MOCK_STATE/calls" | cut -d' ' -f2 | tr '\n' ' ')" = "claude-opus-5-5 claude-opus-5-5 claude-opus-5-5 claude-fable-5-2 claude-opus-5-5 " ] || fail "M2.T1: want Opus x3 (429), Fable (limited), then Opus after the wait"
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
# a third fallback model: the leg tries its own model and that one, then waits and starts again on its own
calls, script = [], iter(["limit", "limit", None])
loop.run_claude = lambda kind, prompt, model, effort: calls.append(model) or {"err": next(script), "text": "usage limit"}
loop.git, loop.sh, loop.pause = (lambda *a, **k: ""), (lambda *a, **k: None), (lambda *a: calls.append("wait"))
r = with_env({"HARNESS_FALLBACK_MODEL": "x"}, loop.session, "work", "brief", "HEAD")
assert calls == [O, "x", "wait", O] and not r["fallback"], calls
assert loop.classify('API Error: 429 {"error":{"type":"rate_limit_error"}}') == "rate" and loop.classify("Rate limit reached") == "rate"
assert loop.classify("API Error: 529 overloaded") == "transient"
assert loop.classify("Claude AI usage limit reached · resets 3am") == "limit" and loop.classify("5-hour limit reached ∙ resets 3am") == "limit"
PY
# a spec edited after approval must stop the next run before it starts
sed -i 's/"anything beyond integers"/"anything beyond whole numbers"/' spec/requirements.json; git commit -q -am "edit spec"
if python3 -I harness/loop.py run --no-push >/dev/null 2>&1; then fail "the loop started with a spec that changed after approval"; fi

# "check is wrong" path (MOCK_SCENARIO=judge, see mock_claude): a fresh repo, a fake notify-send that logs to the mock's calls
make_repo "$tmp/repo2"
mkdir -p "$tmp/bin"; printf '#!/bin/sh\necho "NOTIFY $*" >> "$MOCK_STATE/calls"\n' > "$tmp/bin/notify-send"; chmod +x "$tmp/bin/notify-send"
set +e; MOCK_SCENARIO=judge MOCK_STATE="$tmp/mock2" PATH="$tmp/bin:$PATH" python3 -I harness/loop.py run --no-push > "$tmp/run.log" 2>&1; rc=$?; set -e
calls="$tmp/mock2/calls"
[ "$rc" = 3 ] || fail "judge run: loop exited $rc, expected 3 (M1 blocked by M1.T1)"
python3 -I - > "$tmp/judge.txt" 2>&1 <<'PY2' || fail "judge run ledger: $(cat "$tmp/judge.txt")"
import json
cards = {c["id"]: c for c in map(json.loads, open("ledger.jsonl"))}
t1, t2, t3 = cards["M1.T1"], cards["M1.T2"], cards["M1.T3"]
assert (t1["state"], t1["attempts"]) == ("blocked", 2), f"M1.T1 {t1['state']} after {t1['attempts']} attempts: want blocked at once on attempt 2"
assert t1["note"].startswith("check wrong (judge agreed): JUDGE-T1-REASON"), t1["note"]
assert (t2["state"], t3["state"], t3["attempts"]) == ("done", "done", 2), f"other tasks did not run on: {t2['state']}, {t3['state']} ({t3['attempts']})"
assert [g["kind"] for g in t3["legs"]] == ["work", "work", "judge", "work", "verify"], [g["kind"] for g in t3["legs"]]
assert [g["kind"] for g in t1["legs"]] == ["work", "work", "judge"], [g["kind"] for g in t1["legs"]]
j = [g for g in t1["legs"] + t3["legs"] if g["kind"] == "judge"]
assert all((g["model"], g["effort"], g["output"]) == ("claude-fable-5-2", "high", 200) for g in j), j
PY2
[ "$(grep '^JUDGE' "$calls" | cut -d' ' -f2,4 | tr '\n' ' ')" = "claude-fable-5-2 M1.T1 claude-fable-5-2 M1.T3 " ] \
  || fail "want one judge leg for M1.T1 and one for M1.T3, both on attempt 2 (a claim on attempt 1 is ignored): $(grep '^JUDGE' "$calls")"
first_notify=$(grep -n '^NOTIFY' "$calls" | head -1 | cut -d: -f1); t2_work=$(grep -n '^WORKER .* M1.T2$' "$calls" | head -1 | cut -d: -f1)
[ -n "$first_notify" ] && [ "$first_notify" -lt "$t2_work" ] || fail "John was not notified at once when the judge agreed: $(cat "$calls")"
grep -q 'M1.T1 blocked, its check needs John' .harness-run/alerts.log || fail "the alert is not in .harness-run/alerts.log"
grep '^NOTIFY' "$calls" | head -1 | grep -q 'M1.T1 blocked, its check needs John: check wrong (judge agreed)' || fail "notification text: $(grep '^NOTIFY' "$calls")"
grep -q 'JUDGE-T3-REASON' "$tmp/mock2/WORKER-M1.T3-3.txt" || fail "the judge's reason for CHECK-OK is not in the next attempt's brief"
grep -q 'JUDGE-T3-REASON' "$tmp/mock2/WORKER-M1.T3-2.txt" && fail "mock: the judge's reason appeared before the judge ran"
grep -q 'MARKER-T2-CHECK-OUTPUT sub ran' "$tmp/mock2/VERIFIER-M1.T2-1.txt" || fail "the verify brief does not carry the loop's check output"
grep -q '  PASS' "$tmp/mock2/VERIFIER-M1.T2-1.txt" || fail "the verify brief does not carry the loop's gate output"
# Secrets (C10): a fake `secret` helper with two projects; the other project's token is in the shell (never used).
# The project's spec secrets (a multi-line one too) reach checks and run sessions, the other project's keys do not, a
# session's `secret set` is seen by a later check, check_scope catches a vault value or BAO_TOKEN in a tracked file and
# in a commit not yet on origin/main, vault reads are retried, and a vault that does not answer stops the run cleanly.
make_repo "$tmp/repo3"
python3 -I - <<'PY'
import json
s = json.load(open("spec/requirements.json"))
s["secrets"] = [{"name": "SC_API_KEY", "purpose": "the calculator's API key, supplied by John"},
                {"name": "PEM_KEY", "purpose": "a multi-line key, supplied by John"},
                {"name": "AGENT_KEY", "purpose": "a key a run session creates in a web dashboard", "created_by": "agent"},
                {"name": "OTHER_KEY", "purpose": "exists only in another project's vault", "created_by": "agent"}]
json.dump(s, open("spec/requirements.json", "w"))
PY
git commit -q -am "spec: secrets"; python3 -I harness/spec.py approve >/dev/null || fail "a spec with created_by does not pass spec.py"
mkdir -p "$tmp/vbin" "$tmp/home/.config/openbao" "$tmp/home-empty" "$tmp/mock3" "$tmp/mock4"
cp "$src/harness/tests/fake_secret" "$tmp/vbin/secret"
n=$(date +%s%N)   # values made here, so no tracked file holds them
export EXPECT_SC="vault-sc-$n" EXPECT_PEM=$'-----BEGIN TEST KEY-----\nline-one-'"$n"$'\nline-two\n-----END TEST KEY-----' \
       MOCK_AGENT_VALUE="agent-key-$n" EXPECT_TOK="tok-calc-$n"
printf '%s\n' "$EXPECT_TOK" > "$tmp/home/.config/openbao/selftest-calc.token"
python3 -I -c 'import json, os, sys; json.dump({"selftest-calc": {"token": os.environ["EXPECT_TOK"], "keys": {"SC_API_KEY": os.environ["EXPECT_SC"],
  "PEM_KEY": os.environ["EXPECT_PEM"]}}, "other": {"token": "tok-other", "keys": {"OTHER_KEY": "other-project-value"}}}, open(sys.argv[1], "w"))' "$tmp/vault.json"
vault_env=(HOME="$tmp/home" PATH="$tmp/vbin:$PATH" FAKE_VAULT="$tmp/vault.json" BAO_TOKEN=tok-other SECRET_PROJECT=other
           HARNESS_VAULT_WAITS=0,0 MOCK_STATE="$tmp/mock3" MOCK_SCENARIO=vault HARNESS_CLAUDE="$src/harness/tests/mock_claude")
env "${vault_env[@]}" python3 -I harness/spec.py secrets > "$tmp/sec.txt" 2>&1 || fail "spec.py secrets with the vault: $(cat "$tmp/sec.txt")"
grep -q '^ok    vault project selftest-calc answers' "$tmp/sec.txt" && grep -q '^note  .*a run session creates and stores them: AGENT_KEY, OTHER_KEY' "$tmp/sec.txt" \
  || fail "spec.py secrets does not report the vault and the agent's keys: $(cat "$tmp/sec.txt")"
env "${vault_env[@]}" python3 -I - > "$tmp/vault.txt" 2>&1 <<'PY' || fail "vault: $(cat "$tmp/vault.txt")"
import os, sys
sys.path.insert(0, "harness")
import loop
st = os.environ["MOCK_STATE"]
names = lambda f: set(open(f"{st}/{f}").read().split())
dump = 'python3 -c "import os; print(chr(10).join(os.environ))" > "$MOCK_STATE/%s"'     # names only, never values
assert loop.run_script(dump % "check-1.txt")[0]
c1 = names("check-1.txt")
assert {"SC_API_KEY", "BAO_TOKEN", "SECRET_PROJECT"} <= c1, "(1) the project's secret and its vault token do not reach a check"
assert not {"OTHER_KEY", "AGENT_KEY"} & c1, "(2) a key of another project (or not yet created) reached a check"
assert loop.run_script('[ "$SC_API_KEY" = "$EXPECT_SC" ] && [ "$SECRET_PROJECT" = selftest-calc ] && [ "$BAO_TOKEN" = "$EXPECT_TOK" ]')[0], \
    "(1) wrong value in a check, or the shell's BAO_TOKEN / SECRET_PROJECT was passed on"
assert loop.run_script('[ "$PEM_KEY" = "$EXPECT_PEM" ]')[0], "a multi-line vault value does not reach a check whole"
r = loop.run_claude("work", "You are the WORKER session.\nTASK M9.T1\nATTEMPT: 1\n", loop.OPUS, "high")
assert r["ok"] and r["text"] == "stored AGENT_KEY", f"(3) the run session could not store its key: {r['text']}"
s1 = names("env-M9.T1.txt")
assert "OTHER_KEY" not in s1 and names("ls-M9.T1.txt") == {"SC_API_KEY", "PEM_KEY"}, "(2) the run session sees another project's keys"
assert {"SC_API_KEY", "BAO_TOKEN", "SECRET_PROJECT"} <= s1, "(1) the project's secret and its vault token do not reach a run session"
assert loop.run_script('[ "$AGENT_KEY" = "$MOCK_AGENT_VALUE" ] && [ -z "${OTHER_KEY+x}" ]')[0], "(3) a later check does not see the key the session stored"
os.environ["FAKE_VAULT_FAIL_FIRST"] = str(int(open(os.environ["FAKE_VAULT"] + ".fails").read()) + 2)
assert loop.child_env()["SC_API_KEY"] == os.environ["EXPECT_SC"], "a vault read that fails twice was not retried"
del os.environ["FAKE_VAULT_FAIL_FIRST"]
for name, val in (("SC_API_KEY", os.environ["EXPECT_SC"]), ("BAO_TOKEN", os.environ["EXPECT_TOK"])):
    open("app.cfg", "w").write(f"key = {val}\n")
    loop.git("add", "app.cfg"); loop.git("commit", "-q", "-m", "leak")
    ok, out = loop.run_gates()
    assert not ok and f"app.cfg: contains the value of {name}" in out, f"(4) check_scope missed {name} in a tracked file: {out}"
    assert val not in out, "(4) check_scope printed the value"
    loop.git("rm", "-q", "app.cfg"); loop.git("commit", "-q", "-m", "remove the leak")
    ok, out = loop.run_gates()
    assert not ok and f"a commit not yet on origin/main contains the value of {name}" in out, f"check_scope missed {name} in the history: {out}"
    assert val not in out, "check_scope printed the value"
    loop.git("reset", "-q", "--hard", "HEAD~2")
ok, out = loop.run_gates(); assert ok, f"gates fail once the leak is gone: {out}"
# a work leg that commits a key (and removes it again) is discarded whole, so the next task's gates pass
start = loop.git("rev-parse", "HEAD")
card = {"id": "M9.T9", "title": "leaky task", "acceptance": "app.py prints ok", "check": "true", "files": ["app.py"], "attempts": 0}
ok, msg, r, _, ran = loop.work_leg(card, "main")
assert not ok and "a secret value (or a file over 5 MB) was committed, so the whole leg was discarded" in msg and "SC_API_KEY" in msg, msg
assert os.environ["EXPECT_SC"] not in msg, "the failure note holds the value"
assert loop.git("rev-parse", "HEAD") == start and not os.path.exists("app.py"), "the leaky leg's commits were kept"
ok, out = loop.run_gates(); assert ok, f"the next task's gates fail after a discarded leaky leg: {out}"
assert "M9.T9: a secret value was committed" in open(".harness-run/alerts.log").read(), "John was not alerted"
PY
# a vault that does not answer ends the run through finish(): a clear stop and an alert, no traceback
set +e; env "${vault_env[@]}" FAKE_VAULT_HANG=1 HARNESS_VAULT_TIMEOUT=0.5 python3 -I harness/loop.py run --no-push > "$tmp/hang.txt" 2>&1; rc=$?; set -e
[ "$rc" = 3 ] && grep -q 'LOOP STOPPED: the vault does not answer: `secret --project selftest-calc ls` did not answer in time (3 tries)' "$tmp/hang.txt" \
  && ! grep -q Traceback "$tmp/hang.txt" && grep -q 'the vault does not answer' .harness-run/alerts.log || fail "vault timeout (rc $rc): $(cat "$tmp/hang.txt")"
git switch -q main
# deploys: the loop takes deploy.by from the committed, approved spec and passes HARNESS_DEPLOY_BY; the guard trusts
# only that variable. MCP: a valid spec/mcp.json reaches `claude`, an invalid one does not, a worker's edit is undone.
env "${vault_env[@]}" python3 -I - > "$tmp/deploy.txt" 2>&1 <<'PY' || fail "deploy/mcp: $(cat "$tmp/deploy.txt")"
import hashlib, json, os, sys
sys.path.insert(0, "harness")
import loop
st = os.environ["MOCK_STATE"]
work = lambda t: loop.run_claude("work", f"You are the WORKER session.\nTASK {t}\nATTEMPT: 1\n", loop.OPUS, "high")
read = lambda f: open(f"{st}/{f}").read().split()
mcp = os.path.join(os.getcwd(), "spec", "mcp.json")
os.environ["HARNESS_DEPLOY_BY"] = "agent"                                   # the shell's value is never passed on
work("M9.T3"); assert read("deploy-M9.T3.txt") == ["john"], "the session's HARNESS_DEPLOY_BY is not john for a spec without deploy.by"
spec = json.load(open("spec/requirements.json")); spec["deploy"]["by"] = "agent"
open("spec/requirements.json", "w").write(json.dumps(spec))                # forged in the working tree, with a matching hash
open("spec/APPROVED", "w").write(json.dumps({"sha256": hashlib.sha256(open("spec/requirements.json", "rb").read()).hexdigest()}))
work("M9.T4"); assert read("deploy-M9.T4.txt") == ["john"], "a spec forged in the working tree allowed deploys"
loop.git("commit", "-q", "-am", "approved: deploy by agent")
work("M9.T5"); assert read("deploy-M9.T5.txt") == ["agent"], "the committed, approved deploy.by agent did not reach the session"
loop.git("reset", "-q", "--hard", "HEAD~1")
work("M9.T6"); assert mcp not in read("argv-M9.T6.txt"), "spec/mcp.json passed although it does not exist"
open(mcp, "w").write('{"mcpServers": {"browser": {"command": "agent-browser-mcp", "args": []}}}')
work("M9.T7"); a = read("argv-M9.T7.txt"); i = a.index("--mcp-config")
assert a[i + 1:i + 3] == [str(loop.H / "mcp.json"), mcp], f"spec/mcp.json is not passed with harness/mcp.json: {a}"
loop.git("add", "spec/mcp.json"); loop.git("commit", "-q", "-m", "design: browser")
start = loop.git("rev-parse", "HEAD")
open(mcp, "w").write('{"mcpServers": {}, "worker": "edit"}')
loop.seal(start, "main", "work", forbidden=loop.WORK_FORBIDDEN)
assert "worker" not in open(mcp).read(), "a worker's edit to spec/mcp.json was not undone"
open(mcp, "w").write('{"servers": []}')
work("M9.T8"); assert mcp not in read("argv-M9.T8.txt"), "an invalid spec/mcp.json was passed to claude"
loop.git("checkout", "--", "spec/mcp.json"); loop.git("reset", "-q", "--hard", "HEAD~1")
PY
guard() {   # $1: HARNESS_DEPLOY_BY or "", $2: the command; exit 2 = blocked
  printf '{"tool_input":{"command":%s}}' "$(jq -Rn --arg c "$2" '$c')" \
    | env -u HARNESS_DEPLOY_BY -u SECRET_PROJECT ${1:+HARNESS_DEPLOY_BY=$1} ${SP:+SECRET_PROJECT=$SP} CLAUDE_PROJECT_DIR="$PWD" bash harness/guard.sh 2>"$tmp/guard.err"
}
SP=selftest-calc   # the loop sets SECRET_PROJECT only when this project's vault is in use; SP= below is a run without it
for c in "wrangler deploy" "npx wrangler@3.9 deploy" "npm run deploy" "pnpm publish" "yarn publish" "npx netlify-cli deploy --prod" "cf deploy" \
         "env -u BAO_TOKEN secret --project claude ls" "BAO_TOKEN= secret ls" "unset BAO_TOKEN; secret ls" "env -u SECRET_PROJECT secret ls" \
         "SECRET_PROJECT=claude secret ls" "cat ~/.config/openbao/claude.token" "env -i secret ls" "secret --project=claude ls" \
         "export SECRET_PROJECT=claude" "x=\$(secret --project claude get K)"; do
  if guard "" "$c"; then fail "the guard let '$c' through"; fi
done
for c in "secret ls" "printf %s \"\$K\" | secret set NAME -" "npm run build" "wrangler dev" "grep BAO_TOKEN= src" "grep -rn unset src"; do guard "" "$c" || fail "the guard blocked '$c'"; done
for c in "secret ls" "printf %s \"\$K\" | secret set NAME -" "x=\$(secret get K)" "command secret ls" "FOO=1 secret ls"; do
  if SP= guard "" "$c"; then fail "the guard let '$c' through without SECRET_PROJECT (it would use John's \`claude\` vault project)"; fi
done
grep -q 'John must run `vault-project selftest-calc` once' "$tmp/guard.err" || fail "the guard's message does not name vault-project <slug>: $(cat "$tmp/guard.err")"
for c in "npx wrangler secret list" "grep -rn secret src" "ls secrets/"; do SP= guard "" "$c" || fail "the guard blocked '$c' without SECRET_PROJECT"; done
guard agent "npx wrangler@3.9 deploy" || fail "the guard blocked a deploy with HARNESS_DEPLOY_BY=agent"
guard agent "secret get K | npx wrangler pages secret put K --project-name site" || fail "the guard took wrangler's --project-name for the vault's --project"
guard agent "secret get K | npx wrangler pages secret put K --project site" || fail "the guard took another tool's \`secret\` subcommand for the vault helper"
mkdir -p "$tmp/dep/spec"; cp -r harness "$tmp/dep/"     # a spec/ that says agent, approved, is not enough for the guard
python3 -I -c 'import json; s = json.load(open("spec/requirements.json")); s["deploy"]["by"] = "agent"; print(json.dumps(s))' > "$tmp/dep/spec/requirements.json"
python3 -I "$tmp/dep/harness/spec.py" check >/dev/null || fail "spec.py rejects deploy.by agent"
printf '{"sha256": "%s"}\n' "$(sha256sum "$tmp/dep/spec/requirements.json" | cut -d' ' -f1)" > "$tmp/dep/spec/APPROVED"
printf '{"tool_input":{"command":"wrangler deploy"}}' | env -u HARNESS_DEPLOY_BY CLAUDE_PROJECT_DIR="$tmp/dep" bash harness/guard.sh 2>/dev/null \
  && fail "the guard trusted deploy.by agent in spec/ instead of HARNESS_DEPLOY_BY"
sed -i 's/"by": "agent"/"by": "bob"/' "$tmp/dep/spec/requirements.json"
python3 -I "$tmp/dep/harness/spec.py" check >/dev/null && fail "spec.py accepts deploy.by bob"
python3 -I -c 'import json; s = json.load(open("spec/requirements.json")); s["project"] = "Claude"; print(json.dumps(s))' > "$tmp/dep/spec/requirements.json"
python3 -I "$tmp/dep/harness/spec.py" check > "$tmp/dep.txt" 2>&1 || true; grep -q '`project` .Claude.: the vault projects claude, silk' "$tmp/dep.txt" || fail "spec.py accepts the reserved vault project claude"
# (6) without this project's token file the store is .env, as before: checks get its values, run sessions do not, and
# the shell's BAO_TOKEN / SECRET_PROJECT (a valid token of another project, with the helper on PATH) reach neither.
printf 'SC_API_KEY=dotenv-value-0123456789\nPEM_KEY=dotenv-pem\n' > .env
env "${vault_env[@]}" HOME="$tmp/home-empty" MOCK_STATE="$tmp/mock4" python3 -I - > "$tmp/dotenv.txt" 2>&1 <<'PY' || fail ".env: $(cat "$tmp/dotenv.txt")"
import os, sys
sys.path.insert(0, "harness")
import loop
assert loop.vault() is None, "the vault was used without this project's token file"
env = loop.child_env()
assert env.get("SC_API_KEY") == "dotenv-value-0123456789", "(6) .env does not reach checks"
assert not {"BAO_TOKEN", "SECRET_PROJECT"} & set(env), "the shell's BAO_TOKEN / SECRET_PROJECT reached a check"
loop.run_claude("work", "You are the WORKER session.\nTASK M9.T2\nATTEMPT: 1\n", loop.OPUS, "high")
seen = open(os.environ["MOCK_STATE"] + "/env-M9.T2.txt").read().split()
assert "SC_API_KEY" not in seen, "(6) .env values now reach run sessions"
assert not {"BAO_TOKEN", "SECRET_PROJECT"} & set(seen), "the shell's BAO_TOKEN / SECRET_PROJECT reached a run session"
PY
HOME="$tmp/home-empty" python3 -I harness/spec.py secrets | grep -q "every required secret John supplies is in .env" || fail "(6) spec.py secrets does not read .env"
rm .env
# preflight: the helper on PATH and secrets in the spec but no token for this project is a FAIL naming vault-project <slug>;
# the sign-in probe runs on the work legs' model (Opus, or the loop's overrides), not on Fable
printf '#!/bin/sh\nwhile [ $# -gt 0 ]; do [ "$1" = --model ] && echo "$2" >> "%s"; shift; done\necho %s\n' "$tmp/probe.txt" "'{\"is_error\": false}'" > "$tmp/vbin/probe-claude"
chmod +x "$tmp/vbin/probe-claude"
env "${vault_env[@]}" HOME="$tmp/home-empty" HARNESS_CLAUDE="$tmp/vbin/probe-claude" bash harness/preflight.sh > "$tmp/pre.txt" 2>&1 && fail "preflight passed without this project's vault token"
grep -q '^  FAIL  the spec lists secrets .*run `vault-project selftest-calc` once' "$tmp/pre.txt" || fail "preflight: no FAIL naming vault-project selftest-calc: $(cat "$tmp/pre.txt")"
grep -q '^  ok    a headless session starts and answers (model claude-opus-5-5)' "$tmp/pre.txt" && [ "$(cat "$tmp/probe.txt")" = claude-opus-5-5 ] \
  || fail "preflight did not probe with the work model claude-opus-5-5: $(cat "$tmp/probe.txt")"
rm "$tmp/probe.txt"
env "${vault_env[@]}" HARNESS_MODEL=claude-x-1 HARNESS_CLAUDE="$tmp/vbin/probe-claude" bash harness/preflight.sh > "$tmp/pre.txt" 2>&1 || true
grep -q 'vault-project' "$tmp/pre.txt" && fail "preflight asks for vault-project although the token file exists: $(cat "$tmp/pre.txt")"
[ "$(cat "$tmp/probe.txt")" = claude-x-1 ] || fail "preflight's probe ignores HARNESS_MODEL: $(cat "$tmp/probe.txt")"
# approve: the next step names the store in use; .env.example does not ask John to fill a key the run creates
env "${vault_env[@]}" python3 -I harness/spec.py approve > "$tmp/appr.txt" 2>&1 || fail "approve: $(cat "$tmp/appr.txt")"
grep -q 'Next: put secret values in the vault (`secret --project selftest-calc set NAME -`' "$tmp/appr.txt" && ! grep -q '\.env' "$tmp/appr.txt" \
  || fail "approve with the vault does not say vault: $(cat "$tmp/appr.txt")"
env "${vault_env[@]}" HOME="$tmp/home-empty" python3 -I harness/spec.py approve > "$tmp/appr.txt" 2>&1 || fail "approve: $(cat "$tmp/appr.txt")"
grep -q 'Next: run `vault-project selftest-calc` once' "$tmp/appr.txt" || fail "approve without the token does not say vault-project: $(cat "$tmp/appr.txt")"
HOME="$tmp/home-empty" python3 -I harness/spec.py approve > "$tmp/appr.txt" 2>&1 || fail "approve: $(cat "$tmp/appr.txt")"
grep -q 'Next: put secret values in .env' "$tmp/appr.txt" || fail "approve without the helper does not say .env: $(cat "$tmp/appr.txt")"
grep -q '^SC_API_KEY=$' .env.example && grep -q '^# AGENT_KEY=$' .env.example && ! grep -q '^AGENT_KEY=' .env.example \
  || fail ".env.example asks John for a key the run creates: $(cat .env.example)"

# Ctrl+C, a closed tmux window (SIGHUP) and `kill` (SIGTERM): the running session (own process group)
# dies with the loop and commits nothing afterwards
for sig in INT HUP TERM; do
make_repo "$tmp/repo4-$sig"
MOCK_SCENARIO=hang MOCK_STATE="$tmp/mock5-$sig" python3 -I -c 'import os, signal, sys; signal.signal(signal.SIGINT, signal.SIG_DFL); os.execvp(sys.argv[1], sys.argv[1:])' \
  python3 -I harness/loop.py run --no-push > "$tmp/int.txt" 2>&1 &   # SIG_DFL: a background job of a script starts with SIGINT ignored
lp=$!
for _ in $(seq 100); do [ -s "$tmp/mock5-$sig/hang.pid" ] && break; sleep 0.1; done
[ -s "$tmp/mock5-$sig/hang.pid" ] || fail "the hanging mock session did not start: $(cat "$tmp/int.txt")"
kill -"$sig" "$lp"; set +e; wait "$lp"; set -e
heads=$(git log --all --oneline | wc -l); mp=$(cat "$tmp/mock5-$sig/hang.pid")
alive() { [ -r "/proc/$1/stat" ] && ! grep -q '^[0-9]* (.*) Z' "/proc/$1/stat"; }   # a zombie counts as gone
for _ in $(seq 20); do alive "$mp" || break; sleep 0.1; done
alive "$mp" && fail "the session is still running after SIG$sig on the loop"
sleep 4    # past the mock's 3 s sleep: a surviving session would have committed by now
[ "$(git log --all --oneline | wc -l)" = "$heads" ] && ! git log --all --oneline | grep -q 'late commit' \
  || fail "a commit appeared after the loop stopped (SIG$sig): $(git log --all --oneline | head -3)"
grep -q 'interrupted' "$tmp/int.txt" || fail "the loop did not stop as interrupted (SIG$sig): $(cat "$tmp/int.txt")"
done

echo "SELFTEST PASS (design, plan after a limit wait, work with escalation, 429 retry and limit fallback, verify with fallback and the loop's check output, replan, audit gap, fix, audit, deliver; usage recorded; CHECK-WRONG judged both ways, ignored on attempt 1; vault secrets scoped per project, stored by a session, guarded in git; deploy guard; .env fallback; vault-project required; work-model probe; Ctrl+C, SIGHUP and SIGTERM kill the session)"
