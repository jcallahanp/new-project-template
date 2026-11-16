#!/usr/bin/env python3
"""The spec is spec/requirements.json. This script checks it, renders it for reading, and records approval.

  spec.py check      list every problem that would make the build guess (exit 1 if any)
  spec.py render     write spec/REQUIREMENTS.md from the JSON (the JSON is the only source of truth)
  spec.py approve    check + render + write .env.example + record the approval (hash) + commit
  spec.py secrets    say which secrets named in the spec are missing from the store (exit 1 if a required one John
                     supplies is missing; secrets an agent creates during the run may be missing at the start)

The secret store is the droplet's OpenBao vault when the `secret` helper is on PATH and the project has its own token
file ~/.config/openbao/<project>.token; otherwise `.env`. The vault project is the spec's `project` slug. A shell's
BAO_TOKEN / SECRET_PROJECT are never used and never passed on.

The build loop refuses to run unless spec/APPROVED matches the current JSON, so a spec edited after
approval has to be approved again.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESERVED = {"claude", "silk"}                       # vault projects of the machine's own agents, never a template project
LOOP_VARS = ("BAO_TOKEN", "SECRET_PROJECT", "HARNESS_DEPLOY_BY")   # set by the loop only, stripped from the shell's
SPECJ = ROOT / "spec" / "requirements.json"
EARS = re.compile(r"^(When|While|If|Where)\b.+\bshall\b.+|^The (system|[a-z][a-z -]{2,40}) shall\b.+", re.S)
STORY = re.compile(r"^As an? .+, I want .+ so that .+", re.S | re.I)
# Words that cannot be tested. A requirement that needs one needs a number or an example instead.
VAGUE = ["fast", "quick", "quickly", "easy", "easily", "simple", "user-friendly", "intuitive", "robust", "seamless", "seamlessly",
         "appropriate", "appropriately", "properly", "as needed", "etc", "and so on", "nice", "modern", "scalable", "efficient",
         "efficiently", "flexible", "reasonable", "good", "clean", "smooth", "minimal", "some", "various", "should"]
# A number with a measurable unit. Each one in a requirement's statement needs a `limits` entry that says whether it
# is a hard limit or a target, the margin, and how it is measured (a rough estimate must not fail at +1 %). Numbers
# in examples are concrete values (a banner showing "1040 MB") and need none.
UNIT = re.compile(r"(?<![\w.])(\d[\d,]*(?:\.\d+)?)\s?(milliseconds?|seconds?|secs?|minutes?|mins?|hours?|ms|s|h|req/s|rps|[KMG]i?B|B|%)(?![A-Za-z/])", re.I)
UNIT_ALIAS = {"millisecond": "ms", "milliseconds": "ms", "second": "s", "seconds": "s", "sec": "s", "secs": "s", "minute": "min",
              "minutes": "min", "mins": "min", "hour": "h", "hours": "h", "rps": "req/s"}


def unit_key(u):
    u = str(u).strip().lower()
    return UNIT_ALIAS.get(u, u)


def num(x):
    return float(str(x).replace(",", ""))


def limit_problems(rid, r, text):
    out, lims = [], r.get("limits", [])
    if not isinstance(lims, list) or any(not isinstance(x, dict) for x in lims):
        return [f"{rid}: `limits` must be a list of objects"]
    for x in lims:
        name = x.get("name") or "?"
        v, m = x.get("value"), x.get("margin")
        if not str(x.get("name", "")).strip() or isinstance(v, bool) or not isinstance(v, (int, float)) or not str(x.get("unit", "")).strip():
            out.append(f"{rid}: limit {name}: needs a `name`, a numeric `value` and a `unit`")
        if x.get("kind") not in ("hard", "target"):
            out.append(f"{rid}: limit {name}: `kind` must be `hard` (fails at the value) or `target` (passes within the margin)")
        ok_margin = (isinstance(m, (int, float)) and not isinstance(m, bool) and m >= 0) or bool(re.fullmatch(r"\d+(\.\d+)?%", str(m)))
        zero = ok_margin and float(str(m).rstrip("%")) == 0
        if x.get("kind") == "target" and (not ok_margin or zero):
            out.append(f"{rid}: limit {name}: a target needs a `margin` above 0, like \"10%\" or a number in {x.get('unit', 'its unit')}")
        if x.get("kind") == "hard" and m is not None and not zero:
            out.append(f"{rid}: limit {name}: a hard limit fails at its value; give it margin 0 or make it a target")
        if len(str(x.get("measure", "")).split()) < 4:
            out.append(f"{rid}: limit {name}: `measure` must say how it is measured (what, how often, how many runs)")
    have = {(num(x["value"]), unit_key(x.get("unit"))) for x in lims if isinstance(x.get("value"), (int, float)) and not isinstance(x.get("value"), bool)}
    for value, unit in UNIT.findall(text):
        if (num(value), unit_key(unit)) not in have:
            have.add((num(value), unit_key(unit)))      # report each missing number once
            out.append(f"{rid}: \"{value} {unit}\" needs a `limits` entry with value {value} and unit {unit}: hard limit or target, "
                       "the margin, and how it is measured (ask John)")
    return out


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
    if slug(s) in RESERVED:
        out.append(f"`project` {s['project']!r}: the vault projects {', '.join(sorted(RESERVED))} belong to the machine's own agents; "
                   "choose another name")
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
        elif any(k not in ("name", "purpose", "required", "created_by") for k in x):
            out.append(f"secret {x['name']}: only name, purpose, required, created_by are allowed (never a value)")
        elif x.get("created_by", "john") not in ("john", "agent"):
            out.append(f"secret {x['name']}: created_by must be `john` (he supplies it before the run) or `agent` (a run session "
                       "creates it, for example an API key made in a web dashboard)")
    if s["deploy"].get("by", "john") not in ("john", "agent"):
        out.append("`deploy.by` must be `john` (default: he deploys) or `agent` (a run session may deploy and publish)")
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
        out += limit_problems(rid, r, st)
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
        if r.get("limits"):
            L += ["", "**Limits:**", ""] + [f"- {x['name']}: {x['value']} {x['unit']}, {x['kind']}"
                                           + (f" (passes up to {x['value']} {x['unit']} + {x['margin']})" if x["kind"] == "target" else " (fails at the value)")
                                           + f"; measured: {x['measure']}" for x in r["limits"]]
        L += ["", f"**How it is proven:** {r['verify']}", ""]
    for title, key in (("Will not do", "non_goals"), ("Constraints", "constraints"), ("Assumptions", "assumptions"),
                       ("Only John does these", "human_gates")):
        L += [f"## {title}", ""] + ([f"- {x}" for x in s[key]] or ["- none"]) + [""]
    L += ["## Deploy", "", f"Target: {s['deploy']['target']}", "",
          f"Deployed by: {'a run session (agent)' if s['deploy'].get('by') == 'agent' else 'John'}", "", "Ready to deploy when:", ""] + [f"- {x}" for x in s["deploy"]["ready_when"]]
    L += ["", "## Secrets (names only; values go in the vault or `.env`)", ""]
    L += [f"- `{x['name']}`{'' if x.get('required', True) else ' (optional)'}{' (created by an agent during the run)' if x.get('created_by') == 'agent' else ''}: "
          f"{x['purpose']}" for x in s["secrets"]] or ["- none"]
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


def slug(s):
    """The project's short name: the build branch is build/<slug> and the vault project is <slug>."""
    return re.sub(r"[^a-z0-9]+", "-", str(s.get("project", "project")).lower()).strip("-")[:40] or "project"


