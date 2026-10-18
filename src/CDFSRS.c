#include "CDFSRS.h"
#include <math.h>
#include <stdint.h>

static const double W[19] = { 0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192, 1.01925,
                              1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621 };   // the FSRS-5 defaults
static const double DECAY = -0.5, FACTOR = 19.0 / 81.0;
static const int LEARN[] = { 60, 600 }, NLEARN = 2, RELEARN[] = { 600 }, NRELEARN = 1;
#define MAX_IVL 36500
#define ROLLOVER (4 * 3600)

long CDDay(long long t, int offset) { long long x = t + offset - ROLLOVER; return (long)(x >= 0 ? x / 86400 : -((-x + 86399) / 86400)); }
static double initD(int r) { return W[4] - exp(W[5] * (r - 1)) + 1; }
static double clampD(double d) { return fmin(fmax(d, 1.0), 10.0); }
static double nextD(double d, int r) { double d2 = d + (-W[6] * (r - 3)) * (10.0 - d) / 9.0; return clampD(W[7] * initD(4) + (1 - W[7]) * d2); }
static double retr(long elapsed, double s) { return pow(1 + FACTOR * elapsed / s, DECAY); }
static double recallS(double d, double s, double R, int r) {
    return s * (1 + exp(W[8]) * (11 - d) * pow(s, -W[9]) * (exp((1 - R) * W[10]) - 1) * (r == 2 ? W[15] : 1) * (r == 4 ? W[16] : 1));
}
static double forgetS(double d, double s, double R) { return fmin(W[11] * pow(d, -W[12]) * (pow(s + 1, W[13]) - 1) * exp((1 - R) * W[14]), s / exp(W[17] * W[18])); }
static int interval(double s, double retention) { double i = floor(s / FACTOR * (pow(retention, 1 / DECAY) - 1) + 0.5); return (int)fmin(fmax(i, 1), MAX_IVL); }
static int fuzz(int ivl, double seed) {
    if (ivl < 2.5 || seed < 0) return ivl;
    static const double ranges[3][3] = { { 2.5, 7.0, 0.15 }, { 7.0, 20.0, 0.1 }, { 20.0, 1e9, 0.05 } };
    double delta = 1.0; for (int k = 0; k < 3; k++) delta += ranges[k][2] * fmax(fmin(ivl, ranges[k][1]) - ranges[k][0], 0.0);
    int lo = (int)fmax(2, floor(ivl - delta + 0.5)), hi = (int)fmin(floor(ivl + delta + 0.5), MAX_IVL); if (lo > hi) lo = hi;
    int f = (int)floor(seed * (hi - lo + 1) + lo); return f < hi ? f : hi;
}
double CDSeed(const char *id) { uint32_t h = 2166136261u; for (const unsigned char *p = (const unsigned char *)id; *p; p++) h = (h ^ *p) * 16777619u; return h / 4294967296.0; }
double CDRetrievability(const CDCard *c, long today) { return c->state == CDNew ? 0 : retr(today - c->lastDay, c->s); }

int CDAnswer(CDCard *c, long long t, int offset, int r, double retention, double seed) {
    int prev = c->state; long today = CDDay(t, offset), elapsed = today - c->lastDay;
    if (c->state == CDNew) { c->s = W[r - 1]; c->d = clampD(initD(r)); c->state = CDLearning; c->step = 0; }
    else if (elapsed < 1) { c->s = c->s * exp(W[17] * (r - 3 + W[18])); c->d = nextD(c->d, r); }
    else { double R = retr(elapsed, c->s); c->s = r == 1 ? forgetS(c->d, c->s, R) : recallS(c->d, c->s, R, r); c->d = nextD(c->d, r); }
    c->s = fmax(c->s, 0.01);
    int secs = -1;   // a learning step, or -1 for a whole-day interval
    if (c->state == CDLearning || c->state == CDRelearning) {
        const int *steps = c->state == CDLearning ? LEARN : RELEARN; int n = c->state == CDLearning ? NLEARN : NRELEARN;
        if (r == 1) { c->step = 0; secs = steps[0]; }
        else if (r == 2) secs = c->step == 0 ? (n == 1 ? (int)(steps[0] * 1.5) : (steps[0] + steps[1]) / 2) : steps[c->step < n - 1 ? c->step : n - 1];
        else if (r == 3 && c->step + 1 < n) { c->step++; secs = steps[c->step]; }
    } else if (r == 1) { c->lapses++; c->state = CDRelearning; c->step = 0; secs = RELEARN[0]; }
    if (secs < 0) { c->state = CDReview; c->step = 0; c->dueDay = today + fuzz(interval(c->s, retention), seed); c->dueT = 0; }
    else c->dueT = t + secs;
    c->reps++; c->lastDay = today; c->lastT = t;
    return prev;
}

long long CDPreview(const CDCard *c, long long t, int offset, int r, double retention, int *isDays) {
    CDCard x = *c; CDAnswer(&x, t, offset, r, retention, -1);
    *isDays = x.state == CDReview; return *isDays ? x.dueDay - CDDay(t, offset) : x.dueT - t;
}
