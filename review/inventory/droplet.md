# Droplet inventory

Generated 2026-11-16T13:29:39Z by review/prompts/droplet-inventory.sh (read-only).

## 1. Machine

```text
$ whoami; hostname; uname -r; . /etc/os-release; echo "$PRETTY_NAME"
john
johns-ubuntu
7.<token>
Ubuntu 26.04.1 LTS
[exit 0]
$ nproc; free -m; swapon --show; df -h --output=size,used,avail,target / ~ | uniq
4
               total        used        free      shared  buff/cache   available
Mem:            7935        2286         926         157        5185        5649
Swap:           4095          22        4073
NAME      TYPE SIZE  USED PRIO
/swapfile file   4G 22.6M   -1
 Size  Used Avail Mounted on
 155G   34G  121G /
[exit 0]
$ uptime
 13:29:40 up 1 day, 17:54,  5 users,  load average: 0.10, 0.14, 0.16
[exit 0]
$ systemctl is-active earlyoom; cat /etc/default/earlyoom 2>/dev/null | grep -v "^#" | grep .
active
EARLYOOM_ARGS="-m 5 -s 10 -r 3600 --prefer (^|/)(chrome|chromium|chrome_crashpad_handler|code|Xvfb|playwright.*)$ --avoid (^|/)(claude|opencode|node|tmux|sshd|systemd|Xorg|xfwm4|xfce4-session|chrome-remote-desktop-host|tailscaled)$ -N /usr/local/bin/earlyoom-notify"
[exit 0]
$ ps -eo rss,comm --sort=-rss | head -12
  RSS COMMAND
341968 chrome
334344 opencode
289752 2.1.325
257220 chrome
236584 2.1.325
200244 chrome
188156 chrome
175328 chrome
159972 chrome
152500 Xorg
152068 claude
[exit 0]
$ tmux ls 2>/dev/null | cut -d: -f1
main
rc
[exit 0]
$ grep -h "Automatic-Reboot" /etc/apt/apt.conf.d/* 2>/dev/null
//Unattended-Upgrade::Automatic-Reboot "false";
// when Unattended-Upgrade::Automatic-Reboot is set to true
//Unattended-Upgrade::Automatic-Reboot-WithUsers "true";
//Unattended-Upgrade::Automatic-Reboot-Time "02:00";
Unattended-Upgrade::Automatic-Reboot "false";
[exit 0]
```

## 2. Claude Code install and sign-in (names only, no values)

```text
$ claude --version; command -v claude; readlink -f "$(command -v claude)"
2.1.325 (Claude Code)
/home/john/.local/bin/claude
/home/john/.local/share/claude/versions/2.1.325
[exit 0]
$ env | cut -d= -f1 | grep -E "^(ANTHROPIC|CLAUDE|BWS|HARNESS|CLOUDFLARE|CF_|GH_|GITHUB|OPENAI|DISABLE_|MAX_THINKING)" | sort
[exit 0]
$ for f in ~/.config/claude/oauth.env ~/.claude/.credentials.json; do [ -e "$f" ] && stat -c "%a %s bytes %y %n" "$f" || echo "missing: $f"; done
missing: /home/john/.config/claude/oauth.env
600 2945 bytes 2026-11-16 12:49:22.823085926 +0000 /home/john/.claude/.credentials.json
[exit 0]
$ grep -o "^[A-Z_]*=" ~/.config/claude/oauth.env 2>/dev/null
[exit 2]
$ ls -la /etc/claude-code/ 2>/dev/null || echo "no managed settings dir"
no managed settings dir
[exit 0]
```

## 3. Claude Code user settings (~/.claude/settings.json, secret-looking values masked)

