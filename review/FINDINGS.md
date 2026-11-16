# Findings: cost, time and reliability of `autonomous-project-template`

Review of template commit `5c4290e`, its run data from `opencode-ui` (`build/opencode-ui` at
`7901f58`), and the droplet `johns-ubuntu`. Date: 2026-11-16. Revision 2, after the independent
review (record in `review/PROGRESS.md`).

Sources in this repo: `review/analysis/run-data.md` (T2, numbers from `ledger_stats.py`),
`review/analysis/harness-diff.md` (T3), `review/inventory/droplet.md` (T1). Paths without a repo
name are in `autonomous-project-template`.

## Summary

1. **Reliability is good, and the design is sound.** 45 of 53 tasks passed on the first attempt.
   No task was recorded done with a failing check. The design follows the long-running harness
   sources in `harness/METHOD.md` (fresh session per step, state in git, script-decided completion).
2. **The main cost is the model, not the method.** Every leg runs on Fable 5.2
   (`harness/loop.py:53`). Work and verify legs are 83 % of leg time, and each does one small,
   script-checked task. On Max 20x, Fable has its own limit (inventory section 11). Moving work and
   verify to Opus 5.5 cuts Fable use by about 80 % and moves that work to the limit that the other
   models share.
3. **Time is lost in two kinds of waiting.** John reports that most time went to waiting for the
   Fable limit to reset (`review/SPEC.md`, Context); by 2026-11-14 about 5 % of his Fable usage was
   left (`linux-droplet-migration` PROGRESS.md:434). The 21-hour window in the run data shows no
   limit wait; its two long stops (4 h 21 min and 35 min) were waits for John after a wrong check or
   limit (`review/analysis/run-data.md`).
4. **The checks are not too hard in general. Numeric limits are.** The interview turns a rough
   number into an exact pass/fail limit with no margin (`.claude/skills/intake/SKILL.md:116`). The
   600 MB check failed at 601 MB. Run-to-run spread for the same measure was larger than the miss
   (563 MB and 595 MB soak peaks).
5. **The droplet blocks the template in three places.** The guard hook blocks `harness/run.sh` in
   every project. Template sessions cannot use the secrets vault or `gh`. The long-lived Claude
   login token is missing.

## Q1. Is it best practice, and is it reliable?

Yes, with two gaps.

What works (evidence: `review/analysis/run-data.md`, "Where the steps went"):

- 127 legs, 52 tasks done, 3 milestones closed. No `done` without a passing check (gate
  `checks/check_progress.sh:26`).
- Fail-first checks, fresh sessions, protected paths and an independent verifier follow the
  sources in `harness/METHOD.md`. The harness self-test proves the loop's defenses without a model
  (`harness/tests/selftest.sh`).

Gaps:

- **No path to report a wrong check.** A worker that finds a wrong check can only fail
  (`CLAUDE.md`, rule 3). The loop tries 3 times (`harness/loop.py:60`), then blocks the task. All 3
  human interventions were wrong checks or limits: M2.T14 (`67ebb89`), M3.T11 (`e69debe`), M4.T12
  (`7901f58`). Their failed attempts used 5,822 s of leg time.
- **Timeouts are expensive.** 3 legs hit their time limit: 6,300 s, 11.9 % of leg time. A timed-out
  plan leg is rejected; the re-plans that followed took 303 s and 726 s. A timed-out work leg keeps
  its commit but counts as a failed attempt (`harness/loop.py:544`). `opencode-ui` already raised
  the plan limit (`feb4339`).

## Q2. Where to save large cost or time without loss of reliability

Ranked by size. Leg time is the proxy for usage, because the ledger records no tokens
(`review/analysis/run-data.md`, "Not recorded").

