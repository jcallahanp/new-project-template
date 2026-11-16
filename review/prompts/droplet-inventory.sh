#!/usr/bin/env bash
# Read-only inventory of johns-ubuntu for the harness review (review/PLAN.md, task T1).
# Run ON THE DROPLET as user john:  bash droplet-inventory.sh > ~/inventory.md 2>&1
#
# What it changes: nothing, except one tiny Claude Code call on Haiku 5.5 (section 9) that uses a
# few cents of Max-plan usage. Set NO_PROBE=1 to skip it.
# What it never prints: secret values, emails, IP addresses, long token-like strings. A final filter
# masks those even if a command prints one. Still read the output before you commit it.
set -u
export PATH="$HOME/.local/bin:$PATH"
TPL="$HOME/projects/autonomous-project-template"

sec() { printf '\n## %s\n\n```text\n' "$1"; }
end() { printf '```\n'; }
run() { printf '$ %s\n' "$*"; bash -c "$*" 2>&1 | head -n "${LINES_MAX:-60}"; printf '[exit %s]\n' "${PIPESTATUS[0]}"; }

# Print JSON with every value under an "env" key, and every value of a key that looks secret, masked.
masked_json() {
  python3 -I - "$1" <<'PY'
import json, re, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
except Exception as e:
    print(f"(cannot read {p}: {e.__class__.__name__})"); sys.exit(0)
SECRET = re.compile(r"token|key|secret|password|passwd|auth|credential", re.I)
def walk(x, k=""):
    if isinstance(x, dict):
        return {kk: ("***" if (k == "env" or SECRET.search(kk)) and not isinstance(vv, (dict, list, bool)) else walk(vv, kk)) for kk, vv in x.items()}
    if isinstance(x, list):
        return [walk(v, k) for v in x]
    return x
print(json.dumps(walk(d), indent=1)[:6000])
PY
}

