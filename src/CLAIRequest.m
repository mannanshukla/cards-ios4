#import "CLAIRequest.h"
#import "ORJSON.h"
@interface CLAIRequest (Transport)
- (void)received:(NSURLResponse *)r connection:(NSURLConnection *)c;
- (void)bytes:(NSData *)d connection:(NSURLConnection *)c;
- (void)ended:(NSURLConnection *)c error:(NSError *)e;
- (NSURLRequest *)redirect:(NSURLRequest *)r response:(NSURLResponse *)s connection:(NSURLConnection *)c;
@end
@interface CLAIProxy : NSObject { @public CLAIRequest *owner; }
@end
@implementation CLAIProxy
- (void)connection:(NSURLConnection *)c didReceiveResponse:(NSURLResponse *)r { CLAIRequest *o=[owner retain];[o received:r connection:c];[o release]; }
- (void)connection:(NSURLConnection *)c didReceiveData:(NSData *)d { CLAIRequest *o=[owner retain];[o bytes:d connection:c];[o release]; }
- (void)connectionDidFinishLoading:(NSURLConnection *)c { CLAIRequest *o=[owner retain];[o ended:c error:nil];[o release]; }
- (void)connection:(NSURLConnection *)c didFailWithError:(NSError *)e { CLAIRequest *o=[owner retain];[o ended:c error:e];[o release]; }
- (NSURLRequest *)connection:(NSURLConnection *)c willSendRequest:(NSURLRequest *)r redirectResponse:(NSURLResponse *)s { CLAIRequest *o=[owner retain];NSURLRequest *next=[[o redirect:r response:s connection:c] retain];[o release];return [next autorelease]; }
@end
static NSString *str(id x) { return [x isKindOfClass:[NSString class]]?x:@""; }
@implementation CLAIRequest
@synthesize delegate,state;
- (BOOL)running { return state==CLAIRunning; }
+ (NSString *)providerName { [[NSUserDefaults standardUserDefaults] synchronize];return [[[NSUserDefaults standardUserDefaults] stringForKey:@"ai_provider"] isEqual:@"openrelay"]?@"OpenRelay":@"Claude"; }
+ (NSMutableURLRequest *)requestForSystem:(NSString *)system user:(NSString *)user settings:(NSDictionary *)s error:(NSString **)error {
    BOOL useClaude=![str([s objectForKey:@"ai_provider"]) isEqual:@"openrelay"];
    NSString *key=useClaude?str([s objectForKey:@"ai_claude_key"]):str([s objectForKey:@"hb_api_key"]?:[s objectForKey:@"lf_api_key"]);
    key=[key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(![key length]) { if(error)*error=useClaude?@"Enter your Claude API key in this app’s Settings → AI Coach.":@"Enter your OpenRelay key in this app’s Settings.";return nil; }
    if(![user length] || [user length]>96000 || [system length]>16000) { if(error)*error=@"The request is empty or too long. Shorten the goal or notes.";return nil; }
    NSString *model=useClaude?str([s objectForKey:@"ai_claude_model"]):@"openrelay/gpt-oss-120b";
    if(![model length])model=@"claude-sonnet-5-5";
    NSMutableArray *messages=[NSMutableArray array];
    if(!useClaude)[messages addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"system",@"role",system?:@"",@"content",nil]];
    [messages addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"user",@"role",user,@"content",nil]];
    NSMutableDictionary *body=[NSMutableDictionary dictionaryWithObjectsAndKeys:model,@"model",messages,@"messages",[NSNumber numberWithInt:4096],@"max_tokens",[NSNumber numberWithBool:NO],@"stream",nil];
    if(useClaude)[body setObject:system?:@"" forKey:@"system"];
    NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:useClaude?@"https://api.anthropic.com/v1/messages":@"https://inference.openrelay.inc/v1/chat/completions"] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:90];
    r.HTTPMethod=@"POST";[r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if(useClaude) { [r setValue:key forHTTPHeaderField:@"x-api-key"];[r setValue:@"2023-06-01" forHTTPHeaderField:@"anthropic-version"]; }
    else [r setValue:[@"Bearer " stringByAppendingString:key] forHTTPHeaderField:@"Authorization"];
    r.HTTPBody=[[ORJSON stringify:body] dataUsingEncoding:NSUTF8StringEncoding];return r;
}
+ (NSString *)textFromData:(NSData *)data status:(NSInteger)code claude:(BOOL)useClaude error:(NSString **)error {
    if([data length]>512*1024) { if(error)*error=@"The response was too large.";return nil; }
    id obj=[ORJSON parse:[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]];
    if(code!=200 || ![obj isKindOfClass:[NSDictionary class]]) {
        NSString *message=code==401 || code==403?@"The API key was rejected. Check this app’s Settings.":code==429?@"The provider is busy or your limit was reached. Try again later.":@"The provider returned an unreadable response.";
        if(error)*error=message;return nil;
    }
    NSMutableString *out=[NSMutableString string];
    if(useClaude) {
        if(![str([obj objectForKey:@"stop_reason"]) isEqual:@"end_turn"]) { if(error)*error=@"The response did not finish. Try a smaller plan.";return nil; }
        id blocks=[obj objectForKey:@"content"];
        if([blocks isKindOfClass:[NSArray class]])for(id b in blocks)if([b isKindOfClass:[NSDictionary class]] && [str([b objectForKey:@"type"]) isEqual:@"text"])[out appendString:str([b objectForKey:@"text"])];
    } else {
        id choices=[obj objectForKey:@"choices"],first=[choices isKindOfClass:[NSArray class]] && [choices count]?[choices objectAtIndex:0]:nil;
        if([first isKindOfClass:[NSDictionary class]] && [str([first objectForKey:@"finish_reason"]) isEqual:@"stop"]) { id m=[first objectForKey:@"message"];if([m isKindOfClass:[NSDictionary class]])[out appendString:str([m objectForKey:@"content"])]; }
    }
    NSString *text=[out stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(![text length] || [text length]>32768) { if(error)*error=@"The provider returned no complete, usable text.";return nil; }return text;
}
- (id)init { if((self=[super init])) { proxy=[CLAIProxy new];proxy->owner=self;[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(background:) name:@"UIApplicationDidEnterBackgroundNotification" object:nil]; }return self; }
- (void)clearTransport { NSURLConnection *old=connection;connection=nil;[old cancel];[old release];[response release];response=nil; }
- (void)cancel { if(self.running)state=CLAICancelled;[self clearTransport]; }
- (void)finish:(NSString *)text error:(NSString *)error {
    [self retain];state=text?CLAICompleted:CLAIFailed;[self clearTransport];
    [delegate aiRequest:self text:text error:error];[self release];
}
- (void)background:(NSNotification *)n { if(self.running) { [self retain];[self cancel];[delegate aiRequest:self text:nil error:@"Request cancelled when the app went into the background."];[self release]; } }
- (void)startSystem:(NSString *)system user:(NSString *)user {
    [self cancel];[[NSUserDefaults standardUserDefaults] synchronize];NSDictionary *s=[[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    claude=![str([s objectForKey:@"ai_provider"]) isEqual:@"openrelay"];NSString *error=nil;NSMutableURLRequest *r=[[self class] requestForSystem:system user:user settings:s error:&error];
    state=CLAIRunning;if(!r) { [self finish:nil error:error];return; }
    status=0;response=[NSMutableData new];connection=[[NSURLConnection alloc] initWithRequest:r delegate:proxy startImmediately:NO];
    if(!connection) { [self finish:nil error:@"Could not start the connection."];return; }[connection start];
}
- (void)received:(NSURLResponse *)r connection:(NSURLConnection *)c { if(c!=connection || !self.running)return;status=[r isKindOfClass:[NSHTTPURLResponse class]]?[(NSHTTPURLResponse *)r statusCode]:0;[response setLength:0]; }
- (void)bytes:(NSData *)d connection:(NSURLConnection *)c { if(c!=connection || !self.running)return;if([d length]>512*1024-[response length]) { [self finish:nil error:@"The response was too large."];return; }[response appendData:d]; }
- (void)ended:(NSURLConnection *)c error:(NSError *)e {
    if(c!=connection || !self.running)return;
    NSString *error=nil,*text=nil;
    if(e)error=[e code]==-1012?@"The API key was rejected. Check this app’s Settings.":[e localizedDescription];
    else text=[[self class] textFromData:response status:status claude:claude error:&error];
    [self finish:text error:error];
}
- (NSURLRequest *)redirect:(NSURLRequest *)r response:(NSURLResponse *)s connection:(NSURLConnection *)c { if(c!=connection || !self.running)return nil;if(s) { [self finish:nil error:@"The provider tried to redirect this request. No key was forwarded."];return nil; }return r; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self];delegate=nil;proxy->owner=nil;[self cancel];[proxy release];[super dealloc]; }
@end
