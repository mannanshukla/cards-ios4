#import <Foundation/Foundation.h>
NSURL *CLDraftURL(NSString *source, NSString *question, NSString *context);
NSString *CLDraftTextFromURL(NSURL *url, NSString **error);
