# Prompt for the Claude Code session in Warp (Windows laptop)

John: paste everything below the line into Claude Code in Warp.

---

Task T1 of the harness review in github.com/jcallahanp/new-project-template (branch
`claude/awesome-darwin-di1t8o`, folder `review/`). This task is read-only on the droplet. It does
three things that change something, each listed here: it saves two files in the droplet home folder,
it makes one Claude Code call on Haiku 5.5 (a few cents of usage), and it pushes one commit.
Do not touch `~/projects/opencode-ui` or its tmux sessions.

1. Run `whoami; hostname`. You are on Windows. Reach the droplet with `ssh johns-ubuntu '<command>'`.
2. Fetch the script onto the droplet:
   `ssh johns-ubuntu 'gh api "repos/jcallahanp/new-project-template/contents/review/prompts/droplet-inventory.sh?ref=claude/awesome-darwin-di1t8o" -H "Accept: application/vnd.github.raw" > ~/droplet-inventory.sh'`
   Read the script before you run it. If it does anything other than read, stop and tell John.
3. Run it: `ssh johns-ubuntu 'bash ~/droplet-inventory.sh > ~/inventory.md 2>&1'`.
4. Read `~/inventory.md` on the droplet. If it shows a secret value, an email, an IP address or a
   token, stop and tell John. Do not commit it.
5. Append two sections to `~/inventory.md`:
   - `## 11. Answers`. Ask John these and write his answers:
     a. Max plan tier (Max 5x or Max 20x)? Is Fable a separate limit in `/usage`? What did `/usage`
        show at the worst point of the opencode-ui build?
     b. Which developer sites is the agent Chrome profile signed into?
     c. Is the opencode-ui build still on hold? Which model and effort will it use when it restarts?
   - `## 12. Leeway`. In 15 lines or fewer, from the files on the droplet (read-only): what an
     unattended Claude Code session on the droplet can do without John, and each thing that stops or
     limits it (permission mode, guard hook, deny rules, earlyoom, usage limits, missing logins or
     tokens). Give the file for each.
6. Commit the result from the droplet:
   - If `~/projects/new-project-template` does not exist:
     `git clone -b claude/awesome-darwin-di1t8o https://github.com/jcallahanp/new-project-template ~/projects/new-project-template`.
     Else: `git -C ~/projects/new-project-template pull --ff-only`.
   - Copy `~/inventory.md` to `review/inventory/droplet.md` in that clone.
   - This repository is public. Read the file one more time for personal data. Then commit with the
     message `inventory: droplet (T1)` and push to `claude/awesome-darwin-di1t8o`.
7. Report the commit hash and any step that failed, in five lines or fewer.
