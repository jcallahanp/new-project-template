#!/usr/bin/env bash
# Everything that would stop an unattended run, checked before it starts. Exit 0 = good to go.
# Run from anywhere: bash harness/preflight.sh [--max-hours N]   (harness/run.sh passes its arguments)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
max_hours=24; prev=""
for a in "$@"; do
  case "$a" in --max-hours=*) max_hours="${a#*=}" ;; esac
  [ "$prev" = "--max-hours" ] && max_hours="$a"; prev="$a"
done
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
out=$(python3 -I harness/spec.py secrets 2>&1); src=$?
while read -r level msg; do
  case "$level" in ok) ok "$msg" ;; note) note "$msg" ;; "") ;; *) bad "$level $msg" ;; esac
done <<<"$out"
[ "$src" = 0 ] || rc=1
# With the vault helper on PATH but no token for this project, the helper falls back to John's machine-wide `claude`
# project: a session's `secret set` would land there. The loop sets SECRET_PROJECT only from this project's token file.
if command -v secret >/dev/null 2>&1; then
  read -r slug nsec < <(python3 -I -c 'import sys; sys.path.insert(0, "harness"); import spec; s = spec.load()
print(spec.slug(s), len(s.get("secrets") or []))' 2>/dev/null)
  if [ "${nsec:-0}" -gt 0 ] && [ ! -f "$HOME/.config/openbao/$slug.token" ]; then
    bad "the spec lists secrets and the vault helper is on PATH, but this project has no vault token (~/.config/openbao/$slug.token): run \`vault-project $slug\` once, then store the values with \`secret --project $slug set NAME -\` (value on stdin)"
  fi
fi
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
# Probe with the work legs' model (most legs run on it), with the same overrides as loop.py: a usage limit on another
# model does not stop the run (the loop falls back), so it must not stop the start either.
probe_model=$(python3 -I -c 'import sys; sys.path.insert(0, "harness"); import loop; print(loop.model_for("work"))' 2>/dev/null) \
  || probe_model="${HARNESS_MODEL_WORK:-${HARNESS_MODEL:-claude-opus-5-5}}"
if [ "${HARNESS_SKIP_CLAUDE_PROBE:-0}" = 1 ]; then note "sign-in probe skipped"
elif out=$(timeout 120 "$CLAUDE" -p --settings harness/run-settings.json --strict-mcp-config --mcp-config harness/mcp.json \
      --output-format json --max-turns 2 --model "$probe_model" "Reply with the single word: ready" </dev/null 2>&1) \
     && [ "$(printf '%s\n' "$out" | grep '^{' | tail -1 | jq -r '.is_error' 2>/dev/null)" = "false" ]; then
  ok "a headless session starts and answers (model $probe_model)"
  exp=$(printf '%s\n' "$out" | grep '^{' | tail -1 | jq -r '.credential_expires_at // empty' 2>/dev/null)
  left=$(python3 -I -c '
import sys, time, datetime as d
v = sys.argv[1]
try:
    t = float(v); t = t / 1000 if t > 1e11 else t
except ValueError:
    t = d.datetime.fromisoformat(v.replace("Z", "+00:00")).timestamp()
print(round((t - time.time()) / 3600, 1))' "$exp" 2>/dev/null)
  if [ -n "$left" ]; then
    if [ -f "$HOME/.config/claude/oauth.env" ] || [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then ok "long-lived sign-in token in use"
    elif python3 -I -c 'import sys; sys.exit(float(sys.argv[1]) >= float(sys.argv[2]))' "$left" "$max_hours"; then
      note "the Claude sign-in expires in ${left} h, before the run's ${max_hours} h budget ends, and there is no long-lived token: run \`claude setup-token\` and save CLAUDE_CODE_OAUTH_TOKEN=<token> in ~/.config/claude/oauth.env (chmod 600)"
    else ok "the Claude sign-in lasts ${left} h, beyond the run's ${max_hours} h budget"; fi
  fi
else bad "a headless session failed: $(printf '%s' "$out" | tail -c 300)"; fi

echo "== machine =="
if command -v busctl >/dev/null 2>&1; then
  lid=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch 2>/dev/null | cut -d'"' -f2)
  [ "$lid" = "suspend" ] && note "closing the laptop lid suspends the machine and freezes the run" || ok "lid close does not suspend (${lid:-n/a})"
fi
desk_mb=$(ps -eo rss=,comm= 2>/dev/null | awk '$2 ~ /^(chrome|chromium|chromium-browse|code)$/ {s += $1} END {print int(s / 1024)}')
[ "${desk_mb:-0}" -gt 1024 ] && note "desktop browsers and editors (chrome, chromium, code) use ${desk_mb} MB: close them during the run: checks are memory- and timing-sensitive, and earlyoom kills chrome/playwright first" \
  || ok "desktop browsers and editors use ${desk_mb:-0} MB"
free_gb=$(df -BG --output=avail . | tail -1 | tr -dc 0-9); [ "${free_gb:-0}" -ge 5 ] && ok "${free_gb} GB free disk" || note "only ${free_gb} GB free disk"

echo
if (( rc )); then echo "PREFLIGHT: FAIL (fix the FAIL lines, then run this again)"; exit 1; fi
(( warn )) && echo "PREFLIGHT: PASS with warnings" || echo "PREFLIGHT: PASS"
