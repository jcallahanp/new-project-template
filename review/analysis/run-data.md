# Run data: opencode-ui build (branch build-ro, 7901f58)

Source: `/home/user/opencode-ui` at `build-ro` (= origin `build/opencode-ui`), 161 commits. Times in PROGRESS.md are UTC; git times are -0500 (13:08 EST = 18:08Z).
`/home/user/paperclip-cockpit` was not used: its PROGRESS.md has no turns or seconds (0 matches for "turns"; 120 lines, hand-written format), so it gives no per-step data.

## Script output (verbatim)

Produced by `python3 review/analysis/ledger_stats.py /home/user/opencode-ui`. Headings below are the script's own.

Source: `/home/user/opencode-ui` — 78 PROGRESS entries, 67 ledger cards (55 tasks, 10 milestones).

## 1. Legs by type

A leg = one `claude -p` session. Counted from `(N turns, Ns)` in PROGRESS.md; a work entry may hold a work leg and a verify leg.

| leg type | count | zero-turn legs (timeouts) |
|---|---|---|
| design | 1 | 0 |
| plan | 6 | 2 |
| work | 66 | 1 |
| verify | 54 | 0 |
| audit | 0 | 0 |
| **total** | **127** | |

### Turns and seconds per leg type

| leg type | n | turns sum | turns median | turns max |
|---|---|---|---|---|
| design | 1 | 38 | 38 | 38 |
| plan | 6 | 117 | 21.5 | 38 |
| work | 66 | 1187 | 16 | 53 |
| verify | 54 | 673 | 11 | 24 |
| audit | 0 | - | - | - |

| leg type | n | seconds sum | seconds median | seconds max |
|---|---|---|---|---|
| design | 1 | 1611 | 1611 | 1611 |
| plan | 6 | 7486 | 1428.5 | 1800 |
| work | 66 | 33867 | 380 | 2700 |
| verify | 54 | 9851 | 151.5 | 774 |
| audit | 0 | - | - | - |

Sum over all legs: 2015 turns, 52815 s (14h40m).

Share of leg seconds by type: design 3%, plan 14%, work 64%, verify 19%, audit 0%.

Per-leg token use, cost, model and effort: not recorded in PROGRESS.md or ledger.jsonl.

## 2. Work attempts per task

| outcome | tasks |
|---|---|
| passed first try | 45 |
| passed second try | 4 |
| passed third try | 2 |
| blocked after 3 failed attempts, then passed after a human reset | 1 |
| blocked after 3 failed attempts, not passed yet (ledger state: todo) | 1 |
| not started (no work leg yet) | 2 |
| **tasks with at least one work leg** | **53** |

Work entries: 66 (52 passed, 14 failed). Tasks that needed a retry (F = failed attempt, P = pass, in order):

- M2.T7: FP — passed second try
- M2.T11: FFP — passed third try
- M2.T14: FFFP — blocked after 3 failed attempts, then passed after a human reset
- M3.T11: FFP — passed third try
- M4.T9: FP — passed second try
- M4.T11: FP — passed second try
- M4.T12: FFF — blocked after 3 failed attempts, not passed yet (ledger state: todo)
- M4.T15: FP — passed second try

## 3. Failures by stage

Stage from the entry text: timeout = "stopped at its N-minute limit"; gates = "gates failed"; check = "task check ... failed"; verify = "fail at verify"; other = rest.

| stage | failed work steps | seconds spent in those steps (work+verify legs) | turns |
|---|---|---|---|
| check | 8 | 3964 | 140 |
| gates | 3 | 927 | 50 |
| verify | 2 | 3264 | 52 |
| timeout | 1 | 2700 | 0 |
| other | 0 | 0 | 0 |
| **all** | **14** | **10855** (3h00m) | 242 |

14 of 66 work steps failed (21%). Seconds in passing work steps (work+verify): 32863.

What failed inside `check` and `gates`: the loop writes only the first line of the message into PROGRESS.md ("task check `...` failed:" / "gates failed:"); the failing output is not recorded there. ledger.jsonl keeps the last failure text only until the task passes (the note is then overwritten with "verified: ...").

## 4. Verify legs

