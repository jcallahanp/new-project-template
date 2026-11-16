#!/usr/bin/env bash
# PreToolUse(Bash) hook for build sessions: block the few commands that cannot be undone or that
# would put a secret into the conversation. Exit 2 = block; stderr is shown to the model.
# A tripwire, not a boundary: the loop restores protected files after every session anyway.
block() { echo "BLOCKED by harness/guard.sh: $1" >&2; exit 2; }
cmd=$(jq -er '.tool_input.command // ""' 2>/dev/null) || block "could not parse hook input"
root="${CLAUDE_PROJECT_DIR:-$PWD}"

# Recursive delete outside the project (or of the repo itself, or of .git).
while read -r seg; do
  [ -n "$seg" ] || continue
  grep -Eq -- '[[:space:]]-[a-zA-Z]*[rR]|--recursive' <<<"$seg" || continue
  for arg in $seg; do
    case "$arg" in
      rm|-*) continue ;;
      /tmp/*|"$root"/?*) ;;
      /*|~*|*..*|.|./|'*'|.git|.git/*|./.git*|'$HOME'*) block "recursive delete of '$arg'. Delete only named paths inside this project." ;;
    esac
  done
done < <(grep -oE '(^|[^[:alnum:]_.-])rm[[:space:]][^|;&]*' <<<"$cmd")

# Printing the secrets file. Load it into a command instead: set -a; . ./.env; set +a; <command>
grep -Eq '(^|[^[:alnum:]_./-])(cat|less|more|head|tail|grep|rg|awk|sed|bat|strings|xxd|od|nl|cut|sort|base64|printenv|env)([[:space:]]+[^|;&]*)?[[:space:]]\.?/?\.env(\.local|\.production)?([[:space:]]|$|[|;&>])' <<<"$cmd" \
  && block "printing .env puts secrets in the conversation. Use them without printing: set -a; . ./.env; set +a; <command>"
grep -Eq '(^|[|;&[:space:]])(printenv|env)[[:space:]]*($|[|;&>])' <<<"$cmd" && block "dumping the whole environment can print secrets. Print one named, non-secret variable instead."

# History rewrites and leaving the run branch.
grep -Eq 'git[[:space:]]+(-[^|;&]*[[:space:]]+)?(rebase|filter-branch|filter-repo|reflog[[:space:]]+expire|update-ref[[:space:]]+-d)' <<<"$cmd" \
  && block "rewriting git history. Make a new commit instead."
grep -Eq 'git[[:space:]]+(-[^|;&]*[[:space:]]+)?(switch|checkout)[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*(main|master)([[:space:]]|$)' <<<"$cmd" \
  && block "leaving the run branch. Stay on the branch the loop started you on."
grep -Eq 'git[[:space:]]+(-[^|;&]*[[:space:]]+)?reset[[:space:]]+--hard[[:space:]]+(origin/|main|master)' <<<"$cmd" \
  && block "resetting onto main discards the run's work."
exit 0
