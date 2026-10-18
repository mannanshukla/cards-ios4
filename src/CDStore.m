#import "CDStore.h"
#import "ORJSON.h"
#import <objc/message.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

NSString *const CDStoreChanged = @"CDStoreChanged";

static NSString *docs(NSString *name) { return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:name]; }
static long long now(void) { return (long long)time(NULL); }
static int offsetNow(void) { return (int)[[NSTimeZone localTimeZone] secondsFromGMTForDate:[NSDate date]]; }
static double stamp(NSString *path, long long *size) { struct stat st; if (stat([path fileSystemRepresentation], &st)) { if (size) *size = -1; return 0; } if (size) *size = st.st_size; return st.st_mtimespec.tv_sec + st.st_mtimespec.tv_nsec / 1e9; }
static NSString *uuid(void) { CFUUIDRef u = CFUUIDCreate(NULL); NSString *s = [(NSString *)CFUUIDCreateString(NULL, u) autorelease]; CFRelease(u); return [s lowercaseString]; }
static id parseJSON(NSData *d) {
    Class j = NSClassFromString(@"NSJSONSerialization");   // iOS 5 has it and it is far quicker; the 4.3 SDK predates it
    if (j) { id (*msg)(id, SEL, NSData *, NSUInteger, NSError **) = (void *)objc_msgSend; return msg(j, @selector(JSONObjectWithData:options:error:), d, 0, NULL); }
    return [ORJSON parse:[[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] autorelease]];
}

#pragma mark - reviews.jsonl
// One flat object per line. Read by hand: ORJSON builds a string per character, too slow on an A4 for a year of answers.
static const char *skipWS(const char *p) { while (*p == ' ' || *p == '\t') p++; return p; }
static const char *readString(const char *p, char *out, size_t n) {
    size_t k = 0; p++;
    while (*p && *p != '"') { if (*p == '\\' && p[1]) p++; if (k + 1 < n) out[k++] = *p; p++; }
    out[k] = 0; return *p == '"' ? p + 1 : NULL;
}
static BOOL parseLine(const char *p, CDEntry *e) {
    memset(e, 0, sizeof *e); e->card = -1;
    p = skipWS(p); if (*p != '{') return NO; p++;
    for (;;) {
        p = skipWS(p); if (*p == '}') break; if (*p != '"') return NO;
        char key[16], val[64]; if (!(p = readString(p, key, sizeof key))) return NO;
        p = skipWS(p); if (*p != ':') return NO; p = skipWS(p + 1);
        if (*p == '"') {
            if (!(p = readString(p, val, sizeof val))) return NO;
            if (!strcmp(key, "id")) strlcpy(e->rid, val, sizeof e->rid); else if (!strcmp(key, "c")) strlcpy(e->cid, val, sizeof e->cid); else if (!strcmp(key, "u")) strlcpy(e->undo, val, sizeof e->undo);
        } else {
            char *end; double v = strtod(p, &end);
            if (end == p) { while (*p && *p != ',' && *p != '}') p++; continue; }   // true, false, null
            p = end;
            if (!strcmp(key, "t")) e->t = (long long)v; else if (!strcmp(key, "o")) e->o = (int)v; else if (!strcmp(key, "r")) e->r = (int)v; else if (!strcmp(key, "ms")) e->ms = (int)v;
        }
        p = skipWS(p); if (*p == ',') p++; else if (*p != '}') return NO;
    }
    return e->rid[0] != 0;
}
static int byTime(const void *a, const void *b) { const CDEntry *x = a, *y = b; if (x->t != y->t) return x->t < y->t ? -1 : 1; return strcmp(x->rid, y->rid); }

@implementation CDStore
+ (CDStore *)shared { static CDStore *s = nil; if (!s) { s = [[CDStore alloc] init]; [s reloadIfChanged]; } return s; }
- (id)init { if ((self = [super init])) { cards = [[NSArray alloc] init]; decks = [[NSArray alloc] init]; mine = [[NSMutableArray alloc] init]; studyDays = [[NSMutableIndexSet alloc] init]; dayAnswers = [[NSMutableDictionary alloc] init]; today = -1; cardsStamp = logStamp = -1; } return self; }

