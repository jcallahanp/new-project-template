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
| A wrong check | Every retry fails the same way | From attempt 2 a worker may claim `CHECK-WRONG`; a read-only judge decides; if it agrees the task is blocked at once with an alert |
| Noisy numbers | A rough estimate becomes an exact limit and fails by 1 % | Each number in the spec is a `hard` limit or a `target` with a margin; the checker rejects a number without one |
| One-shotting | Tries to build everything at once | Milestones planned one at a time; one task per session |
| Regressions | Task 30 quietly breaks task 5 | Gates after every task; every acceptance check re-run before the audit |
| Quiet failure | Stops and nobody notices | Every stop has a printed reason, a file and an alert (`.harness-run/alerts.log`, `notify-send` when present); blocked items say what they need |
| Permission stalls | Waits forever on a prompt | Headless sessions with a fixed allow list; denials are recorded in the task's note |
| Provider errors | One 5xx kills an overnight run | Retried with pauses, never counted against a task; a short 429 is retried too; a usage limit puts a work or verify leg on the other model, any other leg waits it out |
| Lost secrets | Keys in git or in the transcript | Names in the spec, values in the project's vault (when it has a token file) or `.env`; a gate scans tracked files for those values, and a leg that commits one is discarded |

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
5b. **JUDGE** (only when a worker ends with `CHECK-WRONG: <reason>`, from attempt 2): a read-only
   session decides `VERDICT: CHECK-WRONG` or `CHECK-OK`. A missing verdict counts as `CHECK-OK`.
6. **CLOSE**: when a milestone's tasks are done, its requirements' acceptance checks must pass;
   otherwise the milestone is planned again (up to three rounds).
7. **AUDIT**: every acceptance check and gate is re-run, then a read-only auditor uses the product as
   a user would and compares it with the spec. Each gap becomes a fix milestone whose first job is a
   check that demonstrates the gap. Up to three audits.
8. **DELIVER**: `DELIVERY.md`, push, pull request. You merge; you deploy.

A failed task is retried twice with the failure text, then marked `blocked`. From the second attempt,
a worker may end with `CHECK-WRONG: <reason>` when it is sure the check itself is wrong; the judge
decides. If it agrees, the task is blocked at once with a note starting `check wrong (judge
agreed):`, you get an alert, and the run goes on with other tasks; if not, the judge's reason is the
feedback for the next attempt. On the second and third attempt a work leg runs on Fable (unless
`HARNESS_MODEL_WORK` is set). A blocked milestone stops
the run, because later milestones build on it.

## Files

| Path | What it is | Who writes it |
|---|---|---|
| `spec/BRIEF.md` | Your first description, word for word | intake |
| `spec/requirements.json` | The spec. The only source of truth | intake, approved by you |
| `spec/REQUIREMENTS.md`, `.env.example`, `spec/APPROVED` | Readable copy, secret names, approval hash | `harness/spec.py approve` |
| `spec/DESIGN.md`, `plan/milestones.json`, `init.sh` | Architecture, build order, install script | design session |
| `spec/mcp.json` | MCP servers for this project's sessions (a browser, only when the product has a web UI); added to `harness/mcp.json` | design session |
| `plan/*.jsonl`, `checks/tasks/`, `checks/acceptance/` | Tasks and the checks that prove them | planner sessions |
| `checks/check_project.sh` | Lint, tests, build for the chosen stack | design and planner sessions |
| `checks/run_gates.sh` and the other `check_*.sh` | Fixed gates: secrets, record invariants, harness untouched | template only |
| `ledger.jsonl`, `PROGRESS.md`, `DELIVERY.md` | State, step log, final report | `harness/loop.py` only |
| `notes/<task>/` | Evidence and follow-up ideas | workers |
| `.harness-run/alerts.log` | One line per alert (stop, blocked check, discarded secret leg); git-ignored | `harness/loop.py` |
| `.harness-run/last-stop.txt`, `run.log` | Last stop reason, run output; git-ignored | `harness/loop.py`, `harness/run.sh` |
| everything else | The project | workers |

