#!/usr/bin/env python3
"""Claude Code PreToolUse guard (Phase 8.2, John 2026-11-15).

Claude Code runs with all permission checks bypassed on johns-ubuntu. This hook still runs before
every tool call and blocks, by script, what John said must never happen automatically:
  - payments / purchases (paid cloud resources, checkout and billing pages, domain buys)
  - any pentesting (pentest tools, HexStrike)
  - a build that John holds: run, gates or push inside ~/projects/<name> while ~/.config/holds/<name>
    exists (John deletes that file to release the build; review T7/D1, 2026-11-16)
Exit code 2 blocks the call; the message on stderr goes back to the agent.
John can run these himself, or tell the agent to ask him.
"""
import json
import os
import re
import sys

PENTEST_TOOLS = (
    "nmap|masscan|rustscan|sqlmap|ffuf|gobuster|feroxbuster|dirb|dirbuster|wfuzz|nikto|hydra|medusa|john|"
    "hashcat|sslscan|testssl|testssl.sh|whatweb|wpscan|nuclei|amass|subfinder|msfconsole|msfvenom|"
    "metasploit|responder|netexec|nxc|crackmapexec|enum4linux|enum4linux-ng|aircrack-ng|bettercap"
)
PENTEST_CMD_RE = re.compile(r"^(" + PENTEST_TOOLS + r")$", re.I)
PENTEST = re.compile(r"hexstrike", re.I)  # anywhere: server, MCP bridge, repo
WRAPPERS = {"sudo", "env", "time", "nohup", "timeout", "nice", "ionice", "xargs", "exec", "command", "stdbuf"}


def pentest_in_command(cmd: str) -> bool:
    """True if a pentest tool is run as a command (first word of any pipeline/list segment)."""
    if PENTEST.search(cmd):
        return True
    for seg in re.split(r"[;&|\n()`]|\$\(", cmd):
        words = seg.strip().split()
        while words and (words[0] in WRAPPERS or re.match(r"^-|^\w+=|^\d+[smh]?$", words[0])):
            words = words[1:]
        if words and PENTEST_CMD_RE.match(words[0].rsplit("/", 1)[-1]):
            return True
    return False
PAYMENT_CMD = re.compile(
    r"(stripe\s+(charges|payment_intents|checkout|subscriptions|invoices|payment_links)\b[^\n]*\bcreate"
    r"|api\.stripe\.com/v1/(charges|payment_intents|subscriptions|checkout|invoices|payment_links)"
    r"|doctl\s+(compute\s+(droplet\s+(create|resize)|volume\s+create|load-balancer\s+create)"
    r"|databases\s+create|kubernetes\s+cluster\s+create|apps\s+create|registry\s+create)"
    r"|/registrar/|domains?\s+(purchase|register|buy)\b|\bbuy\s+domain\b"
    r"|wrangler\s+[^\n]*\b(subscribe|upgrade)\b)",
    re.I,
)
PAYMENT_URL = re.compile(
    r"(checkout|billing|payment|purchase|subscribe|subscription|upgrade|/cart\b|/pricing/buy|"
    r"pay\.|/pay\b|invoice|add-?credits|top-?up|plans?/(change|select))",
    re.I,
)
# Paid actions through MCP connectors (DigitalOcean, Cloudflare, etc.)
PAYMENT_MCP = re.compile(
    r"(droplet-create|droplet-resize|snapshot|volume-create|database-create|kubernetes|app-create|"
    r"registrar|domain-(register|purchase)|billing|subscription|purchase|payment|checkout)",
    re.I,
)
HOLD_DIR = os.path.expanduser("~/.config/holds")
PROJECTS = os.path.expanduser("~/projects")
# What a hold stops: starting the loop, running its gates, pushing the build branch.
HOLD_ACTION = re.compile(r"harness/run\.sh|harness/loop\.py\s+run\b|checks/run_gates\.sh|\bgit\b[^\n]*\bpush\b")


def held_build(cmd: str, cwd: str) -> str:
    """Name of a held project that this command would start, gate or push; "" if none."""
    try:
        names = [n for n in os.listdir(HOLD_DIR) if not n.startswith(".")]
    except OSError:
        return ""
    if not HOLD_ACTION.search(cmd):
        return ""
    for name in names:
        root = os.path.join(PROJECTS, name)
        inside = cwd == root or cwd.startswith(root + "/")
        named = re.search(r"projects/" + re.escape(name) + r"(/|\s|$|['\"])", cmd)
        if inside or named:
            return name
    return ""


def block(why: str) -> None:
    sys.stderr.write(
        f"BLOCKED by John's guard (~/.claude/hooks/guard.py): {why}. "
        "This needs John: stop and ask him (use `notify` if he is away)."
    )
    sys.exit(2)


def main() -> None:
    try:
        ev = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    tool = ev.get("tool_name", "") or ""
    inp = ev.get("tool_input", {}) or {}
    blob = json.dumps(inp)

    if tool == "Bash":
        cmd = inp.get("command", "") or ""
        if pentest_in_command(cmd):
            block("pentest tools and HexStrike are never run automatically")
        if PAYMENT_CMD.search(cmd):
            block("payments and paid resources are never automatic")
        held = held_build(cmd, str(ev.get("cwd") or ""))
        if held:
            block(f"the {held} build is on hold until John says go (he deletes ~/.config/holds/{held})")
        if re.search(r"\bcurl\b|\bwget\b|https?://", cmd) and re.search(
            r"https?://\S*(" + PAYMENT_URL.pattern + r")", cmd, re.I
        ) and re.search(r"-X\s*POST|--data|-d\s|--json|-F\s", cmd):
            block("POST to a payment/billing URL")
        sys.exit(0)

    if tool.startswith("mcp__"):
        low = tool.lower()
        # Browser tools: never open checkout/billing/payment pages
        if any(k in low for k in ("browser", "chrome", "playwright", "devtools", "puppeteer")):
            url = inp.get("url") or inp.get("href") or ""
            if url and PAYMENT_URL.search(url):
                block(f"browser navigation to a payment/billing page ({url})")
            sys.exit(0)
        # Connector tools that create paid resources
        if PAYMENT_MCP.search(tool) or PAYMENT_MCP.search(str(inp.get("qualified_name", ""))):
            if not re.search(r"(list|get|read|search|find|retrieve|describe)", tool + str(inp.get("qualified_name", "")), re.I):
                block("paid cloud/billing action through a connector")
        if PENTEST.search(blob) or ("command" in inp and pentest_in_command(str(inp["command"]))):
            block("pentest tools and HexStrike are never run automatically")
        sys.exit(0)

    if tool in ("WebFetch",) and PAYMENT_URL.search(str(inp.get("url", ""))):
        sys.exit(0)  # reading a pricing/billing doc page is fine

    sys.exit(0)


if __name__ == "__main__":
    main()
