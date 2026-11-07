#import <Foundation/Foundation.h>

// Deliberately bounded Markdown subset. Returns blocks with semantic inline runs;
// no HTML evaluation, scripts, remote images, or WebViews.
@interface ORMarkdown : NSObject
+ (NSArray *)blocks:(NSString *)source;
+ (NSString *)plainText:(NSString *)source;
@end