- (void)loadCards {
    NSData *d = [NSData dataWithContentsOfFile:docs(@"cards.json")]; id j = d ? parseJSON(d) : nil;
    NSArray *c = [j isKindOfClass:[NSDictionary class]] ? [j objectForKey:@"cards"] : nil, *dk = [j isKindOfClass:[NSDictionary class]] ? [j objectForKey:@"decks"] : nil;
    if (d && ![c isKindOfClass:[NSArray class]]) return;   // half-written or broken: keep what we had
    [cards release]; cards = [(c ?: [NSArray array]) retain];
    [decks release]; decks = [([dk isKindOfClass:[NSArray class]] ? dk : [NSArray array]) retain];
    [synced release]; synced = [j objectForKey:@"synced"] ? [[NSDate alloc] initWithTimeIntervalSince1970:[[j objectForKey:@"synced"] doubleValue]] : nil;
    [from release]; from = [[j objectForKey:@"from"] copy];
    NSInteger n = [cards count]; NSMutableDictionary *ids = [NSMutableDictionary dictionaryWithCapacity:n];
    free(deckOf); free(noteOf); deckOf = calloc(n + 1, sizeof(int)); noteOf = calloc(n + 1, sizeof(int));
    for (NSInteger i = 0; i < n; i++) [ids setObject:[NSNumber numberWithInteger:i] forKey:[[cards objectAtIndex:i] objectForKey:@"id"]];
    for (NSInteger i = 0; i < n; i++) {
        NSDictionary *c = [cards objectAtIndex:i]; NSUInteger k = [decks indexOfObject:[c objectForKey:@"deck"]]; deckOf[i] = k == NSNotFound ? 0 : (int)k;
        NSNumber *note = [ids objectForKey:[c objectForKey:@"note"] ?: @""]; noteOf[i] = note ? [note intValue] : (int)i;
    }
    for (NSInteger k = 0; k < nlog; k++) { NSNumber *i = log[k].cid[0] ? [ids objectForKey:[NSString stringWithUTF8String:log[k].cid]] : nil; log[k].card = i ? [i intValue] : -1; }
}
- (void)push:(CDEntry *)e { if (nlog == caplog) { caplog = caplog ? caplog * 2 : 1024; log = realloc(log, caplog * sizeof(CDEntry)); } log[nlog++] = *e; }
- (void)loadLog {
    NSData *d = [NSData dataWithContentsOfFile:docs(@"reviews.jsonl")]; nlog = 0;
    NSMutableDictionary *ids = [NSMutableDictionary dictionaryWithCapacity:[cards count]];
    for (NSUInteger i = 0; i < [cards count]; i++) [ids setObject:[NSNumber numberWithInteger:i] forKey:[[cards objectAtIndex:i] objectForKey:@"id"]];
    const char *p = [d bytes], *end = p + [d length]; char line[512];
    while (p && p < end) {
        const char *nl = memchr(p, '\n', end - p); size_t len = (nl ? nl : end) - p;
        if (len && len < sizeof line) {
            memcpy(line, p, len); line[len] = 0; CDEntry e;
            if (parseLine(line, &e)) { NSNumber *i = e.cid[0] ? [ids objectForKey:[NSString stringWithUTF8String:e.cid]] : nil; e.card = i ? [i intValue] : -1; [self push:&e]; }
        }
        p = nl ? nl + 1 : end;
    }
}
- (void)readSettings {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    newLimit = [u integerForKey:@"cd_new_per_day"]; revLimit = [u integerForKey:@"cd_max_reviews"]; retention = [u doubleForKey:@"cd_retention"];
    if (retention < 0.7 || retention > 0.99) retention = 0.9;
}