def vault(s):
    """(project, token) when the vault is this project's secret store: the `secret` helper is on PATH and the
    project's own token file exists. Never a token from the shell, never a reserved project."""
    p = slug(s)
    f = Path.home() / ".config" / "openbao" / f"{p}.token"
    if not shutil.which("secret") or p in RESERVED or not f.is_file():
        return None
    tok = f.read_text().strip()
    return (p, tok) if tok else None


def clean_env(base=None):
    """A copy of the environment without the shell's vault and deploy variables (only the loop sets them)."""
    return {k: v for k, v in (os.environ if base is None else base).items() if k not in LOOP_VARS}


def _secret(p, env, *args):
    """Run the helper, retrying a few times with short pauses. Returns stdout; raises RuntimeError without any value."""
    waits = [float(x) for x in os.environ.get("HARNESS_VAULT_WAITS", "2,5,15").split(",") if x.strip()]
    why = ""
    for wait in waits + [None]:
        try:
            r = subprocess.run(["secret", "--project", p, *args], capture_output=True, text=True, env=env,
                               timeout=float(os.environ.get("HARNESS_VAULT_TIMEOUT", "30")))
            if r.returncode == 0:
                return r.stdout
            why = f"exited {r.returncode}" + (f": {r.stderr.strip()[-200:]}" if args[0] == "ls" else "")
        except subprocess.TimeoutExpired:
            why = "did not answer in time"
        except OSError as e:
            why = f"could not run: {e.strerror}"
        if wait is not None:
            time.sleep(wait)
    raise RuntimeError(f"the vault does not answer: `secret --project {p} {args[0]}{' NAME' if len(args) > 1 else ''}` {why} "
                       f"({len(waits) + 1} tries)")


