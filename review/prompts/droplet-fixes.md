# Prompt for the Claude Code session in Warp: droplet fixes (task T7)

John: paste everything below the line into Claude Code in Warp. It asks your yes before each change.

---

Task T7 of the harness review in github.com/jcallahanp/new-project-template (branch
`claude/awesome-darwin-di1t8o`, folder `review/`). Reach the droplet with `ssh johns-ubuntu '<command>'`
(Windows OpenSSH; on the droplet call `~/.local/bin/gh` by its full path). Do not touch
`~/projects/opencode-ui` or its tmux sessions. Before each step that changes something, say in one
line what it changes and wait for John's yes. Never print a secret value.

## Step 1 (D1): guard hook holds only the opencode-ui build

Why: the current guard blocks `bash harness/run.sh` in every project, so no new project can start a
run, and it lets `python3 harness/loop.py run` through inside opencode-ui. The new guard holds a
build only while `~/.config/holds/<project>` exists. Everything else in the guard is unchanged.

1. Fetch the new guard to the droplet (read it before you install it):
   `ssh johns-ubuntu '~/.local/bin/gh api "repos/jcallahanp/new-project-template/contents/review/prompts/droplet/guard.py?ref=claude/awesome-darwin-di1t8o" -H "Accept: application/vnd.github.raw" > ~/guard.py.new'`
2. Change (ask first): back up and install, and create the hold for opencode-ui:
   `ssh johns-ubuntu 'cp -p ~/.claude/hooks/guard.py ~/.claude/hooks/guard.py.bak-2026-11-16 && install -m 755 ~/guard.py.new ~/.claude/hooks/guard.py && mkdir -p ~/.config/holds && touch ~/.config/holds/opencode-ui && rm ~/guard.py.new'`
3. Check: feed these commands to the guard with the cwd shown and report allowed or BLOCKED for each.
   Use `printf '{"tool_name":"Bash","tool_input":{"command":"<cmd>"},"cwd":"<cwd>"}' | python3 -I ~/.claude/hooks/guard.py; echo $?`
   on the droplet (exit 2 = blocked).

   | Command | cwd | Expected |
   |---|---|---|
   | `bash harness/run.sh` | `/home/john/projects/autonomous-project-template` | allowed |
   | `bash harness/run.sh` | `/home/john/projects/opencode-ui` | BLOCKED |
   | `python3 harness/loop.py run` | `/home/john/projects/opencode-ui` | BLOCKED |
   | `python3 -I harness/loop.py status` | `/home/john/projects/opencode-ui` | allowed |
   | `bash checks/run_gates.sh` | `/home/john/projects/opencode-ui` | BLOCKED |
   | `git -C ~/projects/opencode-ui push origin build/x` | `/home/john` | BLOCKED |
   | `nmap -sV 10.0.0.1` | `/home/john` | BLOCKED |
   | `doctl compute droplet create x` | `/home/john` | BLOCKED |

   If any row differs, restore the backup (`cp -p ~/.claude/hooks/guard.py.bak-2026-11-16 ~/.claude/hooks/guard.py`) and stop.
4. Tell John: to release the opencode-ui build later, he deletes `~/.config/holds/opencode-ui`.
   The line about the hold in `~/.claude/CLAUDE.md` stays true.

## Step 2 (D3): long-lived Claude token for unattended runs

Why: `~/.config/claude/oauth.env` is missing, so unattended runs stop when the login expires.

1. John does this himself in his own SSH terminal on the droplet (it opens a browser sign-in and
   prints a token; the token must not pass through this session): `claude setup-token`. Then he
   writes the token into the file with his editor as one line `CLAUDE_CODE_OAUTH_TOKEN=<token>`, and
   runs `chmod 600 ~/.config/claude/oauth.env`.
2. Check (names and mode only): `ssh johns-ubuntu 'stat -c "%a %s" ~/.config/claude/oauth.env; grep -o "^[A-Z_]*=" ~/.config/claude/oauth.env'`
   Expected: `600` and `CLAUDE_CODE_OAUTH_TOKEN=`.

## Step 3 (D5): sign-ins for agent-created keys (only when a project needs them)

No change now. When a project's spec needs a key that an agent creates (for example Cloudflare),
John signs in once: `wrangler login` on the droplet, and the needed developer sites in the agent
Chrome profile (remote desktop). Report "step 3: nothing to do now".

## Step 4: commit the result

1. In `~/projects/new-project-template` on the droplet: `git pull --ff-only`, then append to
   `review/inventory/droplet.md` a section `## 13. T7 results (date)` with the step 1 table
   (actual results) and the step 2 check output. Read it for secrets and personal data (the
   repository is public), commit `inventory: T7 droplet fixes`, push.
2. Ask John if the new guard should also go into `linux-droplet-migration` (`setup/droplet/claude/guard.py`),
   the repo that keeps the droplet's setup. Do it only on his yes, on its current branch.
3. Report in five lines or fewer: each step's result and the commit hash.
