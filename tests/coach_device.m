#import <UIKit/UIKit.h>
#import <malloc/malloc.h>
#import "CDCoachViewController.h"
#import "CLCoachViewController.h"
#import "CLPaper.h"
#import "CDStore.h"
#import "ORJSON.h"
static NSUInteger closed;
#define TRACK(name,base) @interface name:base @end @implementation name - (void)dealloc { closed++;[super dealloc]; } @end
TRACK(Home,CDCoachViewController)
TRACK(Note,CLNoteViewController)
TRACK(Check,CLCheckInController)
TRACK(Coach,CLCoachViewController)
static void check(BOOL b,const char *m) { if(!b){printf("FAIL %s\n",m);fflush(stdout);exit(1);} }
static size_t allocated(void) { malloc_statistics_t s;malloc_zone_statistics(NULL,&s);return s.size_in_use; }
static void reload(UIViewController *c) { check(c.view!=nil,"view loads");[c viewWillAppear:NO];[c viewWillDisappear:NO];[c viewDidUnload];c.view=nil;check(c.view!=nil,"memory-warning reload");[c viewWillAppear:NO];[c viewWillDisappear:NO]; }
@interface Audit:NSObject<UIApplicationDelegate> { UIWindow *window; }
@end
@implementation Audit
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options { window=[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];window.rootViewController=[[[UIViewController alloc] init] autorelease];[window makeKeyAndVisible];[self performSelector:@selector(run) withObject:nil afterDelay:.5];return YES; }
- (void)run { NSString *docs=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];freopen([[docs stringByAppendingPathComponent:@"audit.txt"] fileSystemRepresentation],"w",stdout);freopen([[docs stringByAppendingPathComponent:@"audit.txt"] fileSystemRepresentation],"a",stderr);
 NSDictionary *card=[NSDictionary dictionaryWithObjectsAndKeys:@"test-id",@"id",@"Biology",@"deck",@"<b>What is ATP?</b>",@"front",@"Energy carrier",@"back",nil];NSDictionary *data=[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:1],@"format",[NSArray arrayWithObject:@"Biology"],@"decks",[NSArray arrayWithObject:card],@"cards",nil];[[ORJSON stringify:data] writeToFile:[docs stringByAppendingPathComponent:@"cards.json"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 CDStore *store=[CDStore shared];check([store cardCount]==1,"fixture loaded");[[NSUserDefaults standardUserDefaults] setInteger:20 forKey:@"cd_new_per_day"];size_t baseline=0,last=0;
 for(int i=0;i<50;i++) { NSAutoreleasePool *pool=[NSAutoreleasePool new];Home *h=[Home new];reload(h);[h release];Check *c=[[Check alloc] initWithSource:@"Cards"];reload(c);[c release];Note *n=[[Note alloc] initWithTitle:@"Claude" text:@"## A useful session\n- Start with your **due cards**.\n- Recall before revealing.\n\n```\nA long line inside a horizontally scrollable box.\n```\n"];reload(n);[n release];Coach *a=[[Coach alloc] initWithSource:@"Cards" context:[store coachSummaryForDeck:nil] system:@"Help with learning."];reload(a);[a release];[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.02]];[pool drain];last=allocated();if(i==9)baseline=last;if(i%10==9) { printf("cycle %d allocated=%lu\n",i+1,(unsigned long)last);fflush(stdout); } }
 check(closed==200,"all 200 new controllers released");check(last<baseline+512*1024,"bounded warmed heap");check(![[NSFileManager defaultManager] fileExistsAtPath:[docs stringByAppendingPathComponent:@"reviews.jsonl"]],"coach does not write reviews");printf("PASS 200 controllers released; heap change %+ld bytes; no review writes\n",(long)last-(long)baseline);fflush(stdout);exit(0);
}
- (void)dealloc { [window release];[super dealloc]; }
@end
int main(int argc,char **argv) { NSAutoreleasePool *pool=[NSAutoreleasePool new];int r=UIApplicationMain(argc,argv,nil,@"Audit");[pool drain];return r; }
