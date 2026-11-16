#!/usr/bin/env bash
# Everything that would stop an unattended run, checked before it starts. Exit 0 = good to go.
# Run from anywhere: bash harness/preflight.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
rc=0; warn=0
ok()   { echo "  ok    $1"; }
bad()  { echo "  FAIL  $1"; rc=1; }
note() { echo "  warn  $1"; warn=1; }
CLAUDE="${HARNESS_CLAUDE:-claude}"

echo "== tools =="
for t in git python3 jq bash "$CLAUDE"; do command -v "$t" >/dev/null 2>&1 && ok "$t" || bad "$t is not installed or not on PATH"; done
command -v tmux >/dev/null 2>&1 && ok "tmux (run survives a closed terminal)" || note "tmux missing: harness/run.sh will run in the foreground"
command -v notify-send >/dev/null 2>&1 && ok "notify-send (desktop alerts)" || note "notify-send missing: stops and judge alerts will only be in .harness-run/alerts.log"
command -v gh >/dev/null 2>&1 && ok "gh (pull request at the end)" || note "gh missing: the branch is pushed but you open the pull request yourself"

echo "== spec =="
if python3 -I harness/spec.py check >/dev/null 2>&1; then ok "spec/requirements.json passes its checks"; else bad "spec has problems: python3 harness/spec.py check"; fi
if [ -f spec/APPROVED ] && [ "$(jq -r .sha256 spec/APPROVED 2>/dev/null)" = "$(sha256sum spec/requirements.json 2>/dev/null | cut -d' ' -f1)" ]; then
  ok "spec is approved and unchanged since approval"
else bad "spec is not approved (or changed since): python3 harness/spec.py approve"; fi

echo "== secrets =="
if out=$(python3 -I harness/spec.py secrets 2>&1); then ok "$out"; else bad "$out"; fi
if git ls-files --error-unmatch .env >/dev/null 2>&1; then bad ".env is tracked by git: git rm --cached .env"; fi
git check-ignore -q .env && ok ".env is git-ignored" || bad ".env is not git-ignored: add it to .gitignore"

echo "== git =="
[ -z "$(git status --porcelain)" ] && ok "working tree clean" || bad "uncommitted changes: commit or stash them"
if git remote get-url origin >/dev/null 2>&1; then ok "remote origin set ($(git remote get-url origin))"; else note "no git remote: nothing will be pushed and no pull request opened"; fi
git config user.name >/dev/null && git config user.email >/dev/null && ok "git identity set" || bad "git identity missing: git config user.name / user.email"
bash harness/install-hooks.sh >/dev/null 2>&1 && ok "pre-push hook installed" || note "could not install the pre-push hook"

echo "== gates =="
if bash checks/run_gates.sh >/dev/null 2>&1; then ok "checks/run_gates.sh passes"; else bad "gates fail before the run: bash checks/run_gates.sh"; fi

echo "== claude =="
if [ "${HARNESS_SKIP_CLAUDE_PROBE:-0}" = 1 ]; then note "sign-in probe skipped"
elif out=$(timeout 120 "$CLAUDE" -p --settings harness/run-settings.json --strict-mcp-config --mcp-config harness/mcp.json \
      --output-format json --max-turns 2 --model "${HARNESS_MODEL:-claude-fable-5-2}" "Reply with the single word: ready" </dev/null 2>&1) \
     && [ "$(printf '%s\n' "$out" | grep '^{' | tail -1 | jq -r '.is_error' 2>/dev/null)" = "false" ]; then
  ok "a headless session starts and answers (model ${HARNESS_MODEL:-claude-fable-5-2})"
else bad "a headless session failed: $(printf '%s' "$out" | tail -c 300)"; fi

echo "== machine =="
if command -v busctl >/dev/null 2>&1; then
  lid=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch 2>/dev/null | cut -d'"' -f2)
  [ "$lid" = "suspend" ] && note "closing the laptop lid suspends the machine and freezes the run" || ok "lid close does not suspend (${lid:-n/a})"
fi
free_gb=$(df -BG --output=avail . | tail -1 | tr -dc 0-9); [ "${free_gb:-0}" -ge 5 ] && ok "${free_gb} GB free disk" || note "only ${free_gb} GB free disk"

echo
if (( rc )); then echo "PREFLIGHT: FAIL (fix the FAIL lines, then run this again)"; exit 1; fi
(( warn )) && echo "PREFLIGHT: PASS with warnings" || echo "PREFLIGHT: PASS"
