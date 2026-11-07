// Native controls and journal paper v2. Identical in Meals, Sets, Habits, Cards and Claude.
// UIKit drawing is main-thread only; immutable textures are retained once.
#import <UIKit/UIKit.h>
static inline UIColor *JRInk(void) { return [UIColor colorWithRed:.22 green:.23 blue:.20 alpha:1]; }
static inline UIColor *JRRule(void) { return [UIColor colorWithRed:.70 green:.75 blue:.73 alpha:1]; }
static inline UIColor *JRPaper(void) {
 static UIColor *paper=nil;
 if(!paper) { UIGraphicsBeginImageContextWithOptions(CGSizeMake(64,64),YES,0);CGContextRef c=UIGraphicsGetCurrentContext();
 [[UIColor colorWithRed:.975 green:.958 blue:.907 alpha:1] setFill];CGContextFillRect(c,CGRectMake(0,0,64,64));
 unsigned seed=7319;for(int i=0;i<3000;i++) { seed=1664525*seed+1013904223;CGFloat x=((seed>>8)%128)/2.;seed=1664525*seed+1013904223;CGFloat y=((seed>>8)%128)/2.;CGContextSetGrayFillColor(c,(seed>>24)&1,.045);CGContextFillRect(c,CGRectMake(x,y,.5,.5)); }
 for(int y=0;y<64;y+=4) { CGContextSetGrayFillColor(c,1,.10);CGContextFillRect(c,CGRectMake(0,y,64,.5)); }
 paper=[[UIColor colorWithPatternImage:UIGraphicsGetImageFromCurrentImageContext()] retain];UIGraphicsEndImageContext(); }return paper;
}
@interface UINavigationBar (JRLegacyBackground)
- (void)setBackgroundImage:(UIImage *)image forBarMetrics:(NSInteger)metrics;
@end
static inline void JRStyleBar(UINavigationBar *bar,unsigned rgb) {
 bar.barStyle=UIBarStyleDefault;bar.translucent=NO;
 bar.tintColor=[UIColor colorWithRed:((rgb>>16)&255)/255.0 green:((rgb>>8)&255)/255.0 blue:(rgb&255)/255.0 alpha:1];
 if([bar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)])[bar setBackgroundImage:nil forBarMetrics:0];
}
