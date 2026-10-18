#import <UIKit/UIKit.h>
// The decks as stacks of index cards on the oak desk, two to a row, grouped under letterpressed folder names.
@interface CDDecksViewController : UIViewController { UIScrollView *scroll; NSMutableArray *items, *targets; NSTimer *poll; int ticks; }
@end
// The desk: an index card off the stack, turned over with a tap, stamped Again / Hard / Good / Easy and tossed aside.
@interface CDStudyViewController : UIViewController <UIWebViewDelegate, UIGestureRecognizerDelegate> {
    NSString *deck; NSInteger current; BOOL revealed, busy, revealOnLoad; int answerOnLoad, slams; NSDate *shownAt; NSTimer *waitTimer;
    UIImageView *tab, *peek[3]; CGAffineTransform peekAt[3]; UIView *host, *front, *back; UIWebView *frontWeb, *backWeb; NSMutableArray *stamps, *intervals; UILabel *hint;
}
- (id)initWithDeck:(NSString *)d;   // nil studies every deck
@end
// Stats: a date-due slip in its manila pocket.
@interface CDStatsViewController : UIViewController
@end
