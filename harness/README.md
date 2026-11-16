# The harness: how the unattended build works

## The idea

A long task fails in a few well-known ways when one model session tries to do all of it:

| Failure | What it looks like | What stops it here |
|---|---|---|
| Vague goal | The wrong thing gets built, well | `/intake` interview; spec checker rejects untestable wording; your approval is hashed |
| Context rot | Quality drops as the conversation fills up | A fresh session per task; state lives in git, never in a conversation |
| Context anxiety | Wraps up early, summarises instead of finishing | Small tasks with their own context; rules say there is no reward for finishing early |
| Declaring victory | "Done" with work missing | Scripts decide: task check, gates, acceptance check per requirement, final audit |
| Gaming the check | Hard-coded answers, weakened tests | Checks are written before the work and must fail first; workers cannot edit them; a separate verifier reads every diff |
| One-shotting | Tries to build everything at once | Milestones planned one at a time; one task per session |
| Regressions | Task 30 quietly breaks task 5 | Gates after every task; every acceptance check re-run before the audit |
| Quiet failure | Stops and nobody notices | Every stop has a printed reason, a file and a desktop notification; blocked items say what they need |
| Permission stalls | Waits forever on a prompt | Headless sessions with a fixed allow list; denials are recorded in the task's note |
| Provider errors | One 5xx kills an overnight run | Retried with pauses, never counted against a task; usage limits are waited out |
| Lost secrets | Keys in git or in the transcript | Names in the spec, values in `.env`; a gate scans tracked files for `.env` values |

## The run, step by step

`harness/loop.py` is a plain script. Each step ("leg") is a new `claude -p` session with a short brief
from `harness/prompts/`. The script, not the model, checks and records every result.

1. **DESIGN** (once): `spec/DESIGN.md`, `plan/milestones.json` (every requirement in exactly one
   milestone), `checks/check_project.sh` (lint, tests, build), `init.sh`.
2. **PLAN** (per milestone, just before it starts): atomic tasks in `plan/M1.r1.jsonl`, one check per
   task in `checks/tasks/`, one acceptance check per requirement in `checks/acceptance/`. The plan is
   rejected unless every check parses and **fails before the work exists**.
3. **WORK**: one task, one session. Afterwards the script throws away any edit to the spec, the plan,
   the checks, the ledger or the harness.
4. **CHECK**: the script runs the task's check and `checks/run_gates.sh`.
5. **VERIFY**: a read-only session that did not do the work ends with `VERDICT: PASS` or `FAIL`. Its
   brief carries the loop's check and gate output, so it reads the diff and uses the product instead
   of running them again.
6. **CLOSE**: when a milestone's tasks are done, its requirements' acceptance checks must pass;
   otherwise the milestone is planned again (up to three rounds).
7. **AUDIT**: every acceptance check and gate is re-run, then a read-only auditor uses the product as
   a user would and compares it with the spec. Each gap becomes a fix milestone whose first job is a
   check that demonstrates the gap. Up to three audits.
8. **DELIVER**: `DELIVERY.md`, push, pull request. You merge; you deploy.

A failed task is retried twice with the failure text, then marked `blocked`. From the second attempt,
a worker may end with `CHECK-WRONG: <reason>` when it is sure the check itself is wrong; a read-only
judge session decides. If it agrees, the task is blocked at once with a note starting `check wrong
(judge agreed):`, you get a desktop notification, and the run goes on with other tasks; if not, the
judge's reason is the feedback for the next attempt. A blocked milestone stops
the run, because later milestones build on it.

## Files

| Path | What it is | Who writes it |
|---|---|---|
| `spec/BRIEF.md` | Your first description, word for word | intake |
| `spec/requirements.json` | The spec. The only source of truth | intake, approved by you |
| `spec/REQUIREMENTS.md`, `.env.example`, `spec/APPROVED` | Readable copy, secret names, approval hash | `harness/spec.py approve` |
| `spec/DESIGN.md`, `plan/milestones.json`, `init.sh` | Architecture, build order, install script | design session |
| `plan/*.jsonl`, `checks/tasks/`, `checks/acceptance/` | Tasks and the checks that prove them | planner sessions |
| `checks/check_project.sh` | Lint, tests, build for the chosen stack | design and planner sessions |
| `checks/run_gates.sh` and the other `check_*.sh` | Fixed gates: secrets, record invariants, harness untouched | template only |
| `ledger.jsonl`, `PROGRESS.md`, `DELIVERY.md` | State, step log, final report | `harness/loop.py` only |
| `notes/<task>/` | Evidence and follow-up ideas | workers |
| everything else | The project | workers |

## Settings you may want to change (on `main`, before a run)

- **Permissions**: `harness/run-settings.json`. Shell, edits and web reads are allowed; `sudo`,
  `git push`, `gh`, `ssh` and your private folders are denied. If a task's note says a tool was
  denied and the work needs it, allow it here.
- **Tools for the sessions**: `harness/mcp.json`. Run sessions see only the servers listed here, not
  your personal connectors (mail, calendar, CRM). For a web UI, add the Playwright server so
  sessions can drive a real browser:
  `{"mcpServers": {"playwright": {"command": "npx", "args": ["-y", "@playwright/mcp@0.0.83", "--headless"]}}}`
- **Budgets and model**: `--max-hours`, `--max-legs` on `harness/run.sh`; the model and effort per leg
  kind (`HARNESS_MODEL_<KIND>`, `HARNESS_EFFORT_<KIND>`, or `HARNESS_MODEL`/`HARNESS_EFFORT` for all;
  see the docstring of `harness/loop.py`); the limits at the top of `harness/loop.py`.
  `python3 harness/loop.py status` ends with tokens and a cost estimate per leg kind and model.
- **Rules every session follows**: `CLAUDE.md`.

## Limits worth knowing

- **No operating-system sandbox.** Sessions run as you, with a deny list and a command guard. Use this
  for your own projects, with secrets scoped to the project.
- **The guard is a tripwire, not a boundary.** `harness/guard.sh` blocks common deploy commands (unless
  the approved spec says `"deploy": {"by": "agent"}`) and a session's attempts to reach another vault
  project (`secret --project`, changing or unsetting `BAO_TOKEN`/`SECRET_PROJECT`, `~/.config/openbao`).
  Sessions run as the same unix user that owns every project's vault token file, so a determined
  session could get around it; only a separate unix user per project would be a boundary.
- **A requirement is only as good as its check.** The planner writes the acceptance checks and the
  auditor judges them, but a behaviour no script can observe will not be proven. The interview pushes
  such items into `human_gates`.
- **It prepares a deploy; it does not deploy.** Pushing to production, spending money, messaging real
  people and merging are yours unless the approved spec says otherwise.
- **Usage.** Each task costs at least two sessions (work and verify). A project of 60 tasks is roughly
  150 sessions on the Max plan; when the limit is reached the run waits and continues.
- **Closing the laptop lid** suspends the machine unless you have turned that off.

## Checking the harness itself

`bash harness/tests/selftest.sh` runs the whole loop against a fake model that misbehaves on purpose
(a provider error, edits to the ledger and to checks, a bug only the auditor sees) and takes a few
seconds. CI runs it on every push.

## Where the method comes from

`harness/METHOD.md` lists the sources and what was taken from each.
