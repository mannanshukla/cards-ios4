#import <UIKit/UIKit.h>
UIColor *CDTint(void);
// Decks grouped by folder, with what's due in each.
@interface CDDecksViewController : UITableViewController { NSMutableArray *sections; NSTimer *poll; int ticks; }
@end
// One card at a time: the front, Show Answer, then Again / Hard / Good / Easy with the interval each would give.
@interface CDStudyViewController : UIViewController <UIWebViewDelegate, UIGestureRecognizerDelegate> {
    NSString *deck; NSInteger current; BOOL revealed, revealOnLoad; int answerOnLoad; NSDate *shownAt; NSTimer *waitTimer;
    UIWebView *web; UIButton *showButton; NSMutableArray *rateButtons, *rateIntervals; UILabel *newLabel, *learnLabel, *dueLabel;
}
- (id)initWithDeck:(NSString *)d;   // nil studies every deck
@end
@interface CDStatsViewController : UITableViewController { NSArray *sections; }
@end