| # | Change | Saves | Reliability argument and guard |
|---|---|---|---|
| C1 | Model per leg type: Fable 5.2 for design, plan and audit; Opus 5.5 (effort `high`) for work and verify; a task's 2nd and 3rd work attempts on Fable | about 80 % of Fable use (work + verify = 83 % of leg time) | Each work task has a script check, the gates, a verifier and the audit behind it, and Fable still writes every check. Retries escalate to Fable. John already chose Opus 5.5 for the restart (`linux-droplet-migration` PLAN.md, decision of 2026-11-14). Revert signal from C5: first-attempt pass rate under 80 % (now 85 %) |
| C2 | On a usage limit during a work or verify leg, run it on the other model instead of waiting up to 8 h (`harness/loop.py:55,268-273`). Design, plan and audit legs still wait for Fable | the limit waits John reports | Only legs that a script check judges change model. Fable keeps writing the checks and judging the product. Each fallback is recorded in the ledger (C5) |
| C3 | "Check is wrong" path: from the 2nd attempt, a worker may end with `CHECK-WRONG: <reason>`. A verifier session judges the claim. If it agrees, the loop blocks the task, notifies John at once, and continues with other eligible tasks. If not, it is a normal failed attempt with the verifier's reason as feedback | the 3rd attempt of M2.T14 and M4.T12 (152 s and 317 s in this run); John hears of a wrong check 1 attempt earlier | Workers still cannot edit checks; only John does. A worker cannot stop a task alone: the verifier must agree. Not before the 2nd attempt, so the 6 tasks that passed on attempt 2 or 3 keep their retry |
| C4 | Numbers in the spec are `hard` or `target`, each with a margin. A target check records the value and passes within the margin; a hard limit fails exactly. The interview asks "hard limit or target? how much noise?" for each number | the 600 MB case: 3,573 s of failed legs, and a 2 h 11 min task | John decides in the interview which numbers are hard. A hard limit still fails exactly |
| C5 | Record usage per leg (model, effort, tokens, cost estimate, fallback used) in `PROGRESS.md` and the ledger | none directly; it makes C1, C2 and C8 measurable and revertible | Read-only. `claude -p` already returns `usage` and `modelUsage` (inventory section 9) |
| C6 | The verifier gets the loop's check and gate output in its brief, and does not run them again | part of verify's 19 % of leg time | The loop's run of the check and gates stays the authority (`harness/loop.py:549-550`). The verifier still reads the diff and uses the product. Effort stays `high` |
| C7 | Take the 3 fixes from `opencode-ui` `feb4339`: frozen acceptance checks in re-plans, tolerant VERDICT/GAP parsing, plan limit 2,700 s | plan rejections and plan timeouts of the kind seen in this run | Bug fixes found in a real run (`review/analysis/harness-diff.md`) |
| C8 | Fewer, larger tasks: at most 12 per planning round (now 25, `harness/loop.py:64`); a task is "up to about 30 minutes of work" (now "well under an hour", `harness/prompts/plan.md:37`), inside the 45-minute work limit | fewer sessions; each session pays about 20,000 tokens of fixed start-up (inventory section 9) and re-reads the repo | Median work leg was 380 s, so tasks have room. Revert signal from C5: first-attempt pass rate under 80 % or more work timeouts |
| C9 | Scout subagent on Sonnet 5.5 and critic on Opus 5.5 (now they inherit Fable) | small | Read-only helpers. `opencode-ui` already does this (`feb4339`) |

Not proposed:

- **Parallel tasks in separate worktrees.** This saves wall-clock time but uses the same quota. On
  4 CPUs and 8 GB shared with a desktop, timing-sensitive checks are a risk: the run already had to
  loosen a health timing test (`7901f58`). It also adds a layer.
- **Dropping the verifier, or lowering its effort.** It failed only 2 of 54 times, but it is the
  defense against gamed checks. C1 and C6 make it cheaper instead.

## Q3. Is it too rigid? Are the checks unrealistically hard to pass?

The checks as a whole are not too hard: 45 of 53 tasks passed on the first attempt. Two things are
rigid:

1. **Every number becomes an exact limit.** `spec.py` rejects vague words (`harness/spec.py:25`)
   and the interview asks for numbers (`.claude/skills/intake/SKILL.md:116`). Nothing asks whether a
   number is a hard limit or a rough estimate, or how noisy its measurement is. In the 600 MB case,
   soak peaks for comparable code were 563 MB and 595 MB, and the machine was swapping
   (`review/analysis/run-data.md`, "The 600 MB case"). After the limit went to 1000 MB, the passing
   run peaked at 598 MB with the engine memory hint back at 384 MiB (`42035c0`): the cure was the
   limit, not a smaller product.
2. **Three attempts, then a block, also for problems a retry cannot fix.** A wrong check fails the
   same way each time (C3).

## Q4. Is it ready for the droplet with full control and a secrets manager?

Not yet.

