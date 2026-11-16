#!/usr/bin/env bash
# Authoritative gate. Runs every check; exits non-zero if any fails. A task is not `done` and
# nothing is delivered unless this exits 0. Sessions may not declare success: this script decides.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
fail=0
for c in check_scope check_progress check_protected check_project; do
  echo "== $c =="
  if bash "checks/$c.sh"; then echo "  PASS"; else echo "  FAIL ($c)"; fail=1; fi
done
if (( fail )); then echo "GATES: FAIL"; exit 1; fi
echo "GATES: PASS"; exit 0