```text
{
 "permissions": {
  "defaultMode": "bypassPermissions"
 },
 "theme": "dark",
 "model": "opus",
 "switchModelsOnFlag": true,
 "autoMode": {
  "soft_deny": [
   "$defaults",
   "Bash(*harness/run.sh*) and anything that starts, stops, pushes or runs gates in ~/projects/opencode-ui while the build is on hold (see ~/.claude/CLAUDE.md)"
  ],
  "environment": [
   "**Host**: personal DigitalOcean droplet johns-ubuntu (Ubuntu 26.04, 8 GB RAM), single user john with passwordless sudo; headless; reachable only over Tailscale (<ip>), no public inbound ports",
   "**Primary use of Claude Code**: personal development and unattended coding agents (OpenCode, Claude Code, DeepSeek and Silk-hosted models) for John",
   "**Source control**: GitHub user jcallahanp (private repos); John merges every pull request himself",
   "**Network posture**: services bind to the Tailscale address or <ip> only; never to <ip> or the public IP <ip>",
   "**Key internal services**: OpenCode web at http://<ip>:4096 (basic auth), ntfy alerts via the `notify` command",
   "**Sensitive data locations**: ~/.claude/.credentials.json, ~/.config/opencode/server.env, ~/.config/abliterated/api-key, ~/.config/deepseek/api-key, ~/.config/ntfy/topic, gh login in ~/.config/gh \u2014 never print, commit or send these",
   "**Cloud provider**: DigitalOcean (droplet, firewall, snapshots cost money: ask John first)"
  ]
 },
 "autoUpdatesChannel": "stable",
 "skipDangerousModePermissionPrompt": true,
 "hooks": {
  "PreToolUse": [
   {
    "matcher": "*",
    "hooks": [
     {
      "type": "command",
      "command": "python3 -I /home/john/.claude/hooks/guard.py",
      "timeout": 10
     }
    ]
   }
  ],
  "Stop": [
   {
    "hooks": [
     {
      "type": "command",
      "command": "/home/john/.claude/hooks/notify-hook.sh"
     }
    ]
   }
  ],
  "Notification": [
   {
    "hooks": [
     {
      "type": "command",
      "command": "/home/john/.claude/hooks/notify-hook.sh"
     }
    ]
   }
  ]
 }
}
```

## 4. Hooks, agents, skills, user CLAUDE.md