main() {
printf '# Droplet inventory\n\nGenerated %s by review/prompts/droplet-inventory.sh (read-only).\n' "$(date -u +%FT%TZ)"

sec "1. Machine"
run 'whoami; hostname; uname -r; . /etc/os-release; echo "$PRETTY_NAME"'
run 'nproc; free -m; swapon --show; df -h --output=size,used,avail,target / ~ | uniq'
run 'uptime'
run 'systemctl is-active earlyoom; cat /etc/default/earlyoom 2>/dev/null | grep -v "^#" | grep .'
run 'ps -eo rss,comm --sort=-rss | head -12'
run 'tmux ls 2>/dev/null | cut -d: -f1'
run 'grep -h "Automatic-Reboot" /etc/apt/apt.conf.d/* 2>/dev/null'
end

sec "2. Claude Code install and sign-in (names only, no values)"
run 'claude --version; command -v claude; readlink -f "$(command -v claude)"'
run 'env | cut -d= -f1 | grep -E "^(ANTHROPIC|CLAUDE|BWS|HARNESS|CLOUDFLARE|CF_|GH_|GITHUB|OPENAI|DISABLE_|MAX_THINKING)" | sort'
run 'for f in ~/.config/claude/oauth.env ~/.claude/.credentials.json; do [ -e "$f" ] && stat -c "%a %s bytes %y %n" "$f" || echo "missing: $f"; done'
run 'grep -o "^[A-Z_]*=" ~/.config/claude/oauth.env 2>/dev/null'
run 'ls -la /etc/claude-code/ 2>/dev/null || echo "no managed settings dir"'
end

sec "3. Claude Code user settings (~/.claude/settings.json, secret-looking values masked)"
masked_json "$HOME/.claude/settings.json"
end

sec "4. Hooks, agents, skills, user CLAUDE.md"
run 'ls -la ~/.claude/hooks ~/.claude/agents ~/.claude/skills ~/.claude/commands 2>&1'
run 'sha256sum ~/.claude/hooks/*.py ~/.claude/hooks/*.sh 2>/dev/null | cut -c1-16,65-'
LINES_MAX=200 run 'cat ~/.claude/CLAUDE.md'
end

sec "5. Guard hook behaviour (fed directly, no model call)"
if [ ! -f ~/.claude/hooks/guard.py ]; then echo "no ~/.claude/hooks/guard.py: nothing to test"; else
for c in "bash harness/run.sh" "bash harness/run.sh --foreground" "python3 harness/loop.py run" \
         "python3 -I harness/loop.py status" "bash checks/run_gates.sh" "cd ~/projects/opencode-ui && bash checks/run_gates.sh" \
         "gh pr create --fill" "git push -u origin build/x" "sudo apt-get install -y jq" "nmap -sV 127.0.0.1" \
         "secret set FOO_API_KEY -" "wrangler deploy" "doctl compute droplet create x" "rm -rf node_modules"; do
  printf '%-60s -> ' "$c"
  printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(python3 -I -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$c")" \
    | python3 -I ~/.claude/hooks/guard.py >/dev/null 2>/tmp/guard.err; rc=$?
  [ $rc -eq 0 ] && echo "allowed" || echo "BLOCKED (exit $rc): $(head -c 120 /tmp/guard.err)"
done
rm -f /tmp/guard.err
fi
end

sec "6. MCP servers and the agent browser"
run 'claude mcp list'
run 'command -v agent-chrome agent-browser-mcp crun notify notify-send secret bws wrangler'
run 'ss -ltn | grep -E ":(9222|4096|4310)\b" | sed -E "s/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/<ip>/g"'
run 'ls ~/.config/agent-chrome 2>/dev/null | head -5'
end

sec "7. Secrets manager (Bitwarden Secrets Manager; counts and modes only)"
run 'bws --version'
run 'ls -la ~/.config/bws 2>&1 | sed -E "s/ [A-Z][a-z]{2} +[0-9]+ +[0-9:]+ / /"'
run 'for t in ~/.config/bws/*.token; do [ -e "$t" ] || continue; p=$(basename "$t" .token); n=$(secret --project "$p" ls 2>/dev/null | wc -l); echo "project $p: $n keys (rc of ls: $(secret --project "$p" ls >/dev/null 2>&1; echo $?))"; done'
run 'secret 2>&1 | head -12'
end

sec "8. Developer tools and accounts (no emails or ids)"
run 'git --version; git config --global user.name >/dev/null && echo "git user.name: set" || echo "git user.name: NOT set"; git config --global user.email >/dev/null && echo "git user.email: set" || echo "git user.email: NOT set"'
run 'gh --version | head -1; gh auth status 2>&1 | grep -Ei "logged in|scopes|protocol|token:" | sed -E "s/account [^ ]+/account <user>/"'
run 'node --version; npm --version; pnpm --version; python3 --version; docker --version; docker compose version; tmux -V; jq --version'
run 'ls ~/.cache/ms-playwright 2>/dev/null; npx --no-install playwright --version 2>/dev/null; google-chrome --version 2>/dev/null; chromium --version 2>/dev/null'
run 'wrangler --version 2>/dev/null; wrangler whoami 2>&1 | grep -Ei "logged|not authenticated|token" | head -3'
run 'opencode --version'
end

sec "9. How the template starts a run session on this machine (one Haiku call)"
if [ "${NO_PROBE:-0}" = 1 ]; then echo "skipped (NO_PROBE=1)"; else
  run "git -C '$TPL' log -1 --format='%h %s'; git -C '$TPL' status --porcelain | wc -l"
  ( cd "$TPL" && timeout 180 claude -p --settings harness/run-settings.json --strict-mcp-config --mcp-config harness/mcp.json \
      --output-format json --max-turns 6 --model claude-haiku-5-5 \
      'Run these three Bash commands one at a time and report the exit code of each: (1) gh --version (2) ls -ld ~/.config (3) secret ls > /dev/null. Then reply DONE.' \
      </dev/null 2>&1 ) > /tmp/probe.json
  python3 -I - /tmp/probe.json <<'PY'
import json, sys
raw = open(sys.argv[1]).read().strip().splitlines()
res = None
for line in reversed(raw):
    try:
        res = json.loads(line); break
    except ValueError:
        pass
if not isinstance(res, dict):
    print("no JSON result; last output:", " ".join(raw)[-400:]); sys.exit(0)
print("result keys:", sorted(res))
for k in ("is_error", "subtype", "num_turns", "duration_ms", "total_cost_usd"):
    print(f"{k}: {res.get(k)}")
print("usage:", json.dumps(res.get("usage"))[:600])
print("modelUsage:", json.dumps(res.get("modelUsage"))[:600])
print("permission_denials:", json.dumps(res.get("permission_denials"))[:600])
print("result text:", str(res.get("result"))[:600])
PY
  rm -f /tmp/probe.json
fi
end

sec "10. Template copy on this machine"
run "git -C '$TPL' log -3 --format='%h %ci %s'; git -C '$TPL' branch --show-current; git -C '$TPL' status --porcelain | head"
end
}

# Final safety filter: mask emails, IPv4 addresses and long token-like strings.
main | sed -E \
  -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/<email>/g' \
  -e 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}\b/<ip>/g' \
  -e 's/\b(sk-|gh[pousr]_|github_pat_|xox.-|AKIA|bws_)[A-Za-z0-9._-]{12,}/<token>/g' \
  -e 's/\b[A-Za-z0-9_-]{40,}\b/<long-string>/g'
