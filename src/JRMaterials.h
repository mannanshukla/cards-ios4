// Journal materials v1. Identical in Meals, Sets, Habits, Cards and Claude.
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
static inline UIImage *JRBinding(unsigned rgb) {
 CGFloat red=((rgb>>16)&255)/255.,green=((rgb>>8)&255)/255.,blue=(rgb&255)/255.;
 UIGraphicsBeginImageContextWithOptions(CGSizeMake(320,44),YES,0);CGContextRef c=UIGraphicsGetCurrentContext();
 CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();CGFloat colors[]={red*1.12,green*1.12,blue*1.12,1,red*.76,green*.76,blue*.76,1};CGGradientRef g=CGGradientCreateWithColorComponents(space,colors,NULL,2);CGContextDrawLinearGradient(c,g,CGPointZero,CGPointMake(0,44),0);CGGradientRelease(g);CGColorSpaceRelease(space);
 for(int y=0;y<44;y+=2) { CGContextSetGrayFillColor(c,1,.065);CGContextFillRect(c,CGRectMake(0,y,320,.5));CGContextSetGrayFillColor(c,0,.10);CGContextFillRect(c,CGRectMake(0,y+1,320,.5)); }
 for(int x=0;x<320;x+=2) { CGContextSetGrayFillColor(c,1,.045);CGContextFillRect(c,CGRectMake(x,0,.5,44)); }
 CGContextSetGrayFillColor(c,1,.24);CGContextFillRect(c,CGRectMake(0,0,320,.5));
 CGContextSetGrayFillColor(c,0,.30);CGContextFillRect(c,CGRectMake(0,40,320,1));CGContextSetGrayFillColor(c,1,.18);CGContextFillRect(c,CGRectMake(0,41,320,.5));CGContextSetGrayFillColor(c,0,.4);CGContextFillRect(c,CGRectMake(0,43,320,1));
 UIImage *image=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();return image;
}
@interface UINavigationBar (JRLegacyBackground)
- (void)setBackgroundImage:(UIImage *)image forBarMetrics:(NSInteger)metrics;
@end
static inline void JRStyleBar(UINavigationBar *bar,unsigned rgb) {
 // One cached image per app accent, with a bound for callers using other colors.
 static NSMutableDictionary *images=nil;if(!images)images=[[NSMutableDictionary alloc] init];NSNumber *key=[NSNumber numberWithUnsignedInt:rgb];UIImage *image=[images objectForKey:key];if(!image) { image=JRBinding(rgb);if([images count]>8)[images removeAllObjects];[images setObject:image forKey:key]; }
 bar.translucent=NO;
 if([bar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)])[bar setBackgroundImage:image forBarMetrics:0];
}
