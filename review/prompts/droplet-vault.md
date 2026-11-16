# Prompt for the Claude Code session in Warp: a vault project per template project (task T7, step 5)

John: paste everything below the line into Claude Code in Warp. It asks your yes before each change.

---

Task T7 step 5 of the harness review in github.com/jcallahanp/new-project-template (branch
`claude/awesome-darwin-di1t8o`). Reach the droplet with `ssh johns-ubuntu '<command>'` (on the
droplet call `~/.local/bin/gh` by its full path). Never print a token or secret value. Before each
step that changes something, say in one line what it changes and wait for John's yes.

Why: the improved template (`harness/loop.py`, `child_env`) uses the vault when the `secret` helper
is on PATH and `~/.config/openbao/<project>.token` exists, where `<project>` is the spec's
`project` slug. Run sessions get that token as `BAO_TOKEN` and `SECRET_PROJECT=<project>`, and run
`secret --project <project> get|set|ls|env`. The token must read and write that project's keys and
nothing else (John, 2026-11-16: agents create keys in web dashboards, store them, and wire them
into the app).

1. Read only: how the vault is set up. `~/.local/bin/secret` (how `--project` maps to a KV mount or
   path), `bao status` (or the OpenBao CLI name it uses), the OpenBao config and policies that exist
   (`bao policy list`, `bao secrets list`, with a token John supplies through the environment, never
   in the chat), and where the existing `claude` and `silk` tokens live (paths and modes only).
   Report the layout in ten lines or fewer.
2. Propose a small script `~/.local/bin/vault-project <name>` that, with John's admin token from the
   environment: creates the KV mount or path for `<name>` the same way the helper expects, a policy
   that allows read, list, create, update and delete only there, a token with that policy (no
   expiry, or a long TTL that John chooses), and writes it to `~/.config/openbao/<name>.token`
   (mode 600, never printed). Show the script and wait for John's yes.
3. Change (on yes): install the script, run it for a test project `vault-selftest`, then check:
   `secret --project vault-selftest set PING -` with a random value from stdin, `get` returns the same
   value (compare in the shell, print only "match" or "differ"), `ls` shows `PING`; and with the
   `vault-selftest` token, reading a key of the `claude` project fails. Then delete the test key.
4. Commit the result: in `~/projects/new-project-template` on the droplet, `git pull --ff-only`, append
   `## 14. T7 vault results (date)` to `review/inventory/droplet.md` (layout summary from step 1,
   the script's path, the check results; no tokens, no values), read it for personal data (the repo
   is public), commit `inventory: T7 vault project`, push. Ask John whether a copy of the script
   should also go into `linux-droplet-migration` (`setup/droplet/bin/`); only on his yes.
5. Report in five lines or fewer.

For each new project later: John runs `vault-project <project-slug>` once before `bash harness/run.sh`.
