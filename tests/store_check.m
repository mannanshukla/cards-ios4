// Builds the app's CDStore for the Mac against a folder named by $CARDS_DOCS and prints every card's schedule
// and every deck's counts, for tests/store_check.py to compare with tools/cards' replay.
#import <Foundation/Foundation.h>
#define NSSearchPathForDirectoriesInDomains(a, b, c) [NSArray arrayWithObject:[[[NSProcessInfo processInfo] environment] objectForKey:@"CARDS_DOCS"]]
#import "../src/CDStore.m"
#import "../src/ORJSON.m"
@interface CDStore (Test)
- (CDCard *)stateAt:(NSUInteger)i;
@end
@implementation CDStore (Test)
- (CDCard *)stateAt:(NSUInteger)i { return &state[i]; }
@end
int main(void) {
    NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init];
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:20], @"cd_new_per_day", [NSNumber numberWithInt:200], @"cd_max_reviews", [NSNumber numberWithDouble:0.9], @"cd_retention", nil]];
    CDStore *s = [CDStore shared];
    for (NSUInteger i = 0; i < [s cardCount]; i++) { CDCard *c = [s stateAt:i]; printf("card %s %d %d %.12g %.12g %lld %ld\n", [[[s card:i] objectForKey:@"id"] UTF8String], c->state, c->reps, c->s, c->d, c->dueT, c->dueDay); }
    for (NSString *d in [s decks]) { CDCounts n = [s countsForDeck:d]; printf("deck %s|%ld %ld %ld\n", [d UTF8String], (long)n.fresh, (long)n.learning, (long)n.due); }
    long long w; NSInteger next = [s nextCardInDeck:nil wait:&w];
    printf("today %ld\nnext %s\n", (long)[s answersToday], next >= 0 ? [[[s card:next] objectForKey:@"id"] UTF8String] : "-");
    [p release]; return 0;
}