- (void)apply:(CDEntry *)e {
    int prev = CDAnswer(&state[e->card], e->t, e->o, e->r, retention, CDSeed(e->rid)); long d = CDDay(e->t, e->o);
    if (d > 0) { [studyDays addIndex:d]; NSNumber *k = [NSNumber numberWithLong:d]; [dayAnswers setObject:[NSNumber numberWithInt:[[dayAnswers objectForKey:k] intValue] + 1] forKey:k]; }
    if (prev == CDReview && d > today - 30) { retTotal++; if (e->r > 1) retPass++; }
    if (d == today) { todayAnswers++; todayMs += e->ms; buried[noteOf[e->card]] = YES; if (prev == CDNew) newToday[deckOf[e->card]]++; else if (prev == CDReview) revToday[deckOf[e->card]]++; }
}
- (void)replay {
    NSInteger n = [cards count], nd = [decks count];
    free(state); free(buried); free(newToday); free(revToday);
    state = calloc(n + 1, sizeof(CDCard)); buried = calloc(n + 1, sizeof(BOOL)); newToday = calloc(nd + 1, sizeof(int)); revToday = calloc(nd + 1, sizeof(int));
    todayAnswers = todayMs = retTotal = retPass = 0; [studyDays removeAllIndexes]; [dayAnswers removeAllObjects];
    today = CDDay(now(), offsetNow());
    qsort(log, nlog, sizeof(CDEntry), byTime);
    NSMutableSet *undone = nil;
    for (NSInteger k = 0; k < nlog; k++) if (log[k].undo[0]) { if (!undone) undone = [NSMutableSet set]; [undone addObject:[NSString stringWithUTF8String:log[k].undo]]; }
    for (NSInteger k = 0; k < nlog; k++) {
        CDEntry *e = &log[k];
        if ((k && !strcmp(e->rid, log[k - 1].rid)) || e->undo[0] || e->card < 0 || e->card >= n || e->r < 1 || e->r > 4) continue;
        if (undone && [undone containsObject:[NSString stringWithUTF8String:e->rid]]) continue;
        [self apply:e];
    }
}
- (BOOL)reloadIfChanged {
    BOOL changed = NO; long long size;
    double cs = stamp(docs(@"cards.json"), NULL); if (cs != cardsStamp) { cardsStamp = cs; [self loadCards]; changed = YES; }
    double ls = stamp(docs(@"reviews.jsonl"), &size); if (changed || ls != logStamp || size != logSize) { logStamp = ls; logSize = size; [self loadLog]; changed = YES; }
    NSInteger oldNew = newLimit, oldRev = revLimit; double oldRet = retention; [self readSettings];
    if (oldNew != newLimit || oldRev != revLimit || oldRet != retention) changed = YES;
    if (CDDay(now(), offsetNow()) != today) changed = YES;
    if (changed) { [self replay]; [[NSNotificationCenter defaultCenter] postNotificationName:CDStoreChanged object:self]; }
    return changed;
}
- (void)rollover { if (CDDay(now(), offsetNow()) != today) [self reloadIfChanged]; }

- (NSArray *)decks { return decks; }
- (NSUInteger)cardCount { return [cards count]; }
- (NSUInteger)cardsInDeck:(NSString *)deck { NSUInteger k = [decks indexOfObject:deck], n = 0; for (NSUInteger i = 0; i < [cards count]; i++) if (deckOf[i] == (int)k) n++; return n; }
- (NSDate *)syncedAt { return synced; }
- (NSString *)syncedFrom { return from; }
- (NSDictionary *)card:(NSInteger)i { return [cards objectAtIndex:i]; }
- (NSInteger)answersToday { return todayAnswers; }
- (int)kindOfCard:(NSInteger)i { return state[i].state; }

