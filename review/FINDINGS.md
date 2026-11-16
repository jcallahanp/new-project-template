# Findings: cost, time and reliability of `autonomous-project-template`

Review of template commit `5c4290e`, its run data from `opencode-ui` (`build/opencode-ui` at
`7901f58`), and the droplet `johns-ubuntu`. Date: 2026-11-16.

Sources in this repo: `review/analysis/run-data.md` (T2, numbers from `ledger_stats.py`),
`review/analysis/harness-diff.md` (T3), `review/inventory/droplet.md` (T1). Paths without a repo
name are in `autonomous-project-template`.

## Summary

1. **Reliability is good, and the design is sound.** 45 of 53 tasks passed on the first attempt.
   No task was recorded done with a failing check. The design follows Anthropic's long-running
   harness guidance (fresh session per step, state in git, script-decided completion).
2. **The main cost is the model, not the method.** Every leg runs on Fable 5.2 (`harness/loop.py:53`).
   Work and verify legs are 83 % of leg time, and they do well-specified, script-checked work. On
   Max 20x, Fable has its own limit (inventory section 11). Moving work and verify to Opus 5.5
   cuts Fable use by about 80 % and moves that work to the larger general limit.
3. **The main time loss is waiting.** The run waits for a usage limit to reset, and it waits for
   John after 3 blind retries. The loop waits up to 8 hours for a limit (`harness/loop.py:55`)
   even when another model could do the leg. All 3 tasks that needed John had a wrong check or
   limit, not a product problem.
4. **The checks are not too hard in general. Numeric limits are.** The interview turns a rough
   number into an exact pass/fail limit with no margin (`.claude/skills/intake/SKILL.md:116`). The
   600 MB check failed at 601 MB, while the same code measured between 563 and 601 MB from run to
   run.
5. **The droplet blocks the template in three places.** The guard hook blocks `harness/run.sh` in
   every project. Template sessions cannot read the secrets vault or use `gh`. The long-lived
   Claude login token is missing.

## Q1. Is it best practice, and is it reliable?

Yes, with two gaps.

What works (evidence: `review/analysis/run-data.md`, "Where the steps went"):

- 127 legs, 52 tasks done, 3 milestones closed. No `done` without a passing check (gate
  `checks/check_progress.sh:26`).
- Fail-first checks, fresh sessions, protected paths and an independent verifier follow the
  sources in `harness/METHOD.md`. The harness self-test proves the loop's defenses without a model
  (`harness/tests/selftest.sh`).

Gaps:

- **No path to repair a wrong check.** A worker that finds a wrong check can only fail
  (`CLAUDE.md`, rule 3). The loop then tries 3 times (`harness/loop.py:60`) and stops the milestone.
  All 3 human interventions were wrong checks or limits: M2.T14 (`67ebb89`), M3.T11 (`e69debe`),
  M4.T12 (`7901f58`). Their failed attempts used 5,822 s of leg time. M2.T14 alone stopped the run
  for 4 h 21 min.
- **Timeouts lose the whole leg.** 3 legs hit their time limit with 0 turns recorded: 6,300 s, which
  is 11.9 % of leg time. The re-plans that followed took 303 s and 726 s. `opencode-ui` already
  raised the plan limit (`feb4339`, `harness/loop.py:66` there).

## Q2. Where to save large cost or time without loss of reliability

Ranked by size. Leg time is the proxy for usage, because the ledger records no tokens
(`review/analysis/run-data.md`, "Not recorded"). Each item has an ID; "Proposed changes" below
lists them for approval.

| # | Change | Saves | Reliability argument |
|---|---|---|---|
| C1 | Model per leg type: Fable for design, plan and audit; Opus 5.5 for work and verify; Fable on a task's 2nd and 3rd attempt | about 80 % of Fable use (work + verify = 83 % of leg time) | Work tasks are atomic, each with a script check, gates, a verifier and the audit behind it. Retries escalate to Fable. John already chose Opus 5.5 for the restart (`linux-droplet-migration` PLAN.md, decision of 2026-11-14 and step 6.5) |
| C2 | On a usage limit, run the leg on the fallback model instead of waiting up to 8 h (`harness/loop.py:55,268-273`) | most of the waiting time John reports | The same checks judge the result. The ledger records which model did each leg |
| C3 | "Check is wrong" path: a worker may end with `CHECK-WRONG: <reason>`; the loop blocks that task at once, notifies John, and goes on with other eligible tasks | 5,822 s of failed attempts and 4 h 21 min of stop in this run | The worker still cannot edit the check. Only John changes it. Fewer blind retries, same control |
| C4 | Numbers in the spec are `hard` or `target`, with a stated margin. Target checks record the value and pass within the margin; only hard limits fail | the 600 MB case: 3,573 s of failed legs and a 2 h 11 min task | John decides in the interview what is hard. A hard limit still fails exactly |
| C5 | Record usage per leg (model, tokens, cost estimate) in `PROGRESS.md` and the ledger | none directly; it makes every other saving measurable | Read-only. `claude -p` already returns `usage` and `modelUsage` (inventory section 9) |
| C6 | Verifier does not re-run what the loop already ran; it gets the check and gate output in its brief, and runs at effort `medium` | part of verify's 19 % of leg time | The loop's run of the check and gates stays the authority (`harness/loop.py:549-550`). The verifier still reads the diff and uses the product |
| C7 | Take the 3 fixes from `opencode-ui` `feb4339`: frozen acceptance checks in re-plans, tolerant VERDICT/GAP parsing, plan limit 2,700 s | the plan rejections and plan timeouts seen in this run | Bug fixes found in a real run (`review/analysis/harness-diff.md`) |
| C8 | Larger tasks: at most 12 per planning round (now 25, `harness/loop.py:64`), "one feature slice with its tests, about one hour" (now "well under an hour", `harness/prompts/plan.md:37`) | fewer sessions; each session pays about 20,000 tokens of fixed start-up (inventory section 9) and re-reads the repo | Medium confidence: median work leg was 380 s, so tasks have room. Measure with C5; revert if the first-attempt pass rate falls below 80 % (now 85 %) |
| C9 | Scout subagent on Sonnet 5.5 and critic on Opus 5.5 (now they inherit Fable) | small | Read-only helpers. `opencode-ui` already does this (`feb4339`) |