```text
$ ls -la ~/.claude/hooks ~/.claude/agents ~/.claude/skills ~/.claude/commands 2>&1
ls: cannot access '/home/john/.claude/agents': No such file or directory
ls: cannot access '/home/john/.claude/commands': No such file or directory
/home/john/.claude/hooks:
total 20
drwxrwxr-x  2 john john 4096 Nov 15 23:59 .
drwxrwxr-x 14 john john 4096 Nov 16 12:49 ..
-rwxr-xr-x  1 john john 5159 Nov 15 23:59 guard.py
-rwxr-xr-x  1 john john  747 Nov 15 23:59 notify-hook.sh

/home/john/.claude/skills:
total 12
drwxrwxr-x  3 john john 4096 Nov 14 21:12 .
drwxrwxr-x 14 john john 4096 Nov 16 12:49 ..
drwxrwxr-x  3 john john 4096 Nov 14 21:12 synced
[exit 2]
$ sha256sum ~/.claude/hooks/*.py ~/.claude/hooks/*.sh 2>/dev/null | cut -c1-16,65-
c93464abe0c42273  /home/john/.claude/hooks/guard.py
109b1e88ad3c2896  /home/john/.claude/hooks/notify-hook.sh
[exit 0]
$ cat ~/.claude/CLAUDE.md
# Machine: John's Ubuntu droplet (`johns-ubuntu`)

DigitalOcean droplet, Ubuntu 26.04 LTS, 4 vCPU, 8 GB RAM + 4 GB swap, 160 GB disk, nyc1, $48/month.
User `john` (passwordless sudo, in the `docker` group). This replaced John's laptop as his Linux
machine (migration notes: github.com/jcallahanp/linux-droplet-migration, `PLAN.md` / `PROGRESS.md`).
John works from a Windows laptop: SSH, VS Code Remote-SSH, OpenCode Desktop/web, the Claude app, and
a remote desktop on this machine.

## Desktop (since 2026-11-15)

- XFCE red-team desktop through Chrome Remote Desktop (`chrome-remote-desktop@john`, display `:20`;
  no login screen, boots to `multi-user.target`). Top bar with app menu (Super), Plank dock at the
  bottom, Pentest folder in the menu. Setup script: `~/.local/share/john-setup/desktop-polish.sh`
  (copy in the migration repo, `setup/droplet/`).
- Dock: Files, Chrome, Terminal, Claude Code, Claude (claude.ai), DeepSeek/GLM/Kimi (`ds`/`glm`/`kimi`),
  OpenCode web, VS Code (`code`), GitHub, Text Editor.
- Do not change the desktop's look, dock or launchers unless John asks; do not close John's windows.
- A browser or VS Code left open in the desktop costs 300-500 MB RAM each.

## Access and network

- Reachable only over Tailscale: `<ip>` (host `johns-ubuntu`). The DigitalOcean cloud
  firewall `johns-ubuntu-ssh-only` has NO inbound rules. Never open public ports, never bind a
  service to the public IP (<ip>) or <ip> without John's yes.
- John logs in with `ssh -t -i ~/.ssh/id_ed25519_droplet john@<ip> tmux new -A -s main`.
- OpenCode web: user service `opencode-web.service`, http://<ip>:4096, HTTP basic auth
  user `opencode`, password in `~/.config/opencode/server.env` (600).
- Alerts to John's phone: `notify "message"` (ntfy.sh; topic in `~/.config/ntfy/topic`).
  `notify-send` in `~/.local/bin` is a shim that calls `notify`.

## Tools

- `~/.local/bin`: `claude` (Claude Code, Max login), `opencode` 1.19.5, `gh` 2.102.0 (signed in),
  `ds`, `glm`, `kimi` (OpenCode TUI on the Silk models; `X [folder]`, `X run "msg"`), `notify`.
- Node 22 (apt, `/usr/bin/node`) and Node 24.22.0 (`~/.local/opt/node-v24.22.0-linux-x64`), pnpm,
  JDK 21 (`~/.local/opt/jdk21`), Rust, Python 3, Docker + compose, tmux (`~/.tmux.conf`: mouse on,
  `Ctrl+b |` / `-` splits).
- OpenCode: provider `silk` (Silk Compute) with glm-5.3-uncensored, deepseek-v4.1-flash-1017-uncensored,
  kimi-k3.1-pro-uncensored; key read from `~/.config/abliterated/api-key` (`{file:}` reference).
  Permissions: `"permission": "allow"` (John 2026-11-15: full control here, no prompts). Everything an
  OpenCode agent reads goes to Silk, a small provider: public, non-sensitive work only; keep secrets
  out of its reach.
- The Claude Code harness on Silk models (`claude-abliterated`, `abliterated`, `claude-deepseek`) was
  removed 2026-11-15 (archive: `~/archive/2026-11-15-claude-silk-harness.tgz`). Use `ds`/`glm`/`kimi`.
  `abliterated-research/scripts/loop.py` still points at the removed wrapper and does not run.
- Pentest tools (apt): nmap, masscan, whatweb, sqlmap, ffuf, gobuster, dirb, wfuzz, nikto, hydra,
  john, hashcat, sslscan, testssl.sh, tcpdump, netcat, whois, dig. Agents run them only against
  targets John names for the task.
- Not on this machine: Paperclip (John's decision 2026-11-14), the laptop desktop helpers
  (deskbrid, OpenWhispr, ydotool, screenshot tools, glasses scripts).

## Projects (`~/projects`)

abliterated-research, abliterated-workspace (+ worktrees in `abliterated-workspace-agents/`),
autonomous-project-template, framework, paperclip-cockpit, opencode-ui. Also `~/Documents/Default Project`.

- **opencode-ui build is ON HOLD.** Do not start, stop, push or run the gates of
  `~/projects/opencode-ui` (`harness/run.sh`) until John says go. Never run its loop here and on
  another machine at once.

## How agents work here

- Agents here may act without prompts (John's choice for autonomy and testing); the rules below are
  still the policy and nothing technical enforces them.
- Do only the task John gave. John merges every pull request himself: open the PR and stop.
- Never interrupt, restart or read John's running sessions (OpenCode web/Desktop sessions, tmux `rc`
  and `main`, his terminals). Restarting `opencode-web.service` interrupts them: ask first.
- **Ask John first** before: purchases or payments; sending emails or messages on his behalf;
  deleting or merging data in live systems; public releases; deleting files outside the current
  project; creating or changing accounts, repositories, droplets, firewalls or DNS.
- Before a risky system change, ask John for a DigitalOcean snapshot (they cost money) and record its name.
- Secrets: never in a commit, log, ticket or chat; never print key files. Keys move between machines
  over SSH only.
- Budget: the droplet stays at or under $48 a month unless John raises it.
- RAM is 8 GB shared by everything: close browsers (headless Chrome) when done; watch `free -h`.
[exit 0]
```