- (CDCounts)countsForDeck:(NSString *)deck {
    [self rollover];
    CDCounts r = { 0, 0, 0, -1, today }; NSInteger nd = [decks count], dk = deck ? (NSInteger)[decks indexOfObject:deck] : -1;
    if (deck && dk == NSNotFound) return r;
    int *fresh = calloc(nd + 1, sizeof(int)), *due = calloc(nd + 1, sizeof(int));
    long long end = (long long)(today + 1) * 86400 + 4 * 3600 - offsetNow();   // the next 4 am
    for (NSUInteger i = 0; i < [cards count]; i++) {
        if (dk >= 0 && deckOf[i] != dk) continue;
        CDCard *c = &state[i];
        if (c->state == CDLearning || c->state == CDRelearning) { if (c->dueT < end) r.learning++; continue; }
        if (c->state == CDReview && c->dueDay > today && (r.nextDay < 0 || c->dueDay < r.nextDay)) r.nextDay = c->dueDay;
        if (buried[noteOf[i]]) continue;   // its other side was answered today; it waits for tomorrow
        if (c->state == CDNew) fresh[deckOf[i]]++; else if (c->dueDay <= today) due[deckOf[i]]++;
    }
    for (NSInteger k = 0; k < nd; k++) {
        if (dk >= 0 && k != dk) continue;
        r.fresh += MAX(0, MIN(fresh[k], newLimit - newToday[k])); r.due += MAX(0, MIN(due[k], revLimit - revToday[k]));
    }
    free(fresh); free(due); return r;
}
- (NSInteger)nextCardInDeck:(NSString *)deck wait:(long long *)wait {
    [self rollover]; *wait = -1;
    NSInteger dk = deck ? (NSInteger)[decks indexOfObject:deck] : -1, n = [cards count]; if (deck && dk == NSNotFound) return -1;
    long long t = now(), bt = 0, at = 0; NSInteger best = -1, ahead = -1;
    for (NSInteger i = 0; i < n; i++) {   // learning cards whose minutes are up come first
        CDCard *c = &state[i]; if ((dk >= 0 && deckOf[i] != dk) || (c->state != CDLearning && c->state != CDRelearning)) continue;
        if (c->dueT <= t) { if (best < 0 || c->dueT < bt) { best = i; bt = c->dueT; } }
        else if (ahead < 0 || c->dueT < at) { ahead = i; at = c->dueT; }
    }
    if (best >= 0) return best;
    long bd = 0; NSUInteger bh = 0;
    for (NSInteger i = 0; i < n; i++) {   // then reviews, oldest due first, in a shuffled but steady order
        CDCard *c = &state[i]; if ((dk >= 0 && deckOf[i] != dk) || c->state != CDReview || c->dueDay > today || buried[noteOf[i]] || revToday[deckOf[i]] >= revLimit) continue;
        NSUInteger h = [[[cards objectAtIndex:i] objectForKey:@"id"] hash];
        if (best < 0 || c->dueDay < bd || (c->dueDay == bd && h < bh)) { best = i; bd = c->dueDay; bh = h; }
    }
    if (best >= 0) return best;
    for (NSInteger i = 0; i < n; i++)   // then new cards in the order they're written
        if ((dk < 0 || deckOf[i] == dk) && state[i].state == CDNew && !buried[noteOf[i]] && newToday[deckOf[i]] < newLimit) return i;
    if (ahead >= 0 && at - t <= 20 * 60) return ahead;   // nothing else to do: a learning card a little early beats waiting
    if (ahead >= 0) *wait = at - t;
    return -1;
}
- (NSString *)intervalForCard:(NSInteger)i rating:(int)r {
    int days; long long v = CDPreview(&state[i], now(), offsetNow(), r, retention, &days);
    if (!days) return v < 60 ? @"<1m" : v < 3600 ? [NSString stringWithFormat:@"%lldm", (v + 30) / 60] : [NSString stringWithFormat:@"%lldh", (v + 1800) / 3600];
    return v < 30 ? [NSString stringWithFormat:@"%lldd", v] : v < 365 ? [NSString stringWithFormat:@"%.1fmo", v / 30.0] : [NSString stringWithFormat:@"%.1fy", v / 365.0];
}

