#import "CDSkin.h"

#define CD_SKIN_VERSION @"6"   // bump when a drawing changes, so cached textures are drawn again
static NSMutableDictionary *memory = nil; static NSMutableString *timings = nil;

UIImage *CDRender(CGSize size, void (^draw)(CGContextRef c)) {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0); draw(UIGraphicsGetCurrentContext());
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return i;
}
UIImage *CDCached(NSString *key, CGSize size, void (^draw)(CGContextRef c)) {
    @synchronized ([UIScreen class]) { if (!memory) { memory = [[NSMutableDictionary alloc] init]; timings = [[NSMutableString alloc] init]; } }
    UIImage *i; @synchronized (memory) { i = [[[memory objectForKey:key] retain] autorelease]; } if (i) return i;   // CDWarmUp draws on another thread
    CGFloat scale = [[UIScreen mainScreen] scale];
    NSString *dir = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"skin-" CD_SKIN_VERSION];
    NSString *path = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%.0fx.png", key, scale]];
    NSData *d = [NSData dataWithContentsOfFile:path];
    if (d) i = [UIImage imageWithCGImage:[[UIImage imageWithData:d] CGImage] scale:scale orientation:UIImageOrientationUp];
    if (!i) {
        NSDate *t0 = [NSDate date]; i = CDRender(size, draw);
        @synchronized (memory) { [timings appendFormat:@"%@ %.0f ms%@\n", key, -[t0 timeIntervalSinceNow] * 1000, [NSThread isMainThread] ? @"" : @" (background)"]; }
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL]; [UIImagePNGRepresentation(i) writeToFile:path atomically:YES];
    }
    @synchronized (memory) { [memory setObject:i forKey:key]; } return i;
}
void CDWarmUp(void) {   // the desk's textures, drawn while the cabinet is on screen so the first card opens at once
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        CDDeskImage(CGSizeMake(320, 416)); CDCardImage(YES, 1); CDCardImage(NO, 5); for (int k = 0; k < 3; k++) CDCardImage(NO, 2 + k);
        for (int r = 1; r <= 4; r++) { CDStampImage(r, NO); CDStampImage(r, YES); for (int k = 0; k < 3; k++) CDImpressionImage(r, k); }
        NSString *t; @synchronized (memory) { t = [[timings copy] autorelease]; }   // only non-empty after a fresh install: what each texture cost to draw
        if ([t length]) [t writeToFile:[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"skin-timing.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        [pool release];
    });
}

void CDSkinNavBar(UINavigationBar *bar) {
    UIImage *cloth = CDCached(@"cloth", CGSizeMake(320, 44), ^(CGContextRef c) { CDDrawCloth(c, CGRectMake(0, 0, 320, 44)); });
    if ([bar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) [bar performSelector:@selector(setBackgroundImage:forBarMetrics:) withObject:cloth withObject:0];   // iOS 5 API, absent from the 4.3 SDK
    bar.tintColor = [UIColor colorWithRed:0.50 green:0.08 blue:0.24 alpha:1];   // the buttons in a deeper raspberry than the cloth
}
UIColor *CDDeskColor(void) { return [UIColor colorWithPatternImage:CDCached(@"desk-tile", CGSizeMake(320, 480), ^(CGContextRef c) { CDDrawOak(c, CGRectMake(0, 0, 320, 480), 3, 1); })]; }
UIImage *CDDeskImage(CGSize size) {
    return CDCached([NSString stringWithFormat:@"desk-%.0fx%.0f", size.width, size.height], size, ^(CGContextRef c) { CGRect r = CGRectMake(0, 0, size.width, size.height); CDDrawOak(c, r, 7, 0); CDDrawVignette(c, r); });
}
UIImageView *CDTopShade(CGFloat width) {
    UIImage *i = CDCached(@"topshade", CGSizeMake(8, 7), ^(CGContextRef c) {
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGFloat k[] = { 0.25, 0.10, 0.02, 0.35,  0.25, 0.10, 0.02, 0 }, l[] = { 0, 1 }; CGGradientRef g = CGGradientCreateWithColorComponents(cs, k, l, 2);
        CGContextDrawLinearGradient(c, g, CGPointMake(0, 0), CGPointMake(0, 7), 0); CGGradientRelease(g); CGColorSpaceRelease(cs);
    });
    UIImageView *v = [[[UIImageView alloc] initWithImage:[i stretchableImageWithLeftCapWidth:4 topCapHeight:0]] autorelease];
    v.frame = CGRectMake(0, 0, width, 7); v.autoresizingMask = UIViewAutoresizingFlexibleWidth; v.userInteractionEnabled = NO; return v;
}
UIImage *CDCardImage(BOOL ruled, uint32_t seed) {
    return CDCached([NSString stringWithFormat:@"card-%d-%u", ruled, seed], CGSizeMake(CD_CARD_W + 2 * CD_CARD_PAD, CD_CARD_H + 2 * CD_CARD_PAD), ^(CGContextRef c) {
        CDDrawIndexCard(c, CGRectMake(CD_CARD_PAD, CD_CARD_PAD, CD_CARD_W, CD_CARD_H), seed, ruled);
    });
}
UIImage *CDStackImage(uint32_t seed, int cards) {
    return CDCached([NSString stringWithFormat:@"stack-%u-%d", seed, cards], CGSizeMake(CD_STACK_W, CD_STACK_H), ^(CGContextRef c) { CDDrawStack(c, CGRectMake(0, 0, CD_STACK_W, CD_STACK_H), seed, cards); });
}
UIImage *CDBadgeImage(NSString *count) {
    CGSize sz = CDBadgeSize([count UTF8String]);
    return CDCached([@"badge-" stringByAppendingString:count], sz, ^(CGContextRef c) { CDDrawBadge(c, CGRectMake(0, 0, sz.width, sz.height), [count UTF8String]); });
}
UIImage *CDSectionHeaderImage(NSString *title) {
    return CDCached([@"header-" stringByAppendingString:title], CGSizeMake(320, 26), ^(CGContextRef c) { CDDrawSectionHeader(c, CGRectMake(0, 0, 320, 26), [title UTF8String]); });
}
UIImage *CDStampImage(int rating, BOOL pressed) {
    return CDCached([NSString stringWithFormat:@"stamp-%d-%d", rating, pressed], CGSizeMake(73, 70), ^(CGContextRef c) { CDDrawStamp(c, CGRectMake(0, 0, 73, 70), rating, pressed); });
}
UIImage *CDImpressionImage(int rating, uint32_t seed) {
    return CDCached([NSString stringWithFormat:@"impression-%d-%u", rating, seed], CGSizeMake(136, 50), ^(CGContextRef c) { CDDrawImpression(c, CGRectMake(2, 2, 132, 46), rating, seed); });
}
