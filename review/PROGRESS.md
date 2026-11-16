# PROGRESS

## State

Phase: T1 (droplet inventory) waits for John. T2 runs. T3 done.

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

## Waiting on John

1. Run `review/prompts/warp-inventory-prompt.md` in Warp (T1).
2. Confirm or correct the personas in `review/SPEC.md`.
3. This repository is public. Make it private, or keep it public? The inventory filters personal
   data, but a private repo is safer for findings about your machine.

## Next

T2 and T3 (run-data analysis), then T4 when T1 is in.
