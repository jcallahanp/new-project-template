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
