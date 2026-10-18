#!/usr/bin/env python3
"""Random review histories through the app's C scheduler and tools/cards' Python one; every number must agree.

  python3 tests/crosscheck.py [harness binary] [histories]
"""
import os, random, subprocess, sys
from importlib.machinery import SourceFileLoader

here = os.path.dirname(os.path.abspath(__file__))
cards = SourceFileLoader("cards", os.path.join(here, "..", "tools", "cards")).load_module()
harness = sys.argv[1] if len(sys.argv) > 1 else "/tmp/fsrs_check"
n = int(sys.argv[2]) if len(sys.argv) > 2 else 2000

rng = random.Random(7)
lines, expect = [], []
for i in range(n):
    c, t = cards.Card(), 1760000000 + rng.randrange(0, 86400 * 30)
    o = rng.choice([-25200, -28800, 32400, 0, 19800])
    for k in range(rng.randrange(1, 25)):
        r = rng.choices([1, 2, 3, 4], [15, 10, 60, 15])[0]
        rid = "%08x-%04x" % (rng.getrandbits(32), k)
        pv = []
        for q in (1, 2, 3, 4):
            v, days = cards.preview(c, t, o, q, 0.9)
            pv.append("%d%s" % (v, "d" if days else "s"))
        prev = cards.answer(c, t, o, r, 0.9, cards.seed(rid))
        lines.append("%d %d %d %d %s" % (i, t, o, r, rid))
        expect.append(([prev, c.state, c.step, c.reps, c.lapses, 0], [c.s, c.d], [c.due_t, c.due_day, c.last_day], pv))
        # next answer: on time, early, late, or minutes later while learning
        if c.state == cards.REVIEW:
            due = (c.due_day + 1) * 86400 + cards.ROLLOVER - o - 3600
            t = due + rng.choice([0, 0, -86400 * rng.randrange(1, 3), 86400 * rng.randrange(1, 40), rng.randrange(0, 20000)])
            t = max(t, (c.last_day + 1) * 86400 + cards.ROLLOVER - o + 60) if rng.random() < 0.9 else t
        else:
            t = c.due_t + rng.choice([0, 30, 600, 3600 * 20, 86400 * 3])
        if rng.random() < 0.05:
            o = rng.choice([-25200, -28800])   # crossed a DST change or a time zone

out = subprocess.run([harness, "0.9"], input="\n".join(lines) + "\n", stdout=subprocess.PIPE, universal_newlines=True, check=True).stdout.split("\n")
bad = 0
for k, (want, got) in enumerate(zip(expect, out)):
    f = got.split()
    ints, floats, times, pv = [int(x) for x in f[:6]], [float(x) for x in f[6:8]], [int(x) for x in f[8:11]], f[11:15]
    ok = ints == want[0] and all(abs(a - b) <= 1e-9 * max(1, abs(b)) for a, b in zip(floats, want[1])) and times == want[2] and pv == want[3]
    if not ok:
        bad += 1
        if bad <= 5:
            print("mismatch at answer %d: %s\n  python: %s\n  C:      %s" % (k, lines[k], want, got))
reviews = [w for w in expect if w[0][1] == cards.REVIEW]
print("%d histories, %d answers compared: %s" % (n, len(expect), "all agree" if not bad else "%d differ" % bad))
print("  states seen: %s; longest interval %d days; lapses up to %d" % (
    sorted(set(w[0][1] for w in expect)), max(w[2][1] - w[2][2] for w in reviews), max(w[0][4] for w in expect)))
sys.exit(1 if bad or len(out) - 1 != len(expect) else 0)
