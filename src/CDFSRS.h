// FSRS-5 scheduling with Anki-style learning steps. Plain C so the Mac test harness can build it too.
// Mirrors the FSRS section of tools/cards line for line; tests/crosscheck.py holds the two to the same numbers.
enum { CDNew = 0, CDLearning, CDReview, CDRelearning };
typedef struct { int state, step, reps, lapses; double s, d; long long lastT, dueT; long lastDay, dueDay; } CDCard;
long CDDay(long long t, int offset);                 // days since 1970 in local time, turning over at 4 am
int CDAnswer(CDCard *c, long long t, int offset, int rating, double retention, double seed);   // rating 1 Again .. 4 Easy; returns the state before; seed < 0 skips the fuzz
long long CDPreview(const CDCard *c, long long t, int offset, int rating, double retention, int *isDays);   // the interval this rating would give: seconds, or days when *isDays
double CDSeed(const char *reviewId);                 // FNV-1a of the id as a fraction, so a replay fuzzes the same way every time
double CDRetrievability(const CDCard *c, long today);