**Permissions under full control.** Run sessions should keep the template's own settings file, not
bypass mode. `claude -p` with an allow list never stops for a prompt, so it is as unattended as
bypass, and its deny list is the hard stop for each run (`harness/run-settings.json`). The probe
proves the deny list applies on the droplet (inventory section 9). Bypass mode stays for John's
own and `crun` sessions (inventory section 12). The hard stops in a run are: the deny list, the
template guard (`harness/guard.sh`), the loop's restore of protected paths, and the droplet guard
for payments and pentesting. Whether the droplet guard also loads in `--settings` runs is not yet
proven; T6 tests it.

Blockers and risks found with the inventory (`review/inventory/droplet.md`):

| # | Problem | Evidence | Fix | Where |
|---|---|---|---|---|
| D1 | The guard hook blocks `bash harness/run.sh` in every project, so `/intake` cannot launch a run. It also blocks opencode-ui gates when a command names that path, which can fail workers after the restart | inventory section 5 | Hold only `~/projects/opencode-ui`, through a hold file John deletes to release it | droplet (T7) |
| D2 | Template sessions cannot use the vault or `gh`: `Read(~/.config/**)` and `Bash(gh:*)` are denied. The deny list also names old-laptop paths | inventory section 9; `harness/run-settings.json:7-11` | C10 | template |
| D3 | No long-lived Claude token: `~/.config/claude/oauth.env` is missing, so unattended runs stop when the login expires | inventory sections 2 and 12 | John runs `claude setup-token` once (T7). C11: `run.sh` loads that file when present, and preflight warns when `credential_expires_at` (returned by `claude -p`, inventory section 9) is earlier than the end of the run budget | droplet and template |
| D4 | The template's secrets model is "John fills `.env`". On the droplet the vault is OpenBao through the `secret` helper, not Bitwarden | inventory section 7 | C10 | template |
| D5 | `wrangler` is not signed in, and the agent browser is signed in to no site, so agents cannot create keys yet | inventory sections 8 and 11 | John signs in once (Phase 8 of the migration). Preflight fails with a clear message when the spec needs an agent-created key | droplet (T7) |
| D6 | `harness/mcp.json` is empty, so run sessions have no browser. The droplet has `agent-browser` | inventory section 6 | C12 | template |
| D7 | Memory and timing checks are noisy on a shared 8 GB machine; about 1.3 GB of Chrome processes ran during the inventory | inventory section 1; the 600 MB case | C4 margins; C11 preflight warns when desktop browsers use more than 1 GB | template |
| D8 | earlyoom kills `chrome` and `playwright.*` first, and acceptance checks drive Playwright. An out-of-memory kill would count as a failed attempt | inventory section 1 (`EARLYOOM_ARGS`) | Same preflight warning as D7; the earlyoom alert (`earlyoom-notify`) tells John when it happens | droplet and template |

Template changes for the droplet:

- **C10 secrets, scoped.** The loop, not the model, reads secrets: `child_env()` loads only the
  secret names in the approved spec, through `secret env` when the helper exists, else from `.env`.
  Each project uses its own vault token that can read only that project's keys. Run sessions get no
  vault token, keep the `~/.config` read deny, and may only `secret set` keys that the spec marks
  `created_by: agent`. Deploy commands (`wrangler deploy` and the like) are denied in run sessions
  unless the approved spec lists the deploy. Old-laptop paths leave the deny list.
- **C11 preflight for the droplet:** token expiry, vault reachable, the spec's secrets present,
  heavy desktop processes, and `run.sh` loads `~/.config/claude/oauth.env` when present.
- **C12 browser for web UIs:** the design leg may add the droplet's browser MCP to
  `harness/mcp.json` when the spec has a web UI.

Already fine: `notify-send` reaches the phone through `notify`; earlyoom protects `claude` and
`node`; unattended upgrades never reboot (inventory sections 1 and 12).

## Proposed changes (for John's approval, task T5)

Template (task T6), each with a self-test case: C1 to C12 above.

Droplet (task T7, prompts for Warp, each approved separately): D1 guard hold, D3 long-lived token,
D5 sign-ins.

## Expected result

On the opencode-ui run (52,815 s of leg time), C1 moves about 43,700 s of legs off Fable; Fable
keeps design, plan, audit and retries, about 17 % of leg time plus retries. With Fable use that
low, the Fable limit should seldom be reached, and C2 covers work legs when it is. C3 and C4 cut the
failed attempts behind wrong checks and noisy limits (up to 5,822 s in this run) and tell John
earlier. These are estimates from leg time, not measured tokens. C5 makes the next run measure them.