## 5. Guard hook behaviour (fed directly, no model call)

```text
bash harness/run.sh                                          -> BLOCKED (exit 2): BLOCKED by John's guard (~/.claude/hooks/guard.py): the opencode-ui build is on hold until John says go. This needs John
bash harness/run.sh --foreground                             -> BLOCKED (exit 2): BLOCKED by John's guard (~/.claude/hooks/guard.py): the opencode-ui build is on hold until John says go. This needs John
python3 harness/loop.py run                                  -> allowed
python3 -I harness/loop.py status                            -> allowed
bash checks/run_gates.sh                                     -> allowed
cd ~/projects/opencode-ui && bash checks/run_gates.sh        -> BLOCKED (exit 2): BLOCKED by John's guard (~/.claude/hooks/guard.py): the opencode-ui build is on hold until John says go. This needs John
gh pr create --fill                                          -> allowed
git push -u origin build/x                                   -> allowed
sudo apt-get install -y jq                                   -> allowed
nmap -sV <ip>                                           -> BLOCKED (exit 2): BLOCKED by John's guard (~/.claude/hooks/guard.py): pentest tools and HexStrike are never run automatically. This needs 
secret set FOO_API_KEY -                                     -> allowed
wrangler deploy                                              -> allowed
doctl compute droplet create x                               -> BLOCKED (exit 2): BLOCKED by John's guard (~/.claude/hooks/guard.py): payments and paid resources are never automatic. This needs John: st
rm -rf node_modules                                          -> allowed
```

## 6. MCP servers and the agent browser

```text
$ claude mcp list
Checking MCP server health…

claude.ai Claude Docs: https://api.anthropic.com/v1/pages/mcp - ✔ Connected
claude.ai DigitalOcean: https://mcp.digitalocean.com/mcp - ✔ Connected
claude.ai Linear: https://mcp.linear.app/mcp - ✔ Connected
claude.ai Apollo.io: https://mcp.apollo.io/mcp - ✔ Connected
claude.ai cloudflare: https://mcp.cloudflare.com/mcp - ✔ Connected
claude.ai Cloudflare Developer Platform: https://bindings.mcp.cloudflare.com/mcp - ✔ Connected
claude.ai AnythingMCP: https://cloud.anythingmcp.com/mcp - ✔ Connected
(9 personal claude.ai connectors (health, finance, shopping) omitted for the public repo)
claude.ai Highspot: https://mcp.highspot.com/mcp - ! Needs authentication
claude.ai Plaid Developer Tools: https://api.dashboard.plaid.com/mcp/sse - ! Needs authentication
claude.ai Mermaid Chart: https://chatgpt.mermaid.ai/anthropic/mcp - ✔ Connected
claude.ai Context7: https://mcp.context7.com/mcp - ✔ Connected
claude.ai Exa: https://mcp.exa.ai/mcp - ✔ Connected
claude.ai n8n: https://<workspace>.app.n8n.cloud/mcp-server/http - ✘ Failed to connect — HTTP 404: Error POSTing to endpoint: {"type":"error","error":{"type":"not_found_error","message":"No MCP endpoint was found at the URL provided.","details":{"error_code":"mcp_endpoint_not_found"}},"request_id":"<request-id>"}
claude.ai Attio: https://mcp.attio.com/mcp - ✔ Connected
claude.ai Google Calendar: https://calendarmcp.googleapis.com/mcp/v1 - ✔ Connected
claude.ai Google Sheets: https://sheetsmcp.googleapis.com/mcp/v1 - ✔ Connected
claude.ai Gmail: https://gmailmcp.googleapis.com/mcp/v1 - ✔ Connected
claude.ai Parallel Search: https://search.parallel.ai/mcp - ✔ Connected
claude.ai 6sense: https://api.6sense.com/mcp - ! Needs authentication
claude.ai Notion: https://mcp.notion.com/mcp - ✔ Connected
claude.ai Superhuman Mail: https://mcp.mail.superhuman.com/mcp - ! Needs authentication
claude.ai Mailbox MCP: https://mcp.mailbox-mcp.com/db/mcp - ! Needs authentication
claude.ai ZoomInfo: https://mcp.zoominfo.com/mcp - ! Needs authentication
claude.ai Outreach: https://api.outreach.io/mcp - ! Needs authentication
claude.ai Zoom for Claude: https://mcp.zoom.us/mcp/zoom/streamable - ✔ Connected
claude.ai Microsoft 365: https://microsoft365.mcp.claude.com/mcp - ! Needs authentication
claude.ai Clay: https://api.clay.com/v3/mcp - ✔ Connected
claude.ai Google Drive: https://drivemcp.googleapis.com/mcp/v1 - ✔ Connected
plugin:data:snowflake:  (HTTP) - - Not configured
plugin:data:databricks:  (HTTP) - - Not configured
plugin:data:hex: https://app.hex.tech/mcp (HTTP) - ! Needs authentication
plugin:data:amplitude: https://mcp.amplitude.com/mcp (HTTP) - ! Needs authentication
plugin:data:amplitude-eu: https://mcp.eu.amplitude.com/mcp (HTTP) - ! Needs authentication
plugin:data:atlassian: https://mcp.atlassian.com/v1/mcp (HTTP) - ! Needs authentication
plugin:data:definite: https://api.definite.app/v3/mcp/http (HTTP) - ✘ Failed to connect — MCP endpoint not found at https://api.definite.app. Check the URL in your MCP config.
plugin:cloudflare:cloudflare: https://mcp.cloudflare.com/mcp (HTTP) - ! Needs authentication
agent-browser: /home/john/.local/bin/agent-browser-mcp  - ✔ Connected
[exit 0]
$ command -v agent-chrome agent-browser-mcp crun notify notify-send secret bws wrangler
/home/john/.local/bin/agent-chrome
/home/john/.local/bin/agent-browser-mcp
/home/john/.local/bin/crun
/home/john/.local/bin/notify
/home/john/.local/bin/notify-send
/home/john/.local/bin/secret
/home/john/.local/bin/bws
/home/john/.local/bin/wrangler
[exit 0]
$ ss -ltn | grep -E ":(9222|4096|4310)\b" | sed -E "s/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/<ip>/g"
LISTEN 0      512                            <ip>:4096       <ip>:*   
LISTEN 0      10                                  <ip>:9222       <ip>:*   
[exit 0]
$ ls ~/.config/agent-chrome 2>/dev/null | head -5
ActorSafetyLists
AmountExtractionHeuristicRegexes
CaptchaProviders
CertificateRevocation
Crowd Deny
[exit 0]
```

