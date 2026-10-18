// Replays "card t offset rating id" lines through CDFSRS and prints each card's state after every answer,
// plus the four previews before it, for tests/crosscheck.py to compare with tools/cards.
#include "../src/CDFSRS.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
int main(int argc, char **argv) {
    static CDCard cards[4096]; int i, o, r; long long t; char id[64]; double ret = argc > 1 ? atof(argv[1]) : 0.9;
    memset(cards, 0, sizeof cards);
    while (scanf("%d %lld %d %d %63s", &i, &t, &o, &r, id) == 5) {
        CDCard *c = &cards[i]; long long pv[4]; int pd[4];
        for (int k = 0; k < 4; k++) pv[k] = CDPreview(c, t, o, k + 1, ret, &pd[k]);
        int prev = CDAnswer(c, t, o, r, ret, CDSeed(id));
        printf("%d %d %d %d %d %d %.12g %.12g %lld %ld %ld", prev, c->state, c->step, c->reps, c->lapses, 0, c->s, c->d, c->dueT, c->dueDay, c->lastDay);
        for (int k = 0; k < 4; k++) printf(" %lld%c", pv[k], pd[k] ? 'd' : 's');
        printf("\n");
    }
    return 0;
}