Not proposed:

- **Parallel tasks in separate worktrees.** This would save wall-clock time but use the same quota.
  On 4 CPUs and 8 GB shared with a desktop, timing-sensitive checks already flaked
  (`linux-droplet-migration` PLAN.md, Phase 4: "one unexplained unit-test failure on a slow run"). It also adds a layer.
- **Dropping the verifier.** It failed only 2 of 54 times, but it is the defense against gamed
  checks. C1 and C6 make it cheaper instead.

## Q3. Is it too rigid? Are the checks unrealistically hard to pass?

The checks as a whole are not too hard: 45 of 53 tasks passed on the first attempt. Two things are
rigid:

1. **Every number becomes an exact limit.** `spec.py` rejects vague words (`harness/spec.py:25`)
   and the interview asks for numbers (`.claude/skills/intake/SKILL.md:116`). Nothing asks whether a
   number is a hard limit or a guess. Nothing asks for a margin for measurement noise. In the 600 MB
   case, the same code measured 563 MB in the worker's run and 601 MB in the loop's run, and the
   machine was swapping (`review/analysis/run-data.md`, "The 600 MB case"). The limit was raised to
   1000 MB, and the product then peaked at 598 MB with no product change.
2. **Three attempts, then stop, also for problems a retry cannot fix.** A wrong check fails the same
   way 3 times (C3).

## Q4. Is it ready for the droplet with full control and a secrets manager?

Not yet. Found with the inventory (`review/inventory/droplet.md`):

| # | Problem | Evidence | Fix | Where |
|---|---|---|---|---|
| D1 | The guard hook blocks `bash harness/run.sh` in every project, so `/intake` cannot launch a run. It also blocks opencode-ui gates when a command names that path, which can fail workers after the restart | inventory section 5; `guard.py` BUILD_HOLD | Hold only `~/projects/opencode-ui`, through a hold file John deletes to release it | droplet (T7) |
| D2 | Template sessions cannot use the vault or `gh`: `Read(~/.config/**)` and `Bash(gh:*)` are denied | inventory section 9: both probe commands denied; `harness/run-settings.json:7-11` | Secrets come from the vault through the loop: `child_env()` loads the spec's secret names with `secret env` when `secret` exists, else from `.env`. Workers get `secret set` for keys they create. Remove the old-laptop paths from the deny list | template (C10) |
| D3 | No long-lived Claude token: `~/.config/claude/oauth.env` is missing, so unattended runs stop when the login expires | inventory sections 2 and 12 | John runs `claude setup-token` once. Preflight warns when `credential_expires_at` (returned by `claude -p`) is earlier than the end of the run | droplet (T7) and template (C11) |
| D4 | The template's secrets model is "John fills `.env`". On the droplet the vault is OpenBao through `secret`, not Bitwarden (the `secret` helper says so; `~/.config/bws` is empty) | inventory section 7 | C10. The spec's `secrets` entries get a field `created_by`: `john` or `agent` | template (C10) |
| D5 | `wrangler` is not signed in, and the agent browser is signed in to no site. Agents cannot create keys yet | inventory sections 8 and 11 | John signs in once (Phase 8 of the migration). Until then, specs that need an agent-created key fail at preflight with a clear message | droplet (T7) |
| D6 | `harness/mcp.json` is empty, so run sessions have no browser. The droplet has `agent-browser` | inventory section 6 | The design leg may add the browser MCP to `harness/mcp.json` when the spec has a web UI | template (C12) |
| D7 | Memory and timing checks are noisy on a shared 8 GB machine with a desktop and Chrome (about 1.3 GB of Chrome processes in the inventory) | inventory section 1; the 600 MB case | C4 margins. Preflight warns when Chrome or the remote desktop uses more than 1 GB | template (C4, C11) |

Already fine: `notify-send` reaches the phone through `notify`; earlyoom protects `claude` and
`node`; unattended upgrades never reboot (inventory sections 1 and 12).

## Proposed changes (for John's approval, task T5)

Template (task T6), each with a self-test case:

- C1 model per leg type, with escalation on retries (`HARNESS_MODEL_<KIND>` overrides).
- C2 fallback model on a usage limit.
- C3 `CHECK-WRONG` path.
- C4 hard or target numbers with margins (intake, `spec.py`, plan prompt).
- C5 usage per leg in `PROGRESS.md` and the ledger.
- C6 verifier brief without re-runs, effort `medium`.
- C7 the three `feb4339` fixes.
- C8 larger tasks (12 per round).
- C9 subagent models.
- C10 secrets from the vault (`secret env`), agent-created keys, generic deny list.
- C11 preflight for the droplet: token expiry, vault reachable, heavy desktop processes.
- C12 browser MCP allowed for web UIs.

Droplet (task T7, prompts for Warp, each approved separately): D1 guard hold, D3 long-lived token,
D5 sign-ins.

## Expected result

On the opencode-ui run (measured at 52,815 s of leg time), C1 alone would move about 43,700 s of
legs off Fable. Fable would keep design, plan and audit, about 17 % of leg time. C2 and C3 remove
most of the waiting: the hours for limit resets that John reported, and the 4 h 21 min and
35 min stops in the data. These are estimates from leg time, not measured tokens. C5 makes the next
run measure them.
