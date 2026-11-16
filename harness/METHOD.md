# Method and sources

What this harness borrows, and from where. Collected 2026-11-13.

## Long-running builds

- **Anthropic, "Effective harnesses for long-running agents" (Nov 2025).** An initializer session sets
  up the environment; later sessions each make incremental progress on one feature and leave the
  repo clean. State is carried by files and git, not by the conversation: a feature list where every
  item starts as failing and sessions may only flip the status, a progress file, an `init.sh`.
  End-to-end testing as a user (browser automation) caught what unit tests missed.
  https://www.anthropic.com/research/effective-harnesses-for-long-running-agents
  *Taken:* design session, one task per session, `init.sh`, state in git, checks that start failing,
  end-to-end acceptance checks.
- **Anthropic, "Harness design for long-running apps" (Mar 2026).** Names "context anxiety" (wrapping
  up early near a perceived context limit) and explains why a context reset with a structured handoff
  beats in-place compaction for it; separates a generator from an evaluator that judges against an
  agreed contract; agents communicate through files. It also reports that newer models needed resets
  less. https://www.anthropic.com/research/harness-design-long-running-apps
  *Taken:* fresh context per step, separate verifier and auditor, file-based handoff. This harness
  keeps the resets even for newer models because the requirement here is that nothing depends on a
  session's memory; the cost is more sessions.
- **The Ralph loop and its write-ups (2026).** A loop re-runs the agent until machine-verifiable
  completion criteria pass; iteration caps are the safety net; criteria that pass trivially produce
  worthless output; "tests pass" is not "done", so work is also compared with acceptance criteria;
  failed approaches leave debris unless cleanup is part of the criteria.
  https://blakecrosley.com/blog/ralph-agent-architecture ·
  https://dev.to/premjethwa/building-an-orchestrator-for-claude-code-recoverable-before-autonomous-3f83 ·
  https://calebcoffie.com/blog/my-ralph-loop-experiments-and-why-goal-feels-like-the-successor
  *Taken:* script-decided completion, attempt and leg caps, checks that must fail first, an
  independent comparison with acceptance criteria, the whole-product audit and regression re-run
  (stories that pass alone but break each other were the most reported failure).

## Requirements

- **Spec-driven development: GitHub Spec Kit, Kiro, BMAD (compared 2026).** Specify, clarify, plan,
  tasks, analyse for consistency, implement, converge. Kiro writes requirements in EARS with approval
  between phases. The shared caution: a spec is not right because every heading is filled in.
  https://cloudnala.co.za/insights/flavours-of-spec-driven-development ·
  https://kiro.dev/docs/specs/feature-specs/requirements-first/
  *Taken:* the phase order, EARS sentences, approval before build, the consistency audit, the
  converge step (audit gaps become new work).
- **Interview before spec.** Ask why before how, separate goals from proposed implementations, reflect
  understanding back, ask for examples of good and bad outcomes, name unknowns, refuse to start until
  the goal can be restated; and stop when the interview no longer converges.
  https://github.com/ramparte/agent-building-playbook/blob/534aa66d/patterns/interview-to-a-spec.md
  *Taken:* the interview rules in `.claude/skills/intake/SKILL.md`.
- **Older practice the above rests on:** EARS (Mavin et al., 2009), user stories, specification by
  example (given / when / then), MoSCoW priorities, the pre-mortem.

## From John's earlier setups

- `abliterated-research` and `paperclip-cockpit`: the loop script, ledger, gates, pre-push hook, CI
  gate, protected harness paths, plan validation, scout and critic subagents. Reused and extended.
- `Autonomous-Agent4`: the command guard hook and the "no work without a task line" rule.
- `framework` (`skills/interview`): one question per message, playback, EARS, the missing /
  inconsistent / redundant audit.

## Changes from the 2026-11 review

The review of the `opencode-ui` run and the droplet is in `review/FINDINGS.md`. Changes C1 to C12:

- **C1** Model per step: Fable for design, plan, judge and audit, Opus 5.5 for work and verify, Fable for retries. Work and verify were most of the leg time and each is script-checked.
- **C2** On a usage limit, a work or verify leg runs on the other model instead of waiting; the run lost time to limit waits.
- **C3** `CHECK-WRONG` path with a read-only judge: a wrong check failed the same way three times and needed John anyway.
- **C4** Numbers in the spec are `hard` or `target` with a margin: an exact limit failed on measurement noise.
- **C5** Model, effort, tokens and cost per leg in `PROGRESS.md`, the ledger and `status`: the run data had none, so C1, C2 and C8 could not be measured.
- **C6** The verifier gets the loop's check and gate output and does not run them again, which saves time.
- **C7** Three fixes from `opencode-ui` `feb4339` (frozen acceptance checks in re-plans, tolerant VERDICT/GAP parsing, longer plan limit): bugs a real run found.
- **C8** At most 12 tasks per planning round and larger tasks: each session pays a fixed start-up cost.
- **C9** Scout subagent on Sonnet and critic on Opus instead of inheriting Fable: they are read-only helpers.
- **C10** Secrets from the project's own vault when it has a token file, read and write, scoped to that project; `.env` otherwise: agents must create and store keys, and the droplet uses a vault.
- **C11** Droplet preflight and the long-lived token file `~/.config/claude/oauth.env`: an expiring sign-in stopped unattended runs, and desktop browsers made checks noisy.
- **C12** A browser MCP for web UIs through `spec/mcp.json`: run sessions had no browser.
