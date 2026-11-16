---
name: intake
description: Requirements interview that starts every project in this repo, and the way to change requirements later. Use when the spec is not approved yet, when John describes something he wants built, or when he says "interview me", "new project", "change the requirements", "add a requirement". Turns a rough idea into spec/requirements.json (user stories, EARS requirements, concrete examples), gets John's approval, collects secrets, then starts the unattended build.
---

# Intake: from a rough idea to an approved spec, then launch

John's first description is an impulse, not a specification. It will mix real needs with guessed
solutions, skip the cases he has not thought about, and sometimes ask for the wrong thing. Your job
is to find out what he needs and why, write it so a script can prove each part, get his approval,
and start the build. You write no product code, no design and no plan: later sessions do that from
the spec, and they can ask nobody.

If `spec/APPROVED` already exists, go to "Change mode" at the end.

## Step 1. Keep his words

Write John's description, exactly as he gave it, to `spec/BRIEF.md` under a `# Brief` heading (if he
has not described the project yet, ask him to, in his own words, as long or short as he likes). If
the repo already contains project code, read enough of it to know what exists.

## Step 2. Interview

Rules of the conversation:

- **One question per message.** Never stack questions. Plain words, no jargon he did not use first.
- **Play back before moving on.** After each answer, say in one or two sentences what you understood
  and how you will record it. If he corrects you, fix it before the next question.
- **Ask why until you reach the need.** When he names a feature or a tool, ask what it is for (up to
  five times). "A dashboard" is a solution; "see by 9 am which orders are late" is a need. Record the
  need as the requirement and the named solution as a constraint only if he insists on it.
- **Ask for examples, not adjectives.** "Fast", "simple", "secure", "nice" cannot be built or checked.
  Ask: "Give me one real case: what goes in, what should come out?" and "What would make you say it
  is too slow?" Turn each answer into a given / when / then example with real values.
- **Ask how hard every number is.** For each number with a unit (600 MB, 2 seconds, 50 req/s), ask,
  one at a time: "Is this a hard limit or a target?", "How noisy is the measurement, and what margin is
  fine?", "What happens at 10 % over?". A rough estimate ("roughly 600") is a `target`. Only a number
  that must never be crossed (a contract, a hardware cap) is `hard`. Record the answers in `limits`.
- **Offer a default when he does not care.** If a decision does not matter to him, propose the
  ordinary choice in one line, say why, and record it under `assumptions` once he agrees. Use the
  AskUserQuestion tool when there are two to four clear options; otherwise ask openly.
- **Say when something does not add up.** If two things he wants conflict, if a request will not get
  him the outcome he described, or if something simpler would, tell him plainly and let him decide.
  Do not quietly build a bad instruction and do not quietly drop it.
- **Answer from files when you can.** If the repo or his earlier answers settle a question, state
  what you found and ask him to confirm instead of asking from scratch.
- **Never invent an answer.** If he says "skip" or does not know, record it under `open_questions`
  and come back to it in step 4. The spec cannot be approved with open questions.
- He often dictates: if a word looks like a mishearing of a tool or a name, ask once.

Cover these, in this order, skipping what he has already answered:

1. **Outcome.** Who is it for, what situation are they in, what will they be able to do afterwards
   that they cannot do now? What happens if nothing is built?
2. **Success.** How will he know, a week after it ships, that it worked? What would he look at?
3. **Walk through it.** "Take me through one real use from start to finish." Then the second most
   common use. Each step a user takes is a candidate requirement.
4. **What goes wrong.** For each step: bad input, nothing to show, the service is down, the second
   time, two people at once, the wrong person. What should happen?
5. **Must never.** What must it never do? What is out of scope even if it seems natural to add?
   (At least one item for `non_goals`.)
6. **Constraints.** Where it runs, what it must work with, tools or languages he requires or
   forbids, budget, deadline, data that must stay private, anything that cannot change.
7. **Outside services and secrets.** Every account, API or database it touches. For each: the name of
   the environment variable that will hold the key (`STRIPE_API_KEY`), what it is for, whether the
   project cannot work without it. Never ask for or accept a value in the conversation.
8. **Ready to deploy.** Where will it run, and what must be true for him to call it ready (a
   container builds and starts, a deploy command exists and is documented, a health endpoint answers)?
   What will he do himself (buy a domain, press the final deploy button, merge)? Those go in
   `human_gates`: the run never does them.
9. **Priorities.** Which requirements are `must` (not delivered without them) and which are `should`
   (built after the musts, still checked)? Anything else moves to `non_goals`.
10. **Pre-mortem.** "Imagine it is delivered and you are unhappy with it. What is the most likely
    reason?" Turn each answer into a requirement, a non-goal or a constraint.

Stop asking when a stranger could build the right thing from what you have and every requirement has
an example. Ten to twenty-five questions is normal; a small tool needs fewer. If the interview stops
converging, say what is still unknown and ask whether to record it as an assumption.

## Step 3. Write the spec

Write `spec/requirements.json` (update it as you go, so nothing depends on this conversation):

