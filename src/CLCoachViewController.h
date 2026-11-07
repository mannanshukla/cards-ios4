#import <UIKit/UIKit.h>
#import "CLAIRequest.h"
@interface CLCoachViewController : UITableViewController <CLAIRequestDelegate,UITextViewDelegate> {
    NSString *source,*context,*system,*questionText,*status; UITextView *question; CLAIRequest *request;
}
- (id)initWithSource:(NSString *)source context:(NSString *)context system:(NSString *)system;
@property(nonatomic,copy) NSString *questionText;
@end
