#import <UIKit/UIKit.h>
#import "CLCoachData.h"
@class ORTextLayout;
static inline UIColor *CLColor(unsigned rgb) { return [UIColor colorWithRed:((rgb>>16)&255)/255.0 green:((rgb>>8)&255)/255.0 blue:(rgb&255)/255.0 alpha:1]; }
void CLPaperTable(UITableView *table);
NSArray *CLCoachNotes(void);
NSString *CLCheckInSummary(NSString *source);
UIImage *CLCoachIcon(void);
@interface CLNoteViewController : UITableViewController { NSString *note; ORTextLayout *layout; }
- (id)initWithTitle:(NSString *)title text:(NSString *)text;
@end
@interface CLNotesViewController : UITableViewController { NSArray *notes; }
@end
@interface CLCheckInController : UITableViewController <UITextViewDelegate> { NSString *source; UITextView *goal; UISegmentedControl *energy,*recovery,*time; }
- (id)initWithSource:(NSString *)source;
@end
