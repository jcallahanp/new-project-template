#!/usr/bin/env python3
"""The spec is spec/requirements.json. This script checks it, renders it for reading, and records approval.

  spec.py check      list every problem that would make the build guess (exit 1 if any)
  spec.py render     write spec/REQUIREMENTS.md from the JSON (the JSON is the only source of truth)
  spec.py approve    check + render + write .env.example + record the approval (hash) + commit
  spec.py secrets    say which secrets named in the spec are missing from .env (exit 1 if any required one is)

The build loop refuses to run unless spec/APPROVED matches the current JSON, so a spec edited after
approval has to be approved again.
"""
import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPECJ = ROOT / "spec" / "requirements.json"
EARS = re.compile(r"^(When|While|If|Where)\b.+\bshall\b.+|^The (system|[a-z][a-z -]{2,40}) shall\b.+", re.S)
STORY = re.compile(r"^As an? .+, I want .+ so that .+", re.S | re.I)
# Words that cannot be tested. A requirement that needs one needs a number or an example instead.
VAGUE = ["fast", "quick", "quickly", "easy", "easily", "simple", "user-friendly", "intuitive", "robust", "seamless", "seamlessly",
         "appropriate", "appropriately", "properly", "as needed", "etc", "and so on", "nice", "modern", "scalable", "efficient",
         "efficiently", "flexible", "reasonable", "good", "clean", "smooth", "minimal", "some", "various", "should"]


def load():
    try:
        return json.loads(SPECJ.read_text())
    except OSError:
        sys.exit("spec/requirements.json does not exist yet: run /intake in `claude` first")
    except ValueError as e:
        sys.exit(f"spec/requirements.json is not valid JSON: {e}")


def problems(s):
    out = []
    for key, kind in (("project", str), ("summary", str), ("users", list), ("non_goals", list), ("constraints", list),
                      ("assumptions", list), ("deploy", dict), ("secrets", list), ("human_gates", list),
                      ("open_questions", list), ("requirements", list)):
        if not isinstance(s.get(key), kind):
            out.append(f"`{key}` is missing or is not a {kind.__name__}")
    if out:
        return out
    if len(s["summary"]) < 80:
        out.append("`summary` must say in a few sentences what is being built, for whom and why")
    if not s["users"]:
        out.append("`users`: name at least one kind of user")
    if not s["non_goals"]:
        out.append("`non_goals`: name at least one thing this project will not do (ask John for anti-goals)")
    if s["open_questions"]:
        out.append(f"{len(s['open_questions'])} open question(s) left: ask John, or record his decision to drop them")
    if not str(s["deploy"].get("target", "")).strip() or not s["deploy"].get("ready_when"):
        out.append("`deploy` needs a `target` and at least one observable `ready_when` statement")
    for x in s["secrets"]:
        if not isinstance(x, dict) or not re.fullmatch(r"[A-Z][A-Z0-9_]{2,}", str(x.get("name", ""))) or not x.get("purpose"):
            out.append(f"secret {x!r}: needs a NAME_LIKE_THIS and a purpose (never the value)")
        elif any(k not in ("name", "purpose", "required") for k in x):
            out.append(f"secret {x['name']}: only name, purpose, required are allowed (never a value)")
    if not s["requirements"]:
        out.append("no requirements yet")
    seen = set()
    for n, r in enumerate(s["requirements"], 1):
        rid = str(r.get("id", f"#{n}"))
        if not re.fullmatch(r"R[0-9]{1,3}", rid):
            out.append(f"{rid}: id must look like R1, R2, …")
        if rid in seen:
            out.append(f"{rid}: duplicate id")
        seen.add(rid)
        if r.get("priority") not in ("must", "should"):
            out.append(f"{rid}: priority must be `must` or `should` (a `could` or `won't` belongs in non_goals)")
        if not STORY.match(str(r.get("story", ""))):
            out.append(f"{rid}: story must read \"As a <user>, I want <capability> so that <outcome>.\"")
        st = str(r.get("statement", ""))
        if not EARS.match(st):
            out.append(f"{rid}: statement must be one EARS sentence: \"When/While/If/Where <condition>, the system shall <response>.\" "
                       "or \"The system shall <response>.\"")
        ex = r.get("examples")
        if not isinstance(ex, list) or not ex or any(not isinstance(e, dict) or any(len(str(e.get(k, ""))) < 4 for k in ("given", "when", "then")) for e in ex):
            out.append(f"{rid}: needs at least one concrete example with given / when / then (real values, not placeholders)")
            ex = []
        if len(str(r.get("verify", ""))) < 20:
            out.append(f"{rid}: `verify` must say how a script can prove it (what it runs, what it observes)")
        text = " ".join([st] + [str(e.get("then", "")) for e in ex]).lower()
        hits = [w for w in VAGUE if re.search(rf"(?<![a-z-]){re.escape(w)}(?![a-z-])", text)]
        if hits:
            out.append(f"{rid}: untestable wording ({', '.join(hits)}): replace with a number, a limit or an example")
    return out


