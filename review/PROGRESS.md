# PROGRESS

## State

Phase: T6 (improved template), sub-task T6d next.

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
- 2026-11-16: T1 done (John ran the Warp prompt; commit `7c4276b`): `review/inventory/droplet.md`.
  Check (by the lead): sections 1 to 12 present; the Warp session redacted personal connector names.
  Main facts: Max 20x, Fable is a separate limit; template run sessions denied `gh` and `~/.config`;
  guard blocks `harness/run.sh` everywhere; no long-lived Claude token; vault is OpenBao via `secret`;
  `claude -p` returns `usage` and `modelUsage`. Fixed the script filter that masked `total_cost_usd`.
- 2026-11-16: T4 draft: `review/FINDINGS.md` (lead wrote it). Check: `python3
  review/analysis/check_findings.py` -> 16 rows, 0 uncited. Independent Opus review running.
- 2026-11-16: T4 done. Independent Opus review: revision 1 FAIL (11 findings), revision 2 FAIL
  (4 small items), all 4 fixed in revision 3 as the reviewer specified. Check:
  `check_findings.py` -> 17 rows, 0 uncited. Main changes after review: C2 falls back only for work
  and verify; C3 needs a verifier to agree and starts at attempt 2; C10 uses a write-only vault
  token for run sessions; savings figures corrected.
- 2026-11-16: T5 done. John approved the change list, kept the repo public, confirmed the personas.
- 2026-11-16: T6 base: template `5c4290e` copied to the repo root (`git archive`). Check: `diff -rq`
  against the template shows no difference except `review/`; `bash harness/tests/selftest.sh` ->
  SELFTEST PASS. Added `CLAUDE.md` step 0 so sessions in this repo follow `review/`. T6 split into
  T6a to T6f; T8 added (keep `review/` out of `main`).
- 2026-11-16: T6a done (Opus agent, commit `46ee902`). Check (by the lead): `harness/loop.py`,
  `.claude/agents/scout.md` and `critic.md` byte-identical to `opencode-ui` `feb4339`; self-test
  PASS (14 legs) with new cases for markdown VERDICT/GAP lines and a frozen-acceptance re-plan.
- 2026-11-16: T6b done (Opus agent; commits `9ee9673`, `e0f9167`, `e1820df`, `5389a3b`). C1 model per
  leg kind with escalation, C2 fallback on a usage limit for work/verify, C5 usage per leg.
  Independent Opus review: PASS with 3 minor defects, then FAIL twice on new paths to a Stop (a
  persistent 429 ended the run after ~22 min; a 529 after a long wait ended the run), each fixed
  with a self-test case. Check (by the lead): self-test PASS (15 legs); removing the retry refill
  makes the self-test stop on `529 overloaded` (rc 1).
- 2026-11-16: T6c done (Opus agent; commits `3435121`, `3ae0706`). C3 CHECK-WRONG path with a
  read-only Fable judge; C6 verifier brief with the loop's check output. Independent review FAIL:
  a claim from a worker that changed nothing was dropped; alerts were silent without
  `notify-send`. Both fixed. Check (by the lead): self-test PASS; with the fix disabled the
  self-test blocks M1.T1 after 3 attempts with no judge (rc 1).

## Waiting on John

Nothing for T6. T7 prompts will each need John's yes.

## Next

T6a to T6f, one agent each, a separate reviewer after each. Then T7 (droplet prompts) and T8.
