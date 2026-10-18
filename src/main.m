#import <UIKit/UIKit.h>
#import "CDViewControllers.h"
#import "CDStore.h"
@interface CDAppDelegate : NSObject <UIApplicationDelegate> { UIWindow *window; UINavigationController *nav; }
@end
@implementation CDAppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:20], @"cd_new_per_day", [NSNumber numberWithInt:200], @"cd_max_reviews", [NSNumber numberWithDouble:0.9], @"cd_retention", nil]];   // Settings.bundle defaults only apply once the user opens Settings
    window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    nav = [[UINavigationController alloc] initWithRootViewController:[[[CDDecksViewController alloc] init] autorelease]]; nav.navigationBar.tintColor = CDTint();
    [window addSubview:nav.view]; [window makeKeyAndVisible];
    return YES;
}
- (void)applicationDidBecomeActive:(UIApplication *)app { [[NSUserDefaults standardUserDefaults] synchronize]; [[CDStore shared] reloadIfChanged]; }   // a sync, a settings change, or a new day
- (void)dealloc { [nav release]; [window release]; [super dealloc]; }
@end
int main(int argc, char *argv[]) { NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init]; int r = UIApplicationMain(argc, argv, nil, @"CDAppDelegate"); [p release]; return r; }