def render(s):
    L = [f"# Requirements: {s['project']}", "",
         "Generated from `spec/requirements.json` by `python3 harness/spec.py render`. Edit the JSON, not this file.", "",
         "## What and why", "", s["summary"], "", "## Users", ""] + [f"- {u}" for u in s["users"]]
    L += ["", "## Requirements", ""]
    for r in s["requirements"]:
        L += [f"### {r['id']} ({r['priority']})", "", f"**Story:** {r['story']}", "", f"**Requirement:** {r['statement']}", "", "**Examples:**", ""]
        L += [f"- Given {e['given']}, when {e['when']}, then {e['then']}" for e in r["examples"]]
        L += ["", f"**How it is proven:** {r['verify']}", ""]
    for title, key in (("Will not do", "non_goals"), ("Constraints", "constraints"), ("Assumptions", "assumptions"),
                       ("Only John does these", "human_gates")):
        L += [f"## {title}", ""] + ([f"- {x}" for x in s[key]] or ["- none"]) + [""]
    L += ["## Deploy", "", f"Target: {s['deploy']['target']}", "", "Ready to deploy when:", ""] + [f"- {x}" for x in s["deploy"]["ready_when"]]
    L += ["", "## Secrets (names only; values go in `.env`)", ""]
    L += [f"- `{x['name']}`{'' if x.get('required', True) else ' (optional)'}: {x['purpose']}" for x in s["secrets"]] or ["- none"]
    return "\n".join(L) + "\n"


def env_keys():
    f = ROOT / ".env"
    keys = {}
    if f.is_file():
        for line in f.read_text().splitlines():
            m = re.match(r"\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$", line)
            if m and not line.lstrip().startswith("#"):
                keys[m.group(1)] = m.group(2).strip().strip("\"'")
    return keys


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd not in ("check", "render", "approve", "secrets"):
        sys.exit(__doc__)
    s = load()
    probs = problems(s)
    if cmd == "secrets":
        have = env_keys()
        missing = [x["name"] for x in s.get("secrets", []) if x.get("required", True) and not have.get(x["name"])]
        optional = [x["name"] for x in s.get("secrets", []) if not x.get("required", True) and not have.get(x["name"])]
        if optional:
            print("optional secrets not set: " + ", ".join(optional))
        if missing:
            print("missing from .env (add NAME=value lines): " + ", ".join(missing))
            sys.exit(1)
        print(f"secrets: all {len(s.get('secrets', [])) - len(optional)} required value(s) present in .env")
        return
    if probs:
        print(f"{len(probs)} problem(s) in spec/requirements.json:")
        print("\n".join(f"- {p}" for p in probs))
        sys.exit(1)
    if cmd == "check":
        print(f"spec ok: {len(s['requirements'])} requirements, {len(s['secrets'])} secrets, no open questions")
        return
    (ROOT / "spec" / "REQUIREMENTS.md").write_text(render(s))
    if cmd == "render":
        print("wrote spec/REQUIREMENTS.md")
        return
    lines = ["# Secrets this project needs. Copy to .env and fill in the values. .env is never committed.", ""]
    for x in s["secrets"]:
        lines += [f"# {x['purpose']}" + ("" if x.get("required", True) else " (optional)"), f"{x['name']}=", ""]
    (ROOT / ".env.example").write_text("\n".join(lines))
    (ROOT / "spec" / "APPROVED").write_text(json.dumps({
        "sha256": hashlib.sha256(SPECJ.read_bytes()).hexdigest(), "approved_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "requirements": len(s["requirements"])}, indent=1) + "\n")
    subprocess.run(["git", "add", "spec", ".env.example"], cwd=ROOT, check=True)
    subprocess.run(["git", "commit", "-q", "-m", f"spec: approved ({len(s['requirements'])} requirements)"], cwd=ROOT, check=False)
    print(f"approved: {len(s['requirements'])} requirements. Next: put secret values in .env, then `bash harness/run.sh`.")


if __name__ == "__main__":
    main()
