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
| T6 | Improved template at the repo root (copy of `autonomous-project-template` plus the approved changes) | template files | `bash harness/tests/selftest.sh` passes; new self-test cases for each changed behaviour pass; a separate reviewer agent checks each change against its finding | T5 |
| T7 | Droplet fixes that block reliable unattended runs (prompts for Warp, John approves each) | `review/prompts/droplet-fixes.md` | Re-run of the T1 inventory shows each fix | T4 |

## Decisions

- 2026-11-16 (John): Max plan. Cost means usage quota and waiting time, not dollars. Dollar figures
  are only a way to compare (public API prices).
- 2026-11-16 (John): deliver a findings report and an improved copy of the template.
- 2026-11-16 (John): inventory the droplet through the Claude Code session in Warp first.