- (void)appendLine:(NSString *)line {
    NSString *path = docs(@"reviews.jsonl"); const char *s = [line UTF8String];
    long long before; double st = stamp(path, &before); BOOL outside = st != logStamp || before != logSize;   // a sync got there first
    int fd = open([path fileSystemRepresentation], O_WRONLY | O_APPEND | O_CREAT, 0644); if (fd < 0) return;
    write(fd, s, strlen(s)); fsync(fd); close(fd);
    if (!outside) logStamp = stamp(path, &logSize);
}
- (void)answerCard:(NSInteger)i rating:(int)r ms:(int)ms {
    CDEntry e; memset(&e, 0, sizeof e); NSString *u = uuid();
    strlcpy(e.rid, [u UTF8String], sizeof e.rid); strlcpy(e.cid, [[[cards objectAtIndex:i] objectForKey:@"id"] UTF8String], sizeof e.cid);
    e.t = now(); e.o = offsetNow(); e.r = r; e.ms = ms; e.card = (int)i;
    [self appendLine:[NSString stringWithFormat:@"{\"id\":\"%s\",\"c\":\"%s\",\"t\":%lld,\"o\":%d,\"r\":%d,\"ms\":%d}\n", e.rid, e.cid, e.t, e.o, e.r, e.ms]];
    [self push:&e]; [self apply:&log[nlog - 1]]; [mine addObject:u];
}
- (BOOL)canUndo { return [mine count] > 0; }
- (NSInteger)undo {
    NSString *u = [mine lastObject]; if (!u) return -1; NSInteger card = -1;
    for (NSInteger k = nlog - 1; k >= 0; k--) if (!strcmp(log[k].rid, [u UTF8String])) { card = log[k].card; break; }
    CDEntry e; memset(&e, 0, sizeof e); e.card = -1; strlcpy(e.rid, [uuid() UTF8String], sizeof e.rid); strlcpy(e.undo, [u UTF8String], sizeof e.undo); e.t = now(); e.o = offsetNow();
    [self appendLine:[NSString stringWithFormat:@"{\"id\":\"%s\",\"u\":\"%s\",\"t\":%lld,\"o\":%d}\n", e.rid, e.undo, e.t, e.o]];
    [self push:&e]; [mine removeLastObject]; [self replay];
    return card;
}

- (NSString *)stampForDay:(long)d {   // the date a library stamp would print: OCT 18 2026
    static NSDateFormatter *f = nil; if (!f) { f = [[NSDateFormatter alloc] init]; [f setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]]; [f setDateFormat:@"MMM d yyyy"]; }
    return [[f stringFromDate:[NSDate dateWithTimeIntervalSince1970:(double)d * 86400 + 4 * 3600 - offsetNow() + 12 * 3600]] uppercaseString];
}
- (NSDictionary *)statsSummary {
    [self rollover];
    int by[4] = { 0 }, mature = 0, next[8] = { 0 };
    for (NSUInteger i = 0; i < [cards count]; i++) {
        CDCard *c = &state[i]; by[c->state]++;
        if (c->state != CDReview) continue;
        if (c->dueDay - c->lastDay >= 21) mature++;
        if (c->dueDay > today && c->dueDay <= today + 7) next[c->dueDay - today]++;
    }
    int streak = 0; for (long d = [studyDays containsIndex:today] ? today : today - 1; d > 0 && [studyDays containsIndex:d]; d--) streak++;
    NSMutableArray *past = [NSMutableArray array], *coming = [NSMutableArray array];
    for (NSUInteger d = [studyDays lastIndex]; d != NSNotFound && [past count] < 6; d = [studyDays indexLessThanIndex:d])
        [past insertObject:[NSArray arrayWithObjects:[self stampForDay:(long)d], [dayAnswers objectForKey:[NSNumber numberWithLong:(long)d]], nil] atIndex:0];
    for (int k = 1; k <= 7; k++) [coming addObject:[NSArray arrayWithObjects:[self stampForDay:today + k], [NSNumber numberWithInt:next[k]], nil]];
    NSNumber *(^num)(int) = ^(int v) { return [NSNumber numberWithInt:v]; };
    return [NSDictionary dictionaryWithObjectsAndKeys:past, @"past", coming, @"coming", num(todayAnswers), @"answersToday", num((int)[self sum:newToday]), @"newToday",
            num((todayMs + 30000) / 60000), @"minutesToday", num(streak), @"streak", num(retTotal ? (int)(100.0 * retPass / retTotal + 0.5) : -1), @"retention", num(retTotal), @"reviews30",
            num((int)(retention * 100 + 0.5)), @"target", num(by[CDNew]), @"cardsNew", num(by[CDLearning] + by[CDRelearning]), @"cardsLearning", num(by[CDReview] - mature), @"cardsYoung", num(mature), @"cardsMature", nil];
}
- (NSInteger)sum:(int *)a { NSInteger s = 0; for (NSUInteger k = 0; k < [decks count]; k++) s += a[k]; return s; }
@end