```json
{
  "project": "short-name",
  "summary": "Three or four sentences: what is being built, for whom, and why it matters to them.",
  "users": ["who uses it, in a phrase each"],
  "requirements": [
    {
      "id": "R1",
      "priority": "must",
      "story": "As a <user>, I want <capability> so that <outcome>.",
      "statement": "When <trigger>, the system shall <observable response>.",
      "examples": [
        {"given": "a concrete starting state", "when": "a concrete action with real values", "then": "the exact observable result"}
      ],
      "verify": "How a script can prove it: what it starts, what it sends or clicks, what it must observe.",
      "limits": [
        {"name": "memory", "value": 600, "unit": "MB", "kind": "target", "margin": "10%",
         "measure": "peak resident memory of both servers during a 10-minute soak, median of 3 runs"}
      ]
    }
  ],
  "non_goals": ["what it will not do"],
  "constraints": ["what the build must respect"],
  "assumptions": ["defaults John agreed to"],
  "deploy": {"target": "where it runs", "ready_when": ["observable statement", "another"]},
  "secrets": [{"name": "NAME_OF_VARIABLE", "purpose": "what it is used for", "required": true}],
  "human_gates": ["things only John does"],
  "open_questions": []
}
```

How to write a requirement:

- **One behaviour per requirement.** If the statement needs "and" between two responses, split it.
- **EARS sentence shapes** (pick the one that fits):
  "When <event>, the system shall <response>." · "While <state>, the system shall <response>." ·
  "If <unwanted condition>, then the system shall <response>." · "Where <optional feature is
  present>, the system shall <response>." · "The system shall <response>." (always true)
- **Behaviour, not design.** No libraries, file layouts or vendors unless John required them; then
  they are constraints.
- **Numbers instead of adjectives.** "within 2 seconds for 1,000 rows", not "fast".
- **Every number with a unit in a statement gets a `limits` entry** (`spec.py check` insists): its
  `value` and `unit` as written in the statement, `kind` `hard` or `target`, a `margin` (a target needs
  one, like "10%" or a number in the same unit; a hard limit has margin 0), and `measure`: what is
  measured, how often, how many runs. Ask John the three questions from step 2 for each one. A target
  passes up to value plus margin; a hard limit fails at the value. Leave `limits` out when there are none.
- **Every unhappy path he cares about is its own "If … then" requirement**, with an example.
- **Examples use real values** and include at least one edge case per requirement where one exists.
- **`verify` must be doable by a script on this machine** with the secrets listed. If a requirement
  can only be judged by a person, reword it until a script can check it, or move it to `human_gates`.

## Step 4. Audit your own spec before showing it

Run `python3 harness/spec.py check` and fix every problem it lists. Then read the spec as a stranger
and look for:

- **Missing:** a step in his walk-through with no requirement; an error case with no behaviour; a
  secret a requirement needs that is not listed; a `ready_when` nobody could check.
- **Inconsistent:** two requirements that cannot both be true; an example that contradicts its statement.
- **Redundant:** two requirements a single check would prove.
- **Untestable:** anything `verify` cannot really prove.
- **Smuggled design:** a how dressed as a what.

Ask John about what you find (still one question per message) until `open_questions` is empty.

## Step 5. Get approval

Run `python3 harness/spec.py render` and show John the result in the conversation, compactly: the
summary, each requirement as one line (`R3 (must): When …, the system shall …`), the non-goals, the
deploy readiness list, the secrets by name, and what is left to him. Ask him to correct anything.
Repeat until he says, in his own words, that it is right.

Only then run `python3 harness/spec.py approve`. It re-checks the spec, writes
`spec/REQUIREMENTS.md` and `.env.example`, records the approval and commits. Never run it on your own
judgement: approval is John's.

## Step 6. Secrets

If the spec lists secrets, tell John to put the values in `.env` himself (a copy of `.env.example`
with the values filled in), in his editor, not in this conversation. `.env` is git-ignored. Then run
`python3 harness/spec.py secrets` to confirm every required name has a value (it never prints one).
If a key has to be created first, tell him where; do not start the run with a required secret missing.

## Step 7. Launch

1. If this repo has no GitHub remote yet and John wants one, create a private repository with
   `gh repo create <name> --private --source . --remote origin --push` (ask before creating it).
2. Run `bash harness/preflight.sh` and fix or explain every FAIL line.
3. Run `bash harness/run.sh`. It starts the build loop in a tmux session that survives a closed
   terminal, on a `build/...` branch, never on `main`.
4. Tell John, briefly: how to watch (`tmux attach -t <name>`, `bash harness/run.sh status`), that the
   run stops by itself with a reason if it needs him, and that it ends with `DELIVERY.md` and a pull
   request he merges. Then stop. Do not start building in this session.

## Change mode (the spec is already approved)

1. If a run is in progress, stop it first (`tmux attach -t <name>`, then Ctrl+C): a running loop
   puts the spec back to its approved state after every step. Then ask what should change and why,
   with the same interview rules, as briefly as the change allows.
2. Edit `spec/requirements.json`: change the requirement in place (keep its id), or add a new one with
   the next free id. Never renumber. Move a dropped requirement's intent to `non_goals`.
3. Run steps 4 and 5 again for the changed parts, then `python3 harness/spec.py approve`.
4. Start the run again with `bash harness/run.sh`: it adds a milestone for the new and changed
   requirements by itself and audits the whole product again at the end.
