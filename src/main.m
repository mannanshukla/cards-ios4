#import <UIKit/UIKit.h>
#import "CDViewControllers.h"
#import "CDStore.h"
#import "CDCoachViewController.h"
#import "CLPaper.h"
#import "CDSkin.h"
#import <QuartzCore/QuartzCore.h>
@interface CDAppDelegate : NSObject <UIApplicationDelegate> { UIWindow *window; UITabBarController *tabs; NSUInteger naps; }
@end
@implementation CDAppDelegate
- (UINavigationController *)wrap:(UIViewController *)v title:(NSString *)title icon:(int)icon {
    UINavigationController *n = [[[UINavigationController alloc] initWithRootViewController:v] autorelease]; CDSkinNavBar(n.navigationBar);
    n.tabBarItem = [[[UITabBarItem alloc] initWithTitle:title image:icon==2?CLCoachIcon():CDTabIcon(icon) tag:icon] autorelease]; return n;
}
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:20], @"cd_new_per_day", [NSNumber numberWithInt:200], @"cd_max_reviews", [NSNumber numberWithDouble:0.9], @"cd_retention", nil]];   // Settings.bundle defaults only apply once the user opens Settings
    window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = [NSArray arrayWithObjects:[self wrap:[[[CDDecksViewController alloc] init] autorelease] title:@"Decks" icon:0], [self wrap:[[[CDCoachViewController alloc] init] autorelease] title:@"Coach" icon:2], [self wrap:[[[CDStatsViewController alloc] init] autorelease] title:@"Stats" icon:1], nil];
    if ([tabs.tabBar respondsToSelector:@selector(setSelectedImageTintColor:)]) [tabs.tabBar performSelector:@selector(setSelectedImageTintColor:) withObject:[UIColor colorWithRed:0.92 green:0.36 blue:0.56 alpha:1]];   // iOS 5; iOS 4 keeps its blue
    window.rootViewController = tabs; [window makeKeyAndVisible];
    float slow = [[NSUserDefaults standardUserDefaults] floatForKey:@"cd_test_speed"]; if (slow > 0) window.layer.speed = slow;   // slow motion, to catch an animation in a screenshot
    return YES;
}
- (void)applicationDidEnterBackground:(UIApplication *)app {   // suspended, Cards keeps none of its textures
    CDPurge();   // screens out of sight let theirs go now (they watch for the background themselves)
    // The system takes the snapshot it zooms back in from once this returns, so what is on screen goes a moment later.
    NSUInteger nap = ++naps; __block UIBackgroundTaskIdentifier task = UIBackgroundTaskInvalid;
    void (^end)(void) = ^{ if (task != UIBackgroundTaskInvalid) { [app endBackgroundTask:task]; task = UIBackgroundTaskInvalid; } };
    task = [app beginBackgroundTaskWithExpirationHandler:end];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (nap == naps && app.applicationState == UIApplicationStateBackground) { [[NSNotificationCenter defaultCenter] postNotificationName:CDAsleep object:nil]; CDPurge(); }
        end();
    });
}
- (void)applicationWillEnterForeground:(UIApplication *)app { naps++; }   // a nap still pending is off; screens take their textures back on UIApplicationWillEnterForegroundNotification
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)app { CDPurge(); }
- (void)applicationDidBecomeActive:(UIApplication *)app { [[NSUserDefaults standardUserDefaults] synchronize]; [[CDStore shared] reloadIfChanged]; }   // a sync, a settings change, or a new day
- (void)dealloc { [tabs release]; [window release]; [super dealloc]; }
@end
int main(int argc, char *argv[]) { NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init]; int r = UIApplicationMain(argc, argv, nil, @"CDAppDelegate"); [p release]; return r; }