## 7. Secrets manager (Bitwarden Secrets Manager; counts and modes only)

```text
$ bws --version
bws 2.1.0
[exit 0]
$ ls -la ~/.config/bws 2>&1 | sed -E "s/ [A-Z][a-z]{2} +[0-9]+ +[0-9:]+ / /"
total 8
drwx------  2 john john 4096 .
drwxrwxr-x 26 john john 4096 ..
[exit 0]
$ for t in ~/.config/bws/*.token; do [ -e "$t" ] || continue; p=$(basename "$t" .token); n=$(secret --project "$p" ls 2>/dev/null | wc -l); echo "project $p: $n keys (rc of ls: $(secret --project "$p" ls >/dev/null 2>&1; echo $?))"; done
[exit 0]
$ secret 2>&1 | head -12
secret: read/write agent secrets in the droplet's OpenBao vault (Phase 8.5, 2026-11-16).
Project = KV mount + token. Default `claude`; `--project silk` (or SECRET_PROJECT=silk) switches.
Token: BAO_TOKEN env, else ~/.config/openbao/<project>.token (600). Vault: http://<ip>:8200.
  secret get <KEY>              print a secret's value (for $(...) / env), nothing else
  secret set <KEY> <VALUE>      create or update a secret
  secret set <KEY> -            read the value from stdin (keeps it off the command line)
  secret ls                     list key names (never values)
  secret env <KEY> [<KEY>...]   print `export KEY=value` lines for `eval "$(secret env ...)"`
Values are never logged. Claude agents use the default (claude) token; Silk agents get the silk token.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
[exit 0]
```

## 8. Developer tools and accounts (no emails or ids)

