#import <Foundation/Foundation.h>
@class CLAIRequest, CLAIProxy;
typedef enum { CLAIIdle, CLAIRunning, CLAICompleted, CLAIFailed, CLAICancelled } CLAIState;
@protocol CLAIRequestDelegate <NSObject>
- (void)aiRequest:(CLAIRequest *)request text:(NSString *)text error:(NSString *)error;
@end
@interface CLAIRequest : NSObject {
    id<CLAIRequestDelegate> delegate; CLAIProxy *proxy; NSURLConnection *connection;
    NSMutableData *response; NSInteger status; BOOL claude; CLAIState state;
}
@property(nonatomic,assign) id<CLAIRequestDelegate> delegate;
@property(nonatomic,readonly) CLAIState state;
@property(nonatomic,readonly) BOOL running;
+ (NSString *)providerName;
+ (NSMutableURLRequest *)requestForSystem:(NSString *)system user:(NSString *)user settings:(NSDictionary *)settings error:(NSString **)error;
+ (NSString *)textFromData:(NSData *)data status:(NSInteger)status claude:(BOOL)claude error:(NSString **)error;
- (void)startSystem:(NSString *)system user:(NSString *)user;
- (void)cancel;
@end
