# Autonomous project template

Describe what you want, answer an interview, approve the written requirements, supply the secrets, and
an unattended run builds the project, checks it against every requirement, and opens a pull request
with a delivery report. Built for Claude Code with Fable on the Max plan.

This file is the template's guide. Once a project is under way, a worker session may replace it with
the project's own README; the harness guide stays in `harness/README.md`.

## Start a new project

```bash
gh repo create my-project --private --template jcallahanp/autonomous-project-template --clone
cd my-project
claude
```

Then type `/intake` and describe what you want. The session will:

1. **Interview you**, one question at a time, about the outcome you need and why, real examples, what
   can go wrong, what it must never do, constraints, outside services, and what "ready to deploy" means.
2. **Write the spec** (`spec/requirements.json`): user stories, one testable requirement each, concrete
   examples, non-goals, the secrets it needs by name.
3. **Show it to you** and change it until you say it is right. Only then is it recorded as approved.
4. **Ask you to put secret values in `.env`** yourself (never in the chat, never in git).
5. **Run a preflight** (sign-in, tools, secrets, git, gates) and **start the build** in a tmux session.

After that you can close the terminal.

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
sign-in expired; or the budget (24 hours by default) is used. It sends a desktop notification and
writes the reason to `.harness-run/last-stop.txt`.

## What you get at the end

- A `build/<project>` branch with the finished project, pushed, and a pull request for you to merge.
- `DELIVERY.md`: every requirement, the check that proves it, and the result of a fresh run of each.
- `PROGRESS.md` and `ledger.jsonl`: every step, its check and its commit.

How it works, why each part exists and how to change it: `harness/README.md`.