```text
$ git --version; git config --global user.name >/dev/null && echo "git user.name: set" || echo "git user.name: NOT set"; git config --global user.email >/dev/null && echo "git user.email: set" || echo "git user.email: NOT set"
git version 2.53.0
git user.name: set
git user.email: set
[exit 0]
$ gh --version | head -1; gh auth status 2>&1 | grep -Ei "logged in|scopes|protocol|token:" | sed -E "s/account [^ ]+/account <user>/"
gh version 2.102.0 (2026-09-30)
  ✓ Logged in to github.com account <user> (/home/john/.config/gh/hosts.yml)
  - Git operations protocol: https
  - Token: gho_************************************
  - Token scopes: 'gist', 'read:org', 'repo', 'workflow'
[exit 0]
$ node --version; npm --version; pnpm --version; python3 --version; docker --version; docker compose version; tmux -V; jq --version
v22.22.1
9.2.0
bash: line 1: pnpm: command not found
Python 3.14.4
Docker version 29.1.3, build 29.1.3-0ubuntu4.1
Docker Compose version 2.40.3+ds1-0ubuntu1
tmux 3.6
jq-1.8.1
[exit 0]
$ ls ~/.cache/ms-playwright 2>/dev/null; npx --no-install playwright --version 2>/dev/null; google-chrome --version 2>/dev/null; chromium --version 2>/dev/null
b
Google Chrome 157.0.8103.78 
[exit 127]
$ wrangler --version 2>/dev/null; wrangler whoami 2>&1 | grep -Ei "logged|not authenticated|token" | head -3
4.162.0
You are not authenticated. Please run `wrangler login`.
[exit 0]
$ opencode --version
1.19.5
[exit 0]
```

## 9. How the template starts a run session on this machine (one Haiku call)

```text
$ git -C '/home/john/projects/autonomous-project-template' log -1 --format='%h %s'; git -C '/home/john/projects/autonomous-project-template' status --porcelain | wc -l
5c4290e loop: clearer verifier pass message
0
[exit 0]
result keys: ['api_error_status', 'credential_expires_at', 'duration_api_ms', 'duration_ms', 'fast_mode_disabled_reason', 'fast_mode_state', 'first_content_frame_ms', 'is_error', 'modelUsage', 'num_turns', 'permission_denials', 'queued_turn_count', 'result', 'result_index', 'safety_stops', 'session_id', 'stop_reason', 'subagent_stats', 'subtype', 'terminal_reason', 'time_to_request_ms', 'total_cost_usd', 'ttft_ms', 'ttft_stream_ms', 'type', 'usage', 'uuid']
is_error: False
subtype: success
num_turns: 3
duration_ms: 11272
total_cost_usd: <token>
usage: {"input_tokens": 6, "cache_creation_input_tokens": 20042, "cache_read_input_tokens": 72805, "output_tokens": 1031, "output_tokens_details": {"thinking_tokens": 561}, "server_tool_use": {"web_search_requests": 0, "web_fetch_requests": 0}, "service_tier": "standard", "cache_creation": {"ephemeral_1h_input_tokens": 20042, "ephemeral_5m_input_tokens": 0}, "inference_geo": "global", "iterations": [{"input_tokens": 2, "output_tokens": 396, "cache_read_input_tokens": 30796, "cache_creation_input_tokens": 616, "cache_creation": {"ephemeral_5m_input_tokens": 0, "ephemeral_1h_input_tokens": 616}, "type"
modelUsage: {"claude-haiku-5-5": {"inputTokens": 6, "outputTokens": 1031, "cacheReadInputTokens": 72805, "cacheCreationInputTokens": 20042, "webSearchRequests": 0, "costUSD": <token>, "contextWindow": 1000000, "maxOutputTokens": 128000, "thinkingTokens": 561, "cacheCreationEphemeral5mInputTokens": 0, "cacheCreationEphemeral1hInputTokens": 20042, "canonicalModel": "claude-haiku-5-5", "provider": "firstParty", "costBasis": "list"}}
permission_denials: [{"tool_name": "Bash", "tool_use_id": "toolu_01H8Y657bRXuJWSiPBvHUGFx", "tool_input": {"command": "gh --version; echo \"EXIT=$?\"", "description": "Print gh version and exit code"}}, {"tool_name": "Bash", "tool_use_id": "toolu_014W8iUozWP6NaRaRNs6WBYE", "tool_input": {"command": "ls -ld ~/.config; echo \"EXIT=$?\"", "description": "List ~/.config directory and print exit code"}}]
result text: Bash is being denied for these commands, so I haven't run the third one. I'm stopping here rather than trying other ways around the denials.

**Results so far:**
1. `gh --version; echo "EXIT=$?"`: denied, so no exit code.
2. `ls -ld ~/.config; echo "EXIT=$?"`: denied, so no exit code.
3. `secret ls > /dev/null`: not run.

I didn't run `secret ls` because Bash access looks blocked for this session, and listing secrets is a sensitive action to attempt through a different route. If you want these checked, allow Bash for these commands (or tell me which permission change you want) and I'll run the
```