## Settings you may want to change (on `main`, before a run)

- **Permissions**: `harness/run-settings.json`. Shell, edits and web reads are allowed; `sudo`,
  `git push`, `gh`, `ssh` and your private folders are denied. If a task's note says a tool was
  denied and the work needs it, allow it here.
- **Tools for the sessions**: `harness/mcp.json`. Run sessions see only the servers listed here, not
  your personal connectors (mail, calendar, CRM). For a web UI, add the Playwright server so
  sessions can drive a real browser:
  `{"mcpServers": {"playwright": {"command": "npx", "args": ["-y", "@playwright/mcp@0.0.83", "--headless"]}}}`
- **Budgets**: `--max-hours`, `--max-legs` on `harness/run.sh`; the limits at the top of
  `harness/loop.py`.
- **Models and effort** (environment variables read by `harness/loop.py`; `<KIND>` is `DESIGN`, `PLAN`,
  `WORK`, `VERIFY`, `JUDGE` or `AUDIT`):
  - `HARNESS_MODEL_<KIND>`, else `HARNESS_MODEL`, else the default: Fable 5.2 for design, plan, judge
    and audit; Opus 5.5 for work and verify.
  - `HARNESS_ESCALATE_MODEL`: the model for a work leg on attempt 2 and 3 (default Fable 5.2); it is
    not used when `HARNESS_MODEL_WORK` is set.
  - `HARNESS_EFFORT_<KIND>`, else `HARNESS_EFFORT`, else `high`; a set but empty value passes no
    `--effort`.
  - `HARNESS_FALLBACK_MODEL`: the model a work or verify leg switches to on a usage limit (default:
    the other of Fable 5.2 and Opus 5.5).
  - `HARNESS_LIMIT_HOURS` (how long to wait out a usage limit, default 8), `HARNESS_LIMIT_POLL`
    (seconds between tries, default 900), `HARNESS_RETRY_WAITS` (seconds between retries of a provider
    error, default `30,120,300,900`), `HARNESS_CLAUDE` (the `claude` command).
  `python3 harness/loop.py status` ends with tokens and a cost estimate per leg kind and model.
- **Long-lived sign-in**: `~/.config/claude/oauth.env` with `CLAUDE_CODE_OAUTH_TOKEN=<token>` from
  `claude setup-token`. `harness/run.sh` loads it when it exists.
- **Secrets**: when the `secret` helper is on PATH and `~/.config/openbao/<project-slug>.token`
  exists, the project's values come from its vault project and sessions get `BAO_TOKEN` and
  `SECRET_PROJECT` for that project only; a secret with `"created_by": "agent"` is stored by the
  session with `secret set`. Otherwise values come from `.env`. On the droplet, `vault-project
  <project-slug>` creates the token file.
- **Deploying**: `deploy.by` in the spec, `john` (default) or `agent`. Only `agent` lets a session run
  deploy and publish commands. The loop reads it from the approved spec committed at the start of the
  leg, not from the working tree.
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
- **Usage.** Each task costs at least two sessions (work and verify), on Opus 5.5 by default; Fable
  does design, plan, judge and audit, and the second and third work attempt. A planning round has at
  most 12 tasks, so fewer, larger tasks. Each session's model, effort, tokens and cost estimate go
  into `PROGRESS.md` and the task's `legs` list in the ledger; `python3 harness/loop.py status` sums
  them per kind and model. On a usage limit a work or verify session switches model at once; other
  sessions wait up to `HARNESS_LIMIT_HOURS`, then the run stops and resumes when you start it again.
- **Closing the laptop lid** suspends the machine unless you have turned that off.

## Checking the harness itself

`bash harness/tests/selftest.sh` runs the whole loop against a fake model that misbehaves on purpose
(a provider error, edits to the ledger and to checks, a bug only the auditor sees) and takes a few
seconds. CI runs it on every push.

## Where the method comes from

`harness/METHOD.md` lists the sources and what was taken from each.
