# PROGRESS

## State

Phase: T1 (droplet inventory) waits for John. T2 and T3 done. T4 starts when T1 is in.

## Done

- 2026-11-16: Read all of `autonomous-project-template` (commit `5c4290e`). Wrote draft `SPEC.md`
  with personas and hypotheses H1 to H8.
- 2026-11-16: John answered: Max plan; findings report plus improved copy; inventory through Warp.
  Recorded in `SPEC.md` and `PLAN.md`.
- 2026-11-16: Found the run data (`opencode-ui`, `paperclip-cockpit`, `abliterated-research`) and the
  droplet setup (`linux-droplet-migration`, branch `claude/busy-maxwell-a339dj`, Phase 8).
- 2026-11-16: Wrote `review/prompts/droplet-inventory.sh` and `review/prompts/warp-inventory-prompt.md`.
  Check: `bash -n` passes; a dry run in the cloud container (NO_PROBE=1) exits 0, and section 5 with
  the repo copy of `guard.py` shows `bash harness/run.sh` BLOCKED for every project (the guard's
  opencode-ui hold matches any `harness/run.sh`).
- 2026-11-16: Moved review files into `review/`; the repo root is kept for the improved template.

- 2026-11-16: T3 done (Sonnet agent): `review/analysis/harness-diff.md`. All harness changes in
  opencode-ui come from commit `feb4339`: frozen acceptance checks skipped in the plan check
  (`loop.py:518`), tolerant VERDICT/GAP parsing (`loop.py:576,592-593`), plan leg limit 1800 s to
  2700 s (`loop.py:66`), scout on Sonnet and critic on Opus. Check (by the lead, not the agent):
  `diff` of `loop.py` and the agent files between template `5c4290e` and `feb4339` shows exactly these.
- 2026-11-16: T2 done (Sonnet agent): `review/analysis/ledger_stats.py`, `review/analysis/run-data.md`.
  Check (by the lead): the script re-run on `opencode-ui` `7901f58` exits 0 and all 163 output lines
  appear verbatim in `run-data.md`; the 600 MB story matches commit `e69debe` and R24 in the spec.
  Key numbers: 127 legs, 14h40m in legs, 21h05m wall, 52 tasks done; work 64 %, verify 19 %, plan
  14 % of leg time; verify failed 2 of 54; 14 of 66 work legs failed (20.6 % of leg time); 3
  timeouts (11.9 %); 3 tasks needed John, all fixed by changing a check or the limit, not the product.

## Waiting on John

1. Run `review/prompts/warp-inventory-prompt.md` in Warp (T1).
2. Confirm or correct the personas in `review/SPEC.md`.
3. This repository is public. Make it private, or keep it public? The inventory filters personal
   data, but a private repo is safer for findings about your machine.

## Next

T2 and T3 (run-data analysis), then T4 when T1 is in.