## 10. Template copy on this machine

```text
$ git -C '/home/john/projects/autonomous-project-template' log -3 --format='%h %ci %s'; git -C '/home/john/projects/autonomous-project-template' branch --show-current; git -C '/home/john/projects/autonomous-project-template' status --porcelain | head
5c4290e 2026-11-13 19:01:53 -0500 loop: clearer verifier pass message
8ba8623 2026-11-13 18:48:59 -0500 Template: requirements interview, approved spec, unattended build loop with script-decided checks
main
[exit 0]
```

## 11. Answers

John's answers, 2026-11-16:

- a. Plan: **Max 20x**. Fable is a **separate limit** in `/usage`. `/usage` at the worst point of the
  opencode-ui build: not given.
- b. Agent Chrome profile (`~/.config/agent-chrome`): signed into **no** developer sites.
- c. opencode-ui build: **still on hold**. Model and effort for the restart: not given.

## 12. Leeway

1. Mode: `bypassPermissions` + `skipDangerousModePermissionPrompt` (`~/.claude/settings.json`): user and `crun` sessions run any tool without prompts.
2. Unattended start: `~/.local/bin/crun` (tmux `crun-<name>`, pre-accepts the trust dialog); Stop/Notification send a phone alert (`~/.claude/hooks/notify-hook.sh` -> `notify`).
3. Hard stop: `~/.claude/hooks/guard.py` (PreToolUse, all tools) blocks pentest tools/HexStrike, paid resources (doctl create/resize, stripe, domain buys), POSTs and browser visits to billing pages, paid MCP actions, and `harness/run.sh` or opencode-ui gates.
4. Guard gaps (section 5): allows `sudo`, `git push`, `gh pr create`, `secret set`, `wrangler deploy`, `rm -rf`, and `python3 harness/loop.py run` when run from inside opencode-ui (the hold regex only matches `run.sh` or a path that names opencode-ui).
5. Soft only: `~/.claude/CLAUDE.md` rules (ask before emails, deletes, merges, account/DNS changes) and `autoMode.soft_deny` (applies only in auto mode, not bypass). Nothing enforces them.
6. Root: passwordless sudo for john (`~/.claude/CLAUDE.md`); nothing blocks `sudo`.
7. Template runs (`autonomous-project-template/harness/run-settings.json`): `acceptEdits`, bypass disabled; deny `sudo`, `git push`, `gh`, `ssh`, `systemctl`, `crontab`, reads of `~/.config/**`, `~/.claude/**`, `~/.ssh/**`; `harness/guard.sh` blocks rm -r outside the project, printing `.env`, history rewrites, leaving the run branch.
8. Probe (section 9): in a template run, `gh --version` and `ls -ld ~/.config` were denied, so the run's model cannot use gh or the `secret` vault; `harness/mcp.json` is empty, so no MCP servers.
9. Claude login: OAuth in `~/.claude/.credentials.json` (expires); `~/.config/claude/oauth.env` (long-lived token for `crun`) is missing, so unattended runs stop when the login lapses.
10. Other logins: gh signed in (repo, workflow scopes, `~/.config/gh/hosts.yml`); wrangler not signed in; `~/.config/bws` has no project tokens (secrets moved to OpenBao via `~/.local/bin/secret`); agent Chrome signed into nothing (section 11).
11. Connectors: ~40 claude.ai MCP servers in user sessions (DigitalOcean, Cloudflare, Gmail, finance); `guard.py` blocks only their paid actions, so sending mail etc. is held back only by the soft rules.
12. RAM: earlyoom (`/etc/default/earlyoom`) kills at <5% RAM and <10% swap, Chrome/VS Code/Playwright first, avoids claude/opencode/node; alert via `/usr/local/bin/earlyoom-notify`.
13. Usage: Max 20x, Fable limit separate (section 11); when a limit is hit the session stops until reset, and nothing switches model automatically.
14. Reboots: `Unattended-Upgrade::Automatic-Reboot "false"` (`/etc/apt/apt.conf.d`), so no automatic restarts interrupt a run.