def vault_values(s):
    """The spec's secrets that exist in the vault as {NAME: value} (each read with `secret get`, so multi-line values
    such as PEM keys stay whole), and the variables a session needs for this project's vault only (BAO_TOKEN,
    SECRET_PROJECT). Names not in the vault yet are skipped. Raises RuntimeError (never with a value)."""
    p, tok = vault(s)
    extra = {"BAO_TOKEN": tok, "SECRET_PROJECT": p}
    env = {**clean_env(), **extra}
    stored = set(_secret(p, env, "ls").split())
    vals = {}
    for x in s.get("secrets", []):
        if isinstance(x, dict) and x.get("name") in stored:
            v = _secret(p, env, "get", x["name"])
            vals[x["name"]] = v[:-1] if v.endswith("\n") else v
    return vals, extra


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd not in ("check", "render", "approve", "secrets"):
        sys.exit(__doc__)
    s = load()
    probs = problems(s)
    if cmd == "secrets":                    # each output line starts with ok, note or FAIL (preflight shows them so)
        v = vault(s)
        if v:
            try:
                have = vault_values(s)[0]
            except RuntimeError as e:
                sys.exit(f"FAIL  {e}")
            print(f"ok    vault project {v[0]} answers (secret --project {v[0]} ls)")
            store, how = f"the vault (project {v[0]})", f"secret --project {v[0]} set NAME -   (value on stdin)"
        else:
            have, store, how = env_keys(), ".env", "add NAME=value lines to .env"
        sec = [x for x in s.get("secrets", []) if isinstance(x, dict)]
        john = [x for x in sec if x.get("created_by", "john") != "agent"]
        agent = [x["name"] for x in sec if x.get("created_by") == "agent" and not have.get(x["name"])]
        missing = [x["name"] for x in john if x.get("required", True) and not have.get(x["name"])]
        optional = [x["name"] for x in john if not x.get("required", True) and not have.get(x["name"])]
        if agent:
            print(f"note  not in {store} yet; a run session creates and stores them: " + ", ".join(agent))
        if optional:
            print(f"note  optional secrets not set in {store}: " + ", ".join(optional))
        if missing:
            print(f"FAIL  missing from {store} ({how}): " + ", ".join(missing))
            sys.exit(1)
        print(f"ok    every required secret John supplies is in {store}")
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
