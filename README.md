# Autonomous project template

Describe what you want, answer an interview, approve the written requirements, supply the secrets, and
an unattended run builds the project, checks it against every requirement, and opens a pull request
with a delivery report. Built for Claude Code on the Max plan: Fable 5.2 designs, plans, judges and
audits; Opus 5.5 does the work and the verification.

This file is the template's guide. Once a project is under way, a worker session may replace it with
the project's own README; the harness guide stays in `harness/README.md`.

## Start a new project

```bash
gh repo create my-project --private --template jcallahanp/new-project-template --clone
cd my-project
claude
```

Then type `/intake` and describe what you want. The session will:

1. **Interview you**, one question at a time, about the outcome you need and why, real examples, what
   can go wrong, what it must never do, constraints, outside services, and what "ready to deploy" means.
2. **Write the spec** (`spec/requirements.json`): user stories, one testable requirement each, concrete
   examples, non-goals, the secrets it needs by name. For every number (600 MB, 2 seconds) it asks
   whether it is a **hard limit** (fails at the value) or a **target** (passes within a margin you
   name), and how the number is measured. It also records who deploys: `deploy.by` is `john` unless
   you want the run to deploy and publish itself (`agent`).
3. **Show it to you** and change it until you say it is right. Only then is it recorded as approved.
4. **Ask you to supply secret values** yourself (never in the chat, never in git). On the droplet, if
   the project has its own vault token file (`~/.config/openbao/<project-slug>.token`) and the
   `secret` helper is on PATH, the values live in the vault: run `vault-project <project-slug>` once
   per project, then `secret --project <project-slug> set NAME -`. Otherwise they go in `.env`.
5. **Run a preflight** (sign-in, tools, secrets, git, gates, machine) and **start the build** in a
   tmux session.

After that you can close the terminal.

For a long run, save a long-lived sign-in: run `claude setup-token` once and put
`CLAUDE_CODE_OAUTH_TOKEN=<token>` in `~/.config/claude/oauth.env` (mode 600). `harness/run.sh` loads
that file when it exists. Without it, preflight warns when the interactive sign-in expires before the
run's budget ends.

## Models

| Step | Model |
|---|---|
| design, plan, judge, audit | Fable 5.2 |
| work, verify | Opus 5.5 |
| work, second and third attempt of a task | Fable 5.2 |

Effort is `high` for every step. If a usage limit is hit during a work or verify step, that step runs
at once on the other model; the other steps wait for the limit to clear (up to 8 hours by default).
`harness/README.md` lists the settings that change this.

## While it runs

| You want to | Command |
|---|---|
| See where it stands | `bash harness/run.sh status` |
| Watch it live | `tmux attach -t build-<folder>` (detach: Ctrl+b then d) |
| Read the log | `tail -f .harness-run/run.log` |
| Stop it | attach, then Ctrl+C. Nothing is lost. |
| Resume after any stop | `bash harness/run.sh` |
| Change the requirements | stop it, `claude`, `/intake` (change mode), then resume |

The run stops by itself, with the reason and what it needs from you, when: it is delivered; a task
failed three times; a milestone cannot pass its acceptance checks; the audit keeps finding gaps; the
sign-in expired; or the budget (24 hours by default) is used. It writes the reason to
`.harness-run/last-stop.txt`.

Alerts go to `.harness-run/alerts.log` and the run's output, and to a desktop notification through
`notify-send` when that is installed. You get one for every stop, for a task blocked because its check
is wrong, and for a leg that committed a secret value.

**A check that is wrong.** From the second attempt a worker may say the task's check itself is wrong.
A separate read-only judge decides. If it agrees, the task is blocked at once, you get an alert, and
the run goes on with other tasks; the note on the task says `check wrong (judge agreed)`. Fix the
requirement or the check, then resume.

## What you get at the end

- A `build/<project>` branch with the finished project, pushed, and a pull request for you to merge.
- `DELIVERY.md`: every requirement, the check that proves it, and the result of a fresh run of each.
- `PROGRESS.md` and `ledger.jsonl`: every step, its check and its commit. Each step line also shows the
  model, effort, tokens and a cost estimate (at API list prices). `bash harness/run.sh status` ends
  with the same numbers per step kind and model.

How it works, why each part exists and how to change it: `harness/README.md`.
