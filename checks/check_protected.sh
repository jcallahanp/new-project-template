#!/usr/bin/env bash
# Harness guard: on a build branch the rules, the loop, the prompts, the fixed gates and the CI
# workflow must be identical to origin/main, and the approved spec must match its recorded hash.
# Only John changes the harness, on main.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
rc=0
if [[ -f spec/APPROVED ]]; then
  want=$(python3 -I -c 'import json;print(json.load(open("spec/APPROVED")).get("sha256",""))' 2>/dev/null)
  have=$(sha256sum spec/requirements.json 2>/dev/null | cut -d' ' -f1)
  if [[ "$want" != "$have" ]]; then echo "  spec/requirements.json does not match spec/APPROVED (changed after approval)"; rc=1; fi
fi
branch="${GITHUB_HEAD_REF:-$(git branch --show-current 2>/dev/null)}"
if [[ "$branch" != build/* ]]; then echo "  not a build branch (${branch:-detached}): harness comparison skipped"; exit $rc; fi
if ! git rev-parse -q --verify origin/main >/dev/null 2>&1; then echo "  origin/main not available: harness comparison skipped"; exit $rc; fi
paths=(CLAUDE.md harness .claude .github checks/run_gates.sh checks/check_scope.sh checks/check_progress.sh checks/check_protected.sh)
changed=$(git diff --name-only origin/main...HEAD -- "${paths[@]}"; git status --porcelain -- "${paths[@]}" | sed 's/^...//')
if [[ -n "$changed" ]]; then
  echo "  protected files differ from origin/main on a build branch:"; printf '    %s\n' $changed; rc=1
else echo "  harness untouched"; fi
exit $rc