## 13. T7 results (2026-11-16)

### Step 1 (D1): new guard, hold file `~/.config/holds/opencode-ui`

Old guard backed up to `~/.claude/hooks/guard.py.bak-2026-11-16`. All rows match.

| Command | cwd | Expected | Actual |
|---|---|---|---|
| `bash harness/run.sh` | `/home/john/projects/autonomous-project-template` | allowed | allowed |
| `bash harness/run.sh` | `/home/john/projects/opencode-ui` | BLOCKED | BLOCKED |
| `python3 harness/loop.py run` | `/home/john/projects/opencode-ui` | BLOCKED | BLOCKED |
| `python3 -I harness/loop.py status` | `/home/john/projects/opencode-ui` | allowed | allowed |
| `bash checks/run_gates.sh` | `/home/john/projects/opencode-ui` | BLOCKED | BLOCKED |
| `git -C ~/projects/opencode-ui push origin build/x` | `/home/john` | BLOCKED | BLOCKED |
| `nmap -sV 10.0.0.1` | `/home/john` | BLOCKED | BLOCKED |
| `doctl compute droplet create x` | `/home/john` | BLOCKED | BLOCKED |

### Step 2 (D3): long-lived Claude token

```text
600 133
CLAUDE_CODE_OAUTH_TOKEN=
```

### Step 3 (D5)

Nothing to do now (wrangler and agent Chrome sign-ins wait until a project needs them).

## 14. T7 vault results (2026-11-16)

### Layout (read-only, before changes)

```text
- Server: OpenBao 2.7.2, systemd openbao.service (user openbao), listens on 127.0.0.1:8200 only, no TLS, pebbledb, ui off.
- Unseal: shamir 1 of 1; unseal key and root token in /etc/openbao/secure/init.json (root, 600).
- Auth: token only. KV v2 mounts claude/ and silk/ (plus system mounts).
- Policies: claude-agents = "claude/*" create/read/update/delete/list; silk-agents = "silk/*" the same.
- Tokens: ~/.config/openbao/claude.token, silk.token (600, dir 700): service tokens, period 30 days.
- ~/.local/bin/secret: --project <p> -> KV mount <p>/ and ~/.config/openbao/<p>.token (or BAO_TOKEN); value in field "value".
- Token auth max TTL: 32 days (system default).
```

### Found and fixed: vault was sealed

Auto-unseal (`/etc/systemd/system/openbao.service.d/10-unseal.conf`, `ExecStartPost=/usr/local/bin/openbao-unseal`)
ran as user openbao and could not read the root-only init.json (PermissionError at the last start), so
`secret` failed for every project. Pre-check: `/usr/local/bin/openbao-unseal` is root 755 (dir root 755).
Changed to `ExecStartPost=+/usr/local/bin/openbao-unseal` (runs as root); `systemctl daemon-reload`,
`systemctl restart openbao`: `Sealed false` with no manual unseal.

### New script: `~/.local/bin/vault-project <name>`

Creates KV v2 mount `<name>/`, policy `<name>-agents` (create/read/update/delete/list on `<name>/*`
only), and an orphan periodic token (period 720h) with only that policy, written to
`~/.config/openbao/<name>.token` (600). The admin token is read per command from init.json with sudo;
never printed, exported or stored. Refuses reserved names and an existing token file.

### Checks (test project `vault-selftest`)

```text
vault-project vault-selftest            exit 0; token file 600; policies default + vault-selftest-agents; period 30d; orphan
secret set PING - (random, stdin)       stored
secret get PING vs value                match
secret ls                               PING
selftest token: kv get on claude/       403 (denied)
selftest token: kv list claude/         403 (denied)
test key deleted                        ls -> (none)
```

The `vault-selftest` mount, policy and token remain (empty).

### Open

- The `claude` and `silk` tokens (period 30 days) expire 2026-12-16 unless renewed, and nothing renews
  them. New `vault-project` tokens have the same period. Follow-up: a daily `bao token renew-self` per
  token file (user timer).
- For each new project: `vault-project <project-slug>` once before `bash harness/run.sh`.
