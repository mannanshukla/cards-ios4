# Holds tools/cards to the reference py-fsrs (pip install "fsrs>=5,<6") with fuzz off and reviews on time.
# The app's day rollover means the two only line up when every review lands on its due time, which this arranges.
import os, random, sys
from datetime import datetime, timezone, timedelta
from importlib.machinery import SourceFileLoader
import fsrs
cards = SourceFileLoader("cards", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools", "cards")).load_module()
sch = fsrs.Scheduler(enable_fuzzing=False)
rng = random.Random(3); n = bad = 0; maxds = maxdd = 0
for h in range(3000):
    ref = fsrs.Card(); mine = cards.Card()
    t = datetime(2026, 10, 1, 12, 0, tzinfo=timezone.utc) + timedelta(days=rng.randrange(60))
    for k in range(rng.randrange(1, 20)):
        r = rng.choices([1, 2, 3, 4], [15, 10, 60, 15])[0]
        ref, _ = sch.review_card(ref, fsrs.Rating(r), t)
        cards.answer(mine, int(t.timestamp()), 0, r, 0.9, -1)
        n += 1
        ds, dd = abs(ref.stability - mine.s) / ref.stability, abs(ref.difficulty - mine.d)
        maxds, maxdd = max(maxds, ds), max(maxdd, dd)
        mine_due = (datetime.fromtimestamp(mine.due_t, timezone.utc) if mine.state != cards.REVIEW else t + timedelta(days=mine.due_day - mine.last_day))
        if ds > 1e-9 or dd > 1e-9 or int(ref.state) != {1: 1, 2: 2, 3: 3}[mine.state] or ref.due != mine_due:
            bad += 1
            if bad < 4: print("diff", h, k, r, ref.state, mine.state, ref.stability, mine.s, ref.difficulty, mine.d, ref.due, mine_due)
        t = ref.due + (timedelta(days=rng.choice([0, 0, 2, 9])) if ref.state == fsrs.State.Review else timedelta(0))
print("%d answers vs py-fsrs %s: %d differ; max rel stability diff %.2g, max difficulty diff %.2g" % (n, fsrs.__version__ if hasattr(fsrs, '__version__') else '5.1.3', bad, maxds, maxdd))
