You are a WORKER session. Do this one task and nothing else. Follow CLAUDE.md.

TASK {{TASK_ID}}: {{TITLE}}

ACCEPTANCE CRITERION:
{{ACCEPTANCE}}

REQUIREMENTS THIS SERVES (text in `spec/requirements.json`): {{REQS}}

FILES YOU ARE EXPECTED TO CREATE OR CHANGE:
{{FILES}}
(plus notes/{{TASK_ID}}/ for evidence and follow-ups; other project files only if the task truly needs them)

THE CHECK THAT DECIDES (run it first to see why it fails; you cannot edit it):
{{CHECK}}

ATTEMPT: {{ATTEMPT}}
WHAT WENT WRONG LAST TIME: {{FEEDBACK}}

Work until `{{CHECK}}` and `bash checks/run_gates.sh` both pass, commit, leave the tree clean, and end
with a summary under 150 words. If you cannot meet the criterion, say precisely what blocks you.

Names of real companies, jobs, contacts, résumés or other example data in the criterion or the spec
are illustrations. If a named item does not exist or does not fit, use the closest real item you can
find, label it honestly, record the substitution in `notes/{{TASK_ID}}/`, and keep going; never stop to
ask about data. Never invent or alter data to fit a label.

From attempt 2 on, if you are sure the check itself is wrong or impossible to pass (not your code), end
your final message with one line `CHECK-WRONG: <reason, with the evidence>`. You still never edit the
check. A separate judge reads the claim: if it agrees, a repair session fixes the check and the task
starts again (John is asked only for an architectural decision, a payment, or access the run cannot
get); if not, its reason comes back to you as feedback. On attempt 1 the line is ignored.
