#!/usr/bin/env bash
# Start (or resume) the build loop so it survives a closed terminal.
#   bash harness/run.sh              preflight, then run in a tmux session; prints how to watch it
#   bash harness/run.sh --foreground run in this terminal instead
#   bash harness/run.sh status       where the run stands
# Extra arguments go to `loop.py run` (for example --max-hours 12, --no-push).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
if [ "${1:-}" = "status" ]; then exec python3 -I harness/loop.py status; fi
fg=0; if [ "${1:-}" = "--foreground" ]; then fg=1; shift; fi
# The long-lived sign-in from `claude setup-token` (CLAUDE_CODE_OAUTH_TOKEN=...), when John saved one: an
# interactive login expires. Loaded, never printed; the tmux session loads it again (tmux does not pass it on).
token_env='f="$HOME/.config/claude/oauth.env"; if [ -f "$f" ]; then set -a; . "$f"; set +a; fi'
eval "$token_env"
bash harness/preflight.sh "$@" || exit 1
mkdir -p .harness-run
name="build-$(basename "$PWD" | tr -c 'A-Za-z0-9_-' '-' | cut -c1-30)"
if (( fg )) || ! command -v tmux >/dev/null 2>&1; then
  python3 -I harness/loop.py run "$@" 2>&1 | tee -a .harness-run/run.log; exit "${PIPESTATUS[0]}"
fi
if tmux has-session -t "$name" 2>/dev/null; then echo "already running: tmux attach -t $name"; exit 0; fi
args=""; for a in "$@"; do args+=" $(printf '%q' "$a")"; done
tmux new-session -d -s "$name" "$token_env; python3 -I harness/loop.py run$args 2>&1 | tee -a .harness-run/run.log; echo; echo 'run ended: press Enter to close'; read -r _"
echo "Run started in tmux session '$name'."
echo "  watch:   tmux attach -t $name      (detach with Ctrl+b then d)"
echo "  log:     tail -f .harness-run/run.log"
echo "  status:  bash harness/run.sh status"