Verify legs run: 54 (only after the work leg's check and gates passed). Verifier FAIL: 2 (3.7%). Verifier PASS: 52.

Verifier reasons, grouped (the loop stores only the first line, cut at 200 characters):

- x1 a reset (or close) whose abort lands while a folder's first turn is starting leaves every session in that folder unable to reply (later messages answer 202 but never reach the model, card shows `inter
- x1 a reset or close within about 300 ms of a brand-new card's first message still breaks the folder (every later turn ends as an empty MessageAbortedError with no model request), and the new spec misses 

Verifier PASS texts: x52 "the verifier found no defect".

Seconds spent in verify legs that passed: 9103; in verify legs that failed: 748.

## 5. Planning rounds per milestone and plan rejections

| milestone | plan legs | accepted | rejected | ledger `rounds` | tasks planned | state |
|---|---|---|---|---|---|---|
| M1 | 1 | 1 | 0 | 1 | 12 | done |
| M2 | 2 | 1 | 1 | 1 | 16 | done |
| M3 | 2 | 1 | 1 | 1 | 11 | done |
| M4 | 1 | 1 | 0 | 1 | 16 | doing |

Not yet planned (0 plan legs): M5, M6, M7, M8, M9, M10.

Plan rejections (reason = first line of the message):

- 2026-11-14T04:08:32Z M2: the session was stopped at its 30-minute limit: the step is too big or it got stuck. Do less in one step. (0 turns, 1800s)
- 2026-11-14T14:54:18Z M3: the session was stopped at its 30-minute limit: the step is too big or it got stuck. Do less in one step. (0 turns, 1800s)

Acceptance-failure replans ("tasks done but acceptance fails"): 0. Milestones closed: 3. Milestones blocked by their tasks: 1.

## 6. Wall-clock and gaps

First entry 2026-11-14T01:16:08Z (DESIGN), last entry 2026-11-14T22:21:43Z (M4.T15): 21h05m (75935 s) wall-clock. Entry timestamps are written at the end of a step.

Time inside recorded legs: 52815 s (14h40m) = 70% of wall-clock. The rest (6h25m) is time the log does not attribute: the loop's own checks, gates and acceptance runs, git, and any waiting or stop. It cannot be split further from these files.

Gap = time from the previous entry to this one. "unattributed" = gap minus this entry's recorded leg seconds.

| gap > 30 min | before entry | entry | gap | legs in entry | unattributed |
|---|---|---|---|---|---|
| 1 | 2026-11-14T03:38:19Z M1 | 2026-11-14T04:08:32Z M2 (plan FAIL) | 30m13s | 1800s | 0m13s |
| 2 | 2026-11-14T06:49:17Z M2.T11 | 2026-11-14T07:22:24Z M2.T11 (work FAIL) | 33m07s | 1959s | 0m28s |
| 3 | 2026-11-14T07:22:24Z M2.T11 | 2026-11-14T08:00:55Z M2.T11 (work) | 38m31s | 2281s | 0m30s |
| 4 | 2026-11-14T08:42:27Z M2 | 2026-11-14T13:37:02Z M2.T14 (work) | 4h54m | 1956s | 4h21m |
| 5 | 2026-11-14T14:23:43Z M2 | 2026-11-14T14:54:18Z M3 (plan FAIL) | 30m35s | 1800s | 0m35s |
| 6 | 2026-11-14T16:58:07Z M3.T10 | 2026-11-14T17:43:07Z M3.T11 (work FAIL) | 45m00s | 2700s | 0m00s |
| 7 | 2026-11-14T18:08:26Z M3.T11 | 2026-11-14T19:09:17Z M3.T11 (work) | 1h00m | 1529s | 35m22s |
| 8 | 2026-11-14T19:21:29Z M3 | 2026-11-14T19:53:56Z M4 (plan) | 32m27s | 1555s | 6m32s |

Unattributed time by entry kind (gap minus recorded leg seconds; includes the loop's check, gates and acceptance time):

| entry kind | entries | sum | median | max |
|---|---|---|---|---|
| work pass | 52 | 5h32m | 0m33s | 4h21m |
| work fail (check) | 8 | 16m36s | 0m52s | 10m46s |
| plan pass | 4 | 15m56s | 4m42s | 6m32s |
| milestone closed | 3 | 15m32s | 2m48s | 12m12s |
| work fail (gates) | 3 | 2m34s | 0m42s | 1m14s |

Usage-limit waits: not recorded as such. The loop has a wait counter (`WAITED`) but PROGRESS.md has no wait entry; gaps with large unattributed time are the only trace.

## 7. Tasks per milestone and files per task

| milestone | requirements | tasks | done | files per task (min / median / max) | distinct files | task seconds (work+verify legs) |
|---|---|---|---|---|---|---|
| M1 | 2 | 12 | 12 | 2 / 5.5 / 10 | 44 | 5360 |
| M2 | 4 | 16 | 16 | 1 / 5.5 / 8 | 40 | 19817 |
| M3 | 5 | 11 | 11 | 1 / 6 / 10 | 31 | 10777 |
| M4 | 4 | 16 | 13 | 1 / 4 / 7 | 28 | 7764 |

All planned tasks: 55; files per task min 1, median 5, max 10, mean 5.1.

Seconds per passing task (work+verify legs of the passing step only):

n=52, median 552 s, max 2281 s, sum 32863 s.

Wall-clock per milestone (previous milestone-close entry to this one's close entry):

- M1: 1h55m (closed 2026-11-14T03:38:19Z)
- M2: 10h45m (closed 2026-11-14T14:23:43Z)
- M3: 4h57m (closed 2026-11-14T19:21:29Z)

Files changed per task by the work leg (actual diff size), lines of code, tokens: not recorded (the ledger `files` field is the plan's file list, not the diff).

---

## The 600 MB case

Everything here is from the repo at 7901f58 unless marked inferred.

**Requirement.** R24 at spec approval 0ddec8c (2026-11-13): "While 3 agents and 20 subagents are active, the system shall keep the combined resident memory of the OpenCode server and the UI server under 600 MB" (`spec/requirements.json` R24, now at lines 396-413 with the 1000 MB text). Its `verify`: "Soak script starts the load with the mock model, samples /proc RSS of the service cgroup every 10 s, asserts the max < 600 MB, then lowers the limit in test mode to trigger the banner." (`git show 0ddec8c:spec/requirements.json`, line 412; same line now says 1000.)

**How the check measures.** `checks/acceptance/R24.sh` runs `scripts/soak.mjs --minutes 10 --sample 10` (line 56, timeout 780 s) and, in parallel, its own sampler every 10 s (lines 40-53): `rss_now()` sums `VmRSS` from `/proc/<pid>/status` for the UI server, the engine and engine children with the same executable. `scripts/soak.mjs:305-322` does the same (UI RSS + engine RSS + descendants). 3 cards, 20 child sessions, 61 samples. It fails if either soak max or its own max is not below the limit; in the 600 version: `[ "$OWN_MAX" -lt 600 ] || fail "... reached $OWN_MAX MB (limit 600 MB)"` (R24.sh line 69 at e69debe~1). The two figures must also agree within 60 MB. Measured RSS, not a budget estimate; a 10-minute run is about 13 minutes of wall time (timeout 780 s).

**Attempts** (ledger/PROGRESS = what the loop recorded; evidence = `notes/M3.T11/evidence/README.md`):

| # | what happened | measured | source |
|---|---|---|---|
| 1 | work leg hit the 45-minute limit, 0 turns recorded, 2700 s; a commit exists anyway | 10-min soak: max 609 MB (UI 106, engine 505), over 600 | PROGRESS.md 17:43:07Z M3.T11; ledger note at c00da51; aee7603; README table row `exp-10min-ui-flags-only.json` |
| 2 | work leg 20 turns, 873 s; fail at check. Worker's own run: max 563 MB, "passed"; the loop's re-run of the check failed | loop re-run: soak max 595, check's own /proc sampler 601: `FAIL R24: the check's own /proc samples reached 601 MB (limit 600 MB)` | PROGRESS.md 18:08:26Z; ledger note at e0de4d3; 26d9aba |
| 3 | John raised the limit; work leg 14 turns 755 s + verify 18 turns 774 s; pass | soak max 598 (own max 596) against 1000 | PROGRESS.md 19:09:17Z; `notes/M3.T11/evidence/check.log`; 42035c0 |

Other over-limit runs in the evidence table (not separate loop attempts): 2-minute baseline 603 MB (`before.json`), 10-minute with engine hint 320 MiB 603 MB (`exp-10min-hint320.json`). So the "601-609" values are 601, 603, 603, 609. The fix tried in attempt 2 was `BUN_JSC_forceRAMSize` 128 MiB in `bin/ocui-engine` (26d9aba); it made `checks/tasks/M1.T5.sh` and `M1.T9.sh`, which pin 402653184, fail (README, "What the numbers said"). The README also says the machine was swapping (5.8 GB of 7.6 GB swap in use), which lowers resident figures, and the spread between the worker's run (563) and the loop's run (601) was 32 MB in the soak max (563 vs 595) for the same code (measured; both runs are of the 26d9aba code, inferred).

**Commits.** aee7603 work(M3.T11) "Hold the 600 MB budget" (12:43 EST); 26d9aba hint to 128 MiB (12:57); e0de4d3 chore todo (13:08); 3aa05ca spec re-approved with R24 at 1000 MB (13:30:27, John); e69debe "raise R24 memory limit to 1000 MB (John, 2026-11-14)" (13:31, updates R24.sh and M3.T11.sh, resets M3.T11 to attempt 0 with a narrowed acceptance); 42035c0 limit 1000, hint back to 384 MiB (13:44); 0bdbe95 M3.T11 done (14:09); 38c7a7f M3 done.

**What the human did.** John changed the number, not the product: 600 to 1000 MB in R24 (3aa05ca) and the checks (e69debe). The original 600 came from the spec John approved on 2026-11-13; DESIGN.md:121 now says "R24's limit was raised from 600 MB to 1000 MB by John on 2026-11-14". The reset task's acceptance told the worker: "Do not run extra soak experiments: earlier attempts measured 563-609 MB peaks, well under the new limit."

**Cost, measured.** M3.T11 legs: 2700 + 873 + 755 + 774 = 5102 s; the two failed ones 3573 s (59 min), 20 turns recorded (0 + 20). Wall from M3.T10 entry (16:58:07Z) to M3.T11 pass (19:09:17Z) is 2h11m, against a median passing task of 552 s. Roughly 35 min of that is a stop with no leg running (18:08Z to ~18:44Z; inferred from the 35m22s unattributed time and John's commits at 18:30-18:31Z; PROGRESS does not say the loop was stopped). Measured margin after the change: peak 598 of 1000 MB. Inferred: the requirement was set tighter than the system needed, and the third attempt would have needed a product change (engine hint) that broke two other tasks' checks.

## Where the steps went

Measured unless marked (inferred) or (derived).

- 127 legs, 2015 turns, 52815 s (14h40m) inside legs, in 21h05m wall-clock (70%); 3 milestones closed, 52 of 55 planned tasks done, 6 milestones (M5-M10) not planned, M4 in progress. Wall per done task: 24m20s (derived: 75935 s / 52).
- Work legs are 64% of leg seconds (33867 s, 66 legs, median 380 s, max 2700 s); verify 19% (9851 s, 54 legs, median 151 s); plan 14% (7486 s, 6 legs); design 3% (1611 s, 1 leg).
- 14 of 66 work steps failed (21%) and used 10855 s, 20.6% of leg seconds (derived). By stage: check 8, gates 3, verify 2, timeout 1.
- 45 of 53 started tasks passed on the first work attempt; 6 needed 2-3; 2 hit 3 failures (M2.T14, M4.T12). Both were fixed by editing the check (67ebb89 "fix(M2.T14 check)"; 7901f58 "fix ... M4.T12 check: impossible wait"), per their commit messages. Their 3 failed attempts cost 1143 s and 1106 s (derived: 799+192+152; 569+220+317), 24 and 64 turns.
- Verify: 52 of 54 passed; 2 FAILs (3.7%), both on M2.T11, together 748 s of verify time. The 52 passing verifies cost 9103 s (17% of leg seconds, derived). Whether verify prevented later cost is not measurable here.
- 3 timeouts: 2 plan legs at 1800 s (M2, M3) and 1 work leg at 2700 s (M3.T11), all 0 turns recorded: 6300 s, 11.9% of leg seconds (derived). The re-plans that followed took 303 s (M2, 23 turns) and 726 s (M3, 20 turns) (PROGRESS.md lines 108 and 264), i.e. the timeout cost 6x and 2.5x the successful run (derived).
- Unattributed time is 6h25m (derived: wall minus leg seconds). One stop is 4h21m (M2.T14 blocked 08:42Z, John's fix 67ebb89 at 13:02Z), another 35m22s (M3.T11). The remaining about 1h29m is spread over 76 entries (gates, checks, acceptance, git; milestone close entries average 5m11s). No entry shows a usage-limit wait (inferred from the absence of other large gaps).
- Three tasks needed a human: M2.T14 (67ebb89), M3.T11 (e69debe), M4.T12 (7901f58); measured from those commits and the ledger note "reset by John's approval" on M4.T12.
- The run ended at M4 with 3 tasks open (M4.T12 todo after reset, M4.T13, M4.T16); last PROGRESS entry 22:21:43Z, last commit 7901f58 at 22:29Z is John's reset (the stop reason is not in PROGRESS.md).

## Not recorded

- Tokens, cost, usage-limit consumption per leg: not in PROGRESS.md or ledger.jsonl. Only `turns` and `secs`.
- Model and effort per leg: not recorded. Git trailers on 72 of 161 commits name "Claude Fable 5.2" (67) or "Claude Opus 5.5" (5); the 5 Opus commits are the ones John's sessions made (e.g. e69debe, 67ebb89, 7901f58; inferred). Loop `chore(...)` commits (84) carry no trailer.
- Failing output of a failed check or gate: only the first line ("task check `...` failed:"). The full text lives in the ledger note until the task passes, then it is overwritten ("verified: ..."); older notes only in git history of ledger.jsonl.
- Verifier reasons are cut to the first line and 200 characters; verifier PASS carries no text.
- Retried provider calls (429, 5xx, usage-limit polling) are not logged: `session()` in `harness/loop.py:256-275` retries `run_claude` and only the last call's `secs` is written, so waits show up only as unattributed time. The loop's `WAITED` counter is not written to PROGRESS.md.
- Time inside the loop (check script, gates, acceptance, git) per step: not recorded separately.
- Why the run stopped each time (loop `finish()` message): not in PROGRESS.md.
- Diff size per work leg (files, lines) and the ledger's `files` (planned list only).
- Whether a stop was waiting for John: only inferable from commit times.
