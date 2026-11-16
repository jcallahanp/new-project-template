#!/usr/bin/env python3
"""T4 check: every recommendation row (C1..C12, D1..D7) in review/FINDINGS.md cites evidence:
a `path`, a commit, the inventory, or the run data. Prints uncited rows; exit 1 if any."""
import re, sys
text = open(sys.argv[1] if len(sys.argv) > 1 else "review/FINDINGS.md").read()
rows = [l for l in text.splitlines() if re.match(r"^\| (C|D)\d+ \|", l)]
cite = re.compile(r"`[^`]+`|inventory|run-data|feb4339|[0-9a-f]{7}\b")
bad = [l[:80] for l in rows if not cite.search(l)]
ids = {re.match(r"^\| ((C|D)\d+)", l).group(1) for l in rows}
print(f"{len(rows)} recommendation rows, {len(bad)} uncited")
for l in bad:
    print("  uncited:", l)
sys.exit(1 if bad or not rows else 0)
