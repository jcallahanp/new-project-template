# SPEC: cost and time review of `autonomous-project-template`

Status: DRAFT. Personas and open questions wait for John's answers.

## Goal

Find why the `autonomous-project-template` harness costs so much money and wall-clock time, and find
changes that cut cost or time by a large amount with no loss of reliability. Make the harness fit a
Linux VM where the agent has full control (`--dangerously-skip-permissions`, a secrets manager it
can use to create its own API keys).

## Questions to answer

1. Is the harness best practice, and is it reliable?
2. Where can we save large cost or time without loss of reliability?
3. Is it too rigid? Are its checks unrealistically hard to pass (example: a 600 MB RAM limit that
   failed three times at 601 to 609 MB and cost about $50)?
4. Is it ready for a VM with full control and a secrets manager?

## Personas (draft, confirm with John)

- "I am John, using the template on a Linux VM. I describe a project and approve the spec. I trust
  the run to deliver a correct, verified project. I never pay Fable prices for routine work, and I
  never see $50 spent to save 1 MB."
- "I am John, reading a stopped run. I see in one line what it needs from me. A near miss on a
  soft target reaches me as a question, not as three blind retries."
- "I am John, reviewing the bill. I see the cost of each step in the ledger. I can tell which step
  type uses the money."
- "I am an unattended worker session on the VM. I can get the API keys I need from the secrets
  manager. I cannot spend money, delete live data or publish anything the spec does not allow."

## Constraints

- No loss of reliability. Each saving needs evidence (real run data or a clear mechanism), not a guess.
- Simplest working change. No new abstraction layer without John's approval.
- The original template stays unchanged until John approves a change.
- State lives in this repo: `SPEC.md`, `PLAN.md`, `PROGRESS.md`, `FINDINGS.md`.

## Hypotheses to test (from a first read; not verified with run data)

| # | Hypothesis | Evidence in `autonomous-project-template` |
|---|---|---|
| H1 | Every step runs on Fable 5.2 at effort `high`, including verify and the scout/critic subagents. Fable 5.2 costs 2x Opus 5.5 and 4x Sonnet 5.5 per token. | `harness/loop.py:53-54`; `.claude/agents/*.md` have no `model` field |
| H2 | Each task costs at least two fresh sessions (work and verify). The verifier repeats work the scripts already did. | `harness/loop.py:775-781` |
| H3 | Tasks are very small (up to 25 per planning round, "well under an hour"). Each fresh session pays a fixed start-up cost to re-read the repo. | `harness/prompts/plan.md:37`, `harness/loop.py:64` |
| H4 | The same tests run three to four times per task: worker, loop, verifier, and at plan time. | `harness/loop.py:509,517,549-550`; `harness/prompts/work.md:20`; `harness/prompts/verify.md:18` |
| H5 | The interview turns a rough estimate into a hard limit with no tolerance. A near miss gets three full retries, then blocks. Nothing separates a hard limit from a target. | `.claude/skills/intake/SKILL.md:116`; `harness/loop.py:60,786-790` |
| H6 | The loop discards the cost data that `claude -p` returns, so no record shows where money goes. | `harness/loop.py:236-239` |
| H7 | Tasks run one at a time, also when `depends_on` shows they are independent. | `harness/loop.py:770` |
| H8 | Settings fit the old laptop, not a VM: deny list names old paths, lid check, `notify-send`, secrets only from a hand-filled `.env`, `gh` and `git push` denied. | `harness/run-settings.json`, `harness/preflight.sh:45-50`, `harness/loop.py:672` |

## Open questions for John

See `PROGRESS.md` (section "Waiting on John").
