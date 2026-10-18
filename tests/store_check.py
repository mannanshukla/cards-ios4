#!/usr/bin/env python3
"""A month of made-up answers (with undos, a duplicate line and a torn last line) replayed by the app's CDStore
built for the Mac and by tools/cards; card schedules and deck counts must match.

  python3 tests/store_check.py <store_check binary>
"""
import json, os, random, subprocess, sys, tempfile, time
from importlib.machinery import SourceFileLoader

here = os.path.dirname(os.path.abspath(__file__))
cards = SourceFileLoader("cards", os.path.join(here, "..", "tools", "cards")).load_module()
rng = random.Random(11)
decks, cs, _ = cards.load_cards(os.path.join(here, "fixtures"))
now = int(time.time()); off = time.localtime(now).tm_gmtoff
entries, sim = {}, [cards.Card() for _ in cs]
t = now - 86400 * 30
while t < now - 60:
    i = rng.randrange(len(cs))
    r = rng.choices([1, 2, 3, 4], [15, 10, 60, 15])[0]
    e = {"id": "%032x" % rng.getrandbits(128), "c": cs[i]["id"], "t": t, "o": off, "r": r, "ms": rng.randrange(1000, 9000)}
    entries[e["id"]] = e
    if rng.random() < 0.05:
        u = {"id": "%032x" % rng.getrandbits(128), "u": e["id"], "t": t + 5, "o": off}
        entries[u["id"]] = u
    t += rng.choice([20, 60, 600, 3600, 3600 * 5])
for k in range(6):   # and a few in the last minutes, so today's numbers are tested whatever the hour
    e = {"id": "%032x" % rng.getrandbits(128), "c": cs[rng.randrange(len(cs))]["id"], "t": now - 240 + k * 30, "o": off, "r": rng.choice([1, 2, 3, 4]), "ms": 4000}
    entries[e["id"]] = e
entries["orphan"] = {"id": "orphan", "c": "deadbeef0000", "t": now - 100, "o": off, "r": 3}   # a card that was deleted
d = tempfile.mkdtemp()
with open(os.path.join(d, "cards.json"), "w") as f:
    json.dump({"format": 1, "synced": now, "from": "test", "decks": decks, "cards": cs}, f, ensure_ascii=False)
lines = [cards.log_line(e) for e in entries.values()]
rng.shuffle(lines)
with open(os.path.join(d, "reviews.jsonl"), "w") as f:
    f.write("\n".join(lines + [lines[0]]) + "\n" + '{"id":"torn","c":"%s","t":' % cs[0]["id"])
states, info = cards.replay(cs, entries, cards.DEFAULTS, now)
out = subprocess.run([sys.argv[1]], env=dict(os.environ, CARDS_DOCS=d), stdout=subprocess.PIPE, universal_newlines=True, check=True).stdout.splitlines()
bad = 0
got = dict((l.split()[1], l.split()[2:]) for l in out if l.startswith("card "))
for c, s in zip(cs, states):
    g = got[c["id"]]
    ok = [int(g[0]), int(g[1])] == [s.state, s.reps] and abs(float(g[2]) - s.s) <= 1e-9 * max(1, s.s) and abs(float(g[3]) - s.d) <= 1e-9 and [int(g[4]), int(g[5])] == [s.due_t, s.due_day]
    bad += not ok
    if not ok and bad < 4:
        print("card %s differs: app %s, python %s" % (c["id"], g, [s.state, s.reps, s.s, s.d, s.due_t, s.due_day]))
for l in out:
    if l.startswith("deck "):
        name, nums = l[5:].split("|")
        want = cards.deck_counts(cs, states, info, cards.DEFAULTS, name)
        if tuple(int(x) for x in nums.split()) != want:
            bad += 1; print("deck %s: app %s, python %s" % (name, nums, want))
        else:
            print("  %-12s new %d, learning %d, due %d (both)" % ((name,) + want))
ch = cards.chart_data(cs, states, info)
want = [n for d in ch["answers"] for n in d] + ch["forecast"] + [n for w in ch["weeks"] for n in w] + [ch["states"][k] for k in ("new", "learning", "young", "mature")] + \
       [ch["today"]["answers"], ch["today"]["new"], ch["today"]["minutes"], ch["streak"], ch["retention"], ch["reviews30"]]
got = [int(x) for x in [l for l in out if l.startswith("charts ")][0].split()[1:]]
if got != want:
    bad += 1; print("Stats charts differ:\n  app    %s\n  python %s" % (got, want))
else:
    print("  Stats charts: %d numbers agree (30 days by rating, 30-day forecast, 12 weeks, states, today)" % len(want))
today = [l for l in out if l.startswith("today ")][0].split()[1]
print("%d answers in the log (%d undone), %d answered today; %s" % (len(entries), len([e for e in entries.values() if "u" in e]), info["reviews"],
      "app and tools/cards agree on all %d cards" % len(cs) if not bad and int(today) == info["reviews"] else "%d differences, today %s vs %d" % (bad, today, info["reviews"])))
sys.exit(1 if bad or int(today) != info["reviews"] else 0)
