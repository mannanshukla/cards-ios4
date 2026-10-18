#import <Foundation/Foundation.h>
#import "CDFSRS.h"
// The cards (cards.json, written by `cards sync` on the Mac) and the review log (reviews.jsonl, appended here).
// Schedules are never saved: they are rebuilt by replaying the log through CDFSRS, so the log is the one source of truth.
extern NSString *const CDStoreChanged;
typedef struct { NSInteger fresh, learning, due; long nextDay, today; } CDCounts;   // nextDay: the next day a review falls due, -1 if none
typedef struct { char rid[40], cid[24], undo[40]; long long t; int o, r, ms, card; } CDEntry;
@interface CDStore : NSObject {
    NSArray *cards, *decks; NSDate *synced; NSString *from;
    CDCard *state; int *deckOf, *noteOf; BOOL *buried; int *newToday, *revToday;
    CDEntry *log; NSInteger nlog, caplog;
    double cardsStamp, logStamp; long long logSize;
    NSMutableArray *mine;   // ids of the answers given since launch, newest last, for Undo
    long today; int todayAnswers, todayMs, retTotal, retPass; NSMutableIndexSet *studyDays; NSMutableDictionary *dayAnswers;
    int recent[30][4], weekPass[12], weekTotal[12];   // the last 30 days' answers by rating; reviews remembered and made, by weeks back
    double retention; NSInteger newLimit, revLimit;
}
+ (CDStore *)shared;
- (BOOL)reloadIfChanged;   // re-reads the files if a sync changed them, the settings, or the day; posts CDStoreChanged
- (NSArray *)decks; - (NSUInteger)cardCount; - (NSUInteger)cardsInDeck:(NSString *)deck; - (NSDate *)syncedAt; - (NSString *)syncedFrom;
- (CDCounts)countsForDeck:(NSString *)deck;   // nil means every deck
- (NSInteger)nextCardInDeck:(NSString *)deck wait:(long long *)wait;   // -1 when nothing is due; *wait is then the seconds until a learning card returns, or -1
- (NSDictionary *)card:(NSInteger)i;
- (NSString *)intervalForCard:(NSInteger)i rating:(int)r;
- (int)kindOfCard:(NSInteger)i;   // CDNew, CDLearning, CDReview or CDRelearning
- (void)answerCard:(NSInteger)i rating:(int)r ms:(int)ms;
- (BOOL)canUndo;
- (NSInteger)undo;   // takes back the last answer; returns its card
- (NSInteger)answersToday;
- (NSDictionary *)statsSummary;   // what Stats draws; the same numbers as `cards stats --json`
@end
