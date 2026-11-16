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

# Deploying and publishing are John's unless the approved spec says "deploy": {"by": "agent"}. The loop works that
# out from the committed, approved spec and sets HARNESS_DEPLOY_BY; a spec edited in the working tree changes nothing.
if grep -Eq '(^|[^[:alnum:]_.-])(wrangler(@[^[:space:]]*)?([[:space:]]+[^|;&]*)?[[:space:]](deploy|publish|secret[[:space:]]+(put|bulk))([[:space:]:]|$)|vercel(@[^[:space:]]*)?([[:space:]]+[^|;&]*)?[[:space:]]--prod|netlify(-cli)?(@[^[:space:]]*)?[[:space:]]+deploy([[:space:]]+[^|;&]*)?[[:space:]]--prod|(fly|flyctl)[[:space:]]+deploy|cf[[:space:]]+deploy|(npm|pnpm|yarn|bun)[[:space:]]+(run[[:space:]]+)?(deploy|publish)([[:space:]:]|$)|gh[[:space:]]+release)' <<<"$cmd"; then
  [ "${HARNESS_DEPLOY_BY:-john}" = agent ] || block "deploying and publishing are John's: the approved spec does not say \"deploy\": {\"by\": \"agent\"}. Say in your final message what is ready to deploy."
fi

# The vault: a session uses its own project only (the loop sets BAO_TOKEN and SECRET_PROJECT). Same unix user, so the
# helper could fall back to another project's token file: this is a tripwire against that, not a boundary.
cmd_at='(^|[|;&(`]|\$\()[[:space:]]*'                          # where a command starts
assigns='([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'           # VAR=value prefixes
helper="${cmd_at}${assigns}(env([[:space:]]+[^|;&[:space:]]+)*[[:space:]]+)?(command[[:space:]]+)?secret"
vars='(BAO_TOKEN|SECRET_PROJECT)'
grep -Eq "${helper}([[:space:]]+[^|;&[:space:]]+)*[[:space:]]+--project([[:space:]=]|\$)|${cmd_at}${assigns}${vars}=|(^|[^[:alnum:]_.-])(export|env)([[:space:]]+[^|;&]*)?[[:space:]]${vars}=|(^|[^[:alnum:]_.-])unset([[:space:]]+[^|;&]*)?[[:space:]]${vars}([[:space:]|;&)]|\$)|(^|[^[:alnum:]_.-])env([[:space:]]+[^|;&]*)?[[:space:]](-u|--unset)[=[:space:]]*${vars}|\.config/openbao" <<<"$cmd" \
  && block "the vault is used through this project's own BAO_TOKEN and SECRET_PROJECT only: no --project, no changing or unsetting them, no token files."
grep -Eq '(^|[^[:alnum:]_.-])env[[:space:]]+(-[a-zA-Z]*i|--ignore-environment|-([[:space:]]|$))' <<<"$cmd" && grep -Eq '(^|[^[:alnum:]_.-])secret([[:space:]]|$)' <<<"$cmd" \
  && block "running the vault helper with an emptied environment would use another project's token."

# History rewrites and leaving the run branch.
grep -Eq 'git[[:space:]]+(-[^|;&]*[[:space:]]+)?(rebase|filter-branch|filter-repo|reflog[[:space:]]+expire|update-ref[[:space:]]+-d)' <<<"$cmd" \
  && block "rewriting git history. Make a new commit instead."
grep -Eq 'git[[:space:]]+(-[^|;&]*[[:space:]]+)?(switch|checkout)[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*(main|master)([[:space:]]|$)' <<<"$cmd" \
  && block "leaving the run branch. Stay on the branch the loop started you on."
grep -Eq 'git[[:space:]]+(-[^|;&]*[[:space:]]+)?reset[[:space:]]+--hard[[:space:]]+(origin/|main|master)' <<<"$cmd" \
  && block "resetting onto main discards the run's work."
exit 0
