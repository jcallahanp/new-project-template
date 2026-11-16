#!/usr/bin/env python3
"""Statistics of one unattended build, from ledger.jsonl and PROGRESS.md.

Usage: python3 review/analysis/ledger_stats.py /path/to/project

Reads only <project>/ledger.jsonl, <project>/PROGRESS.md (the files as checked out).
Prints a markdown report. Standard library only. Anything the two files do not
record is reported as "not recorded"; nothing is guessed.

PROGRESS.md format (written by harness/loop.py record()):
  ## <utc> · <card id>
  - action: <text>  (work legs: "work leg (N turns, Ns) [+ verify leg (N turns, Ns)]: <first line of message>")
  - check: ...   - commit: ...   - next: ...
The timestamp is taken when the entry is written, i.e. at the END of the step.
"""
import json
import re
import statistics
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

LEG = r"(\w+) leg \((\d+) turns?, (\d+)s\)"


def ts(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def fmt_s(x):
    x = int(round(x))
    h, r = divmod(x, 3600)
    m, s = divmod(r, 60)
    return f"{h}h{m:02d}m" if h else f"{m}m{s:02d}s"


def load_progress(path):
    entries, cur = [], None
    for line in path.read_text().splitlines():
        m = re.match(r"^## (\S+) · (\S+)\s*$", line)
        if m:
            cur = {"t": m.group(1), "id": m.group(2), "action": "", "check": "", "commit": "", "next": ""}
            entries.append(cur)
            continue
        m = re.match(r"^- (action|check|commit|next): ?(.*)$", line)
        if m and cur is not None:
            cur[m.group(1)] = m.group(2)
    for e in entries:
        e["dt"] = ts(e["t"])
        e["legs"] = []  # (type, turns, secs)
        for lm in re.finditer(LEG, e["action"]):
            e["legs"].append((lm.group(1), int(lm.group(2)), int(lm.group(3))))
        a, c = e["action"], e["check"]
        e["pass"] = "-> pass" in c
        e["stage"] = None
        e["kind"] = "event"
        if e["legs"]:
            e["kind"] = e["legs"][0][0]  # design / plan / work / audit
            if not e["pass"]:
                if "fail at verify" in c:
                    e["stage"] = "verify"
                elif "stopped at its" in a:
                    e["stage"] = "timeout"
                elif "gates failed" in a:
                    e["stage"] = "gates"
                elif "task check" in a:
                    e["stage"] = "check"
                elif "fail at check" in c:
                    e["stage"] = "other"
                else:
                    e["stage"] = "other"
        e["legsecs"] = sum(s for _, _, s in e["legs"])
    return entries


def stat_row(name, vals):
    if not vals:
        return f"| {name} | 0 | - | - | - |"
    return f"| {name} | {len(vals)} | {sum(vals)} | {statistics.median(vals):g} | {max(vals)} |"


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    cards = [json.loads(l) for l in (root / "ledger.jsonl").read_text().splitlines() if l.strip()]
    E = load_progress(root / "PROGRESS.md")
    out = []
    P = out.append

    P(f"Source: `{root}` — {len(E)} PROGRESS entries, {len(cards)} ledger cards "
      f"({sum(c['kind'] == 'task' for c in cards)} tasks, {sum(c['kind'] == 'milestone' for c in cards)} milestones).")
    P("")

    # ---- 1. legs by type ----------------------------------------------------------
    legs = defaultdict(list)  # type -> [(turns, secs, entry)]
    for e in E:
        for t, n, s in e["legs"]:
            legs[t].append((n, s, e))
    P("## 1. Legs by type")
    P("")
    P("A leg = one `claude -p` session. Counted from `(N turns, Ns)` in PROGRESS.md; a work entry may hold a work leg and a verify leg.")
    P("")
    P("| leg type | count | zero-turn legs (timeouts) |")
    P("|---|---|---|")
    for t in ("design", "plan", "work", "verify", "audit"):
        L = legs.get(t, [])
        P(f"| {t} | {len(L)} | {sum(1 for n, _, _ in L if n == 0)} |")
    P(f"| **total** | **{sum(len(v) for v in legs.values())}** | |")
    P("")
    P("### Turns and seconds per leg type")
    P("")
    P("| leg type | n | turns sum | turns median | turns max |")
    P("|---|---|---|---|---|")
    for t in ("design", "plan", "work", "verify", "audit"):
        P(stat_row(t, [n for n, _, _ in legs.get(t, [])]))
    P("")
    P("| leg type | n | seconds sum | seconds median | seconds max |")
    P("|---|---|---|---|---|")
    for t in ("design", "plan", "work", "verify", "audit"):
        P(stat_row(t, [s for _, s, _ in legs.get(t, [])]))
    P("")
    tot_leg_s = sum(s for v in legs.values() for _, s, _ in v)
    tot_turns = sum(n for v in legs.values() for n, _, _ in v)
    P(f"Sum over all legs: {tot_turns} turns, {tot_leg_s} s ({fmt_s(tot_leg_s)}).")
    P("")
    P("Share of leg seconds by type: " + ", ".join(
        f"{t} {100 * sum(s for _, s, _ in legs.get(t, [])) / max(tot_leg_s, 1):.0f}%" for t in ("design", "plan", "work", "verify", "audit")) + ".")
    P("")
    P("Per-leg token use, cost, model and effort: not recorded in PROGRESS.md or ledger.jsonl.")
    P("")

    # ---- 2. work attempts per task -------------------------------------------------
    P("## 2. Work attempts per task")
    P("")
    seq = defaultdict(list)  # task id -> [entry]
    for e in E:
        if e["kind"] == "work":
            seq[e["id"]].append(e)
    tasks = {c["id"]: c for c in cards if c["kind"] == "task"}
    first = Counter()
    detail = []
    for tid, es in seq.items():
        fails = 0
        outcome = None
        for e in es:
            if e["pass"]:
                outcome = f"passed on work attempt {fails + 1}"
                break
            fails += 1
        if outcome is None:
            outcome = f"not passed yet ({fails} failed attempts)"
        # attempts counted by the loop reset to 0 on a human reset, so count raw legs
        if fails >= 3:
            later = es[-1]["pass"]
            key = "blocked after 3 failed attempts" + (", then passed after a human reset" if later else ", not passed yet (ledger state: " + tasks.get(tid, {}).get("state", "?") + ")")
        elif outcome.startswith("passed"):
            key = {1: "passed first try", 2: "passed second try", 3: "passed third try"}[fails + 1]
        else:
            key = outcome
        first[key] += 1
        if fails:
            detail.append((tid, "".join("P" if e["pass"] else "F" for e in es), key))
    P("| outcome | tasks |")
    P("|---|---|")
    for k in ("passed first try", "passed second try", "passed third try"):
        P(f"| {k} | {first.get(k, 0)} |")
    for k, v in first.items():
        if k.startswith("blocked") or k.startswith("not passed"):
            P(f"| {k} | {v} |")
    never = [t for t in tasks if t not in seq]
    P(f"| not started (no work leg yet) | {len(never)} |")
    P(f"| **tasks with at least one work leg** | **{len(seq)}** |")
    P("")
    P(f"Work entries: {sum(len(v) for v in seq.values())} ({sum(1 for v in seq.values() for e in v if e['pass'])} passed, "
      f"{sum(1 for v in seq.values() for e in v if not e['pass'])} failed). Tasks that needed a retry (F = failed attempt, P = pass, in order):")
    P("")
    for tid, s, k in detail:
        P(f"- {tid}: {s} — {k}")
    P("")

    # ---- 3. failures by stage ---------------------------------------------------------
    P("## 3. Failures by stage")
    P("")
    P("Stage from the entry text: timeout = \"stopped at its N-minute limit\"; gates = \"gates failed\"; check = \"task check ... failed\"; verify = \"fail at verify\"; other = rest.")
    P("")
    fs = defaultdict(list)
    for e in E:
        if e["kind"] == "work" and not e["pass"]:
            fs[e["stage"]].append(e)
    P("| stage | failed work steps | seconds spent in those steps (work+verify legs) | turns |")
    P("|---|---|---|---|")
    for st in ("check", "gates", "verify", "timeout", "other"):
        L = fs.get(st, [])
        P(f"| {st} | {len(L)} | {sum(e['legsecs'] for e in L)} | {sum(n for e in L for _, n, _ in e['legs'])} |")
    allf = [e for L in fs.values() for e in L]
    P(f"| **all** | **{len(allf)}** | **{sum(e['legsecs'] for e in allf)}** ({fmt_s(sum(e['legsecs'] for e in allf))}) | {sum(n for e in allf for _, n, _ in e['legs'])} |")
    works = [e for e in E if e["kind"] == "work"]
    P("")
    P(f"{len(allf)} of {len(works)} work steps failed ({100 * len(allf) / max(len(works), 1):.0f}%). Seconds in passing work steps (work+verify): "
      f"{sum(e['legsecs'] for e in works if e['pass'])}.")
    P("")
    P("What failed inside `check` and `gates`: the loop writes only the first line of the message into PROGRESS.md "
      "(\"task check `...` failed:\" / \"gates failed:\"); the failing output is not recorded there. ledger.jsonl keeps the last failure text only until the task passes (the note is then overwritten with \"verified: ...\").")
    P("")
    # ---- 4. verify ---------------------------------------------------------------------
    vlegs = [e for e in E if any(t == "verify" for t, _, _ in e["legs"])]
    vfail = [e for e in vlegs if e["stage"] == "verify"]
    P("## 4. Verify legs")
    P("")
    P(f"Verify legs run: {len(vlegs)} (only after the work leg's check and gates passed). Verifier FAIL: {len(vfail)} "
      f"({100 * len(vfail) / max(len(vlegs), 1):.1f}%). Verifier PASS: {len(vlegs) - len(vfail)}.")
    P("")
    reasons = Counter()
    for e in vfail:
        reasons[e["action"].split("): ", 1)[-1] if "): " in e["action"] else e["action"]] += 1
    P("Verifier reasons, grouped (the loop stores only the first line, cut at 200 characters):")
    P("")
    for r, n in reasons.most_common():
        P(f"- x{n} {r}")
    pas = Counter()
    for e in vlegs:
        if e["stage"] != "verify":
            pas[e["action"].split("): ", 1)[-1]] += 1
    P("")
    P("Verifier PASS texts: " + "; ".join(f"x{n} \"{r}\"" for r, n in pas.most_common()) + ".")
    P("")
    vs = [s for t, _, s in [(t, n, s) for e in vlegs for (t, n, s) in e["legs"]] if t == "verify"]
    P(f"Seconds spent in verify legs that passed: {sum(s for e in vlegs if e['stage'] != 'verify' for t, _, s in e['legs'] if t == 'verify')}; "
      f"in verify legs that failed: {sum(s for e in vfail for t, _, s in e['legs'] if t == 'verify')}.")
    P("")

    # ---- 5. planning ---------------------------------------------------------------------
    P("## 5. Planning rounds per milestone and plan rejections")
    P("")
    pl = defaultdict(list)
    for e in E:
        if e["kind"] == "plan":
            pl[e["id"]].append(e)
    miles = [c for c in cards if c["kind"] == "milestone"]
    P("| milestone | plan legs | accepted | rejected | ledger `rounds` | tasks planned | state |")
    P("|---|---|---|---|---|---|---|")
    unplanned = [m["id"] for m in miles if not pl.get(m["id"]) and not any(c.get("parent") == m["id"] for c in cards)]
    for m in miles:
        L = pl.get(m["id"], [])
        nt = sum(1 for c in cards if c.get("parent") == m["id"])
        if m["id"] in unplanned:
            continue
        P(f"| {m['id']} | {len(L)} | {sum(e['pass'] for e in L)} | {sum(not e['pass'] for e in L)} | {m.get('rounds', 0)} | {nt} | {m['state']} |")
    P("")
    P("Not yet planned (0 plan legs): " + (", ".join(unplanned) or "none") + ".")
    P("")
    P("Plan rejections (reason = first line of the message):")
    P("")
    rej = [e for e in E if e["kind"] == "plan" and not e["pass"]]
    for e in rej:
        P(f"- {e['t']} {e['id']}: {e['action'].split('): ', 1)[-1]} ({e['legs'][0][1]} turns, {e['legs'][0][2]}s)")
    if not rej:
        P("- none")
    P("")
    closed = [e for e in E if e["action"].startswith("milestone closed")]
    P(f"Acceptance-failure replans (\"tasks done but acceptance fails\"): {sum(1 for e in E if e['action'].startswith('tasks done but acceptance fails'))}. "
      f"Milestones closed: {len(closed)}. Milestones blocked by their tasks: {sum(1 for e in E if e['action'].startswith('milestone blocked'))}.")
    P("")

    # ---- 6. wall clock ----------------------------------------------------------------------
    P("## 6. Wall-clock and gaps")
    P("")
    t0, t1 = E[0]["dt"], E[-1]["dt"]
    wall = (t1 - t0).total_seconds()
    P(f"First entry {E[0]['t']} ({E[0]['id']}), last entry {E[-1]['t']} ({E[-1]['id']}): {fmt_s(wall)} ({int(wall)} s) wall-clock. "
      "Entry timestamps are written at the end of a step.")
    P("")
    gaps = []
    for a, b in zip(E, E[1:]):
        g = (b["dt"] - a["dt"]).total_seconds()
        gaps.append((g, a, b))
    P(f"Time inside recorded legs: {tot_leg_s} s ({fmt_s(tot_leg_s)}) = {100 * tot_leg_s / wall:.0f}% of wall-clock. "
      f"The rest ({fmt_s(wall - tot_leg_s)}) is time the log does not attribute: the loop's own checks, gates and acceptance runs, "
      "git, and any waiting or stop. It cannot be split further from these files.")
    P("")
    P("Gap = time from the previous entry to this one. \"unattributed\" = gap minus this entry's recorded leg seconds.")
    P("")
    P("| gap > 30 min | before entry | entry | gap | legs in entry | unattributed |")
    P("|---|---|---|---|---|---|")
    n = 0
    for g, a, b in gaps:
        if g > 1800:
            n += 1
            P(f"| {n} | {a['t']} {a['id']} | {b['t']} {b['id']} ({b['kind']}{'' if b['pass'] else ' FAIL'}) | {fmt_s(g)} | {b['legsecs']}s | {fmt_s(g - b['legsecs'])} |")
    if not n:
        P("| none | | | | | |")
    P("")
    P("Unattributed time by entry kind (gap minus recorded leg seconds; includes the loop's check, gates and acceptance time):")
    P("")
    P("| entry kind | entries | sum | median | max |")
    P("|---|---|---|---|---|")
    ua = defaultdict(list)
    for g, a, b in gaps:
        k = ("work pass" if b["pass"] else f"work fail ({b['stage']})") if b["kind"] == "work" else (
            "milestone closed" if b["action"].startswith("milestone closed") else b["kind"] + (" pass" if b["pass"] else " fail") if b["kind"] != "event" else "other event")
        ua[k].append(g - b["legsecs"])
    for k, v in sorted(ua.items(), key=lambda kv: -sum(kv[1]))[:5]:
        P(f"| {k} | {len(v)} | {fmt_s(sum(v))} | {fmt_s(statistics.median(v))} | {fmt_s(max(v))} |")
    P("")
    P("Usage-limit waits: not recorded as such. The loop has a wait counter (`WAITED`) but PROGRESS.md has no wait entry; "
      "gaps with large unattributed time are the only trace.")
    P("")

    # ---- 7. tasks per milestone, files per task ----------------------------------------------
    P("## 7. Tasks per milestone and files per task")
    P("")
    P("| milestone | requirements | tasks | done | files per task (min / median / max) | distinct files | task seconds (work+verify legs) |")
    P("|---|---|---|---|---|---|---|")
    allfiles = []
    for m in miles:
        ts_ = [c for c in cards if c.get("parent") == m["id"]]
        if not ts_:
            continue
        fl = [len(c.get("files", [])) for c in ts_]
        allfiles += fl
        dist = set(f for c in ts_ for f in c.get("files", []))
        secs = sum(e["legsecs"] for e in E if e["kind"] == "work" and e["id"].startswith(m["id"] + "."))
        P(f"| {m['id']} | {len(m.get('requirements', []))} | {len(ts_)} | {sum(c['state'] == 'done' for c in ts_)} | "
          + (f"{min(fl)} / {statistics.median(fl):g} / {max(fl)}" if fl else "- ") + f" | {len(dist)} | {secs if ts_ else '-'} |")
    P("")
    if allfiles:
        P(f"All planned tasks: {len(allfiles)}; files per task min {min(allfiles)}, median {statistics.median(allfiles):g}, max {max(allfiles)}, mean {statistics.mean(allfiles):.1f}.")
    P("")
    P("Seconds per passing task (work+verify legs of the passing step only):")
    P("")
    ps = [e["legsecs"] for e in works if e["pass"]]
    if ps:
        P(f"n={len(ps)}, median {statistics.median(ps):g} s, max {max(ps)} s, sum {sum(ps)} s.")
    P("")
    P("Wall-clock per milestone (previous milestone-close entry to this one's close entry):")
    P("")
    prev = E[[i for i, e in enumerate(E) if e["id"] == "DESIGN" and e["kind"] == "design"][0]]["dt"]
    for e in E:
        if e["action"].startswith("milestone closed"):
            P(f"- {e['id']}: {fmt_s((e['dt'] - prev).total_seconds())} (closed {e['t']})")
            prev = e["dt"]
    P("")
    P("Files changed per task by the work leg (actual diff size), lines of code, tokens: not recorded (the ledger `files` field is the plan's file list, not the diff).")
    print("\n".join(out))


if __name__ == "__main__":
    main()
