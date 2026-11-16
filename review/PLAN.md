# PLAN: harness review

Deliverables (John, 2026-11-16): `review/FINDINGS.md` (report) and an improved copy of the template
at the root of this repo. The original `autonomous-project-template` stays unchanged.

Layout decision (Claude, 2026-11-16): the improved template lives at the repo root, so
`gh repo create --template jcallahanp/new-project-template` works. Review state lives in `review/`.

## Tasks

Rules: one new agent per task; the agent that does a task never grades it. Each task has a
deterministic check. Status lives in `review/PROGRESS.md`.

| Id | Task | Output | Check (deterministic) | Depends on |
|---|---|---|---|---|
| T1 | Droplet inventory: John runs `review/prompts/warp-inventory-prompt.md` in Warp | `review/inventory/droplet.md` | File has sections 1 to 12; `grep -E` for emails, IPv4, `sk-`, `ghp_`, `bws_` finds nothing | none |
| T2 | Run-data analysis: per-leg counts, turns, time, retries and failure causes from `opencode-ui` (`build/opencode-ui` at `7901f58`) and `paperclip-cockpit`; the 600 MB case traced end to end | `review/analysis/ledger_stats.py`, `review/analysis/run-data.md` | `python3 review/analysis/ledger_stats.py <repo>` re-prints every number in `run-data.md` (diff empty) | none |
| T3 | Compare the template with the newer harness fixes already in `opencode-ui` `main` (`feb4339`: replan fix, verdict parsing, plan time limit, subagent models) | section in `review/analysis/run-data.md` | Each difference cites a commit and `path:line` | none |
| T4 | Findings report: the four questions in `SPEC.md`, savings ranked by size, each with evidence and a reliability argument | `review/FINDINGS.md` | Every recommendation cites `path:line`, a data row from T2, or an inventory line from T1 (script counts uncited items: 0); a separate reviewer agent grades it against `SPEC.md` | T1, T2, T3 |
| T5 | John approves the list of template changes in `FINDINGS.md` | Decisions in this file | John's yes, with the date | T4 |
| T6 | Improved template at the repo root (copy of `autonomous-project-template` plus the approved changes), in the sub-tasks below, one after another (they share `harness/loop.py`) | template files | Per sub-task: `bash harness/tests/selftest.sh` passes, including new cases for the changed behaviour; a separate reviewer agent checks the diff against the finding | T5 |
| T6a | C7 (`feb4339` fixes) and C9 (subagent models) | `harness/loop.py`, `.claude/agents/` | self-test; `diff` against `opencode-ui` `feb4339` shows the same lines | T5 |
| T6b | C1 (model per leg, escalation), C2 (fallback on a usage limit for work and verify), C5 (usage per leg in `PROGRESS.md` and the ledger) | `harness/loop.py`, `harness/tests/` | self-test cases: model chosen per leg and attempt; limit on Fable falls back for work, waits for plan; usage fields recorded | T6a |
| T6c | C3 (`CHECK-WRONG` judged by a verifier), C6 (verifier brief with the loop's check output, no re-runs) | `harness/loop.py`, `harness/prompts/`, `CLAUDE.md`, `harness/tests/` | self-test cases: agreed claim blocks and notifies; rejected claim counts as an attempt; claim on attempt 1 ignored | T6b |
| T6d | C4 (hard or target numbers with margins) and C8 (12 tasks per round, about 30-minute tasks) | `.claude/skills/intake/SKILL.md`, `harness/spec.py`, `harness/prompts/plan.md`, `harness/loop.py`, `harness/tests/` | `spec.py check` rejects a number without `hard`/`target`; self-test spec updated and passing | T6c |
| T6e | C10 (scoped secrets through `secret`), C11 (droplet preflight, token file), C12 (browser MCP for web UIs) | `harness/loop.py`, `harness/spec.py`, `harness/run-settings.json`, `harness/preflight.sh`, `harness/run.sh`, `harness/prompts/design.md`, `harness/tests/` | self-test with a fake `secret` helper: only spec-named secrets reach the check env; deny list has no old-laptop paths | T6d |
| T6f | Docs: `README.md`, `harness/README.md`, `harness/METHOD.md` describe the changes | docs | a reviewer agent finds no doc claim that the code contradicts | T6e |
| T8 | Before the merge to `main`: move `review/` to branch `review-archive` and delete it from the merge, so new projects do not copy it | branch | `git ls-tree origin/main` has no `review/` after the merge | T6, T7 |
| T7 | Droplet fixes that block reliable unattended runs (prompts for Warp, John approves each) | `review/prompts/droplet-fixes.md` | Re-run of the T1 inventory shows each fix | T4 |

## Decisions

- 2026-11-16 (John): Max plan. Cost means usage quota and waiting time, not dollars. Dollar figures
  are only a way to compare (public API prices).
- 2026-11-16 (John): deliver a findings report and an improved copy of the template.
- 2026-11-16 (John): inventory the droplet through the Claude Code session in Warp first.
- 2026-11-16 (John): approved the change list in `review/FINDINGS.md` (C1 to C12; droplet D1, D3,
  D5). The repository stays public. The personas in `SPEC.md` are correct.
