#import <UIKit/UIKit.h>
#import "CDMaterials.h"
// UIKit's side of the desk: CDMaterials drawings turned into images once, kept in memory and in Library/Caches.
#define CD_CARD_PAD 8   // room around a card image for its shadow
UIImage *CDCached(NSString *key, CGSize size, void (^draw)(CGContextRef c));   // memory, then disk, then drawn
UIImage *CDRender(CGSize size, void (^draw)(CGContextRef c));                 // drawn every time
void CDSkinNavBar(UINavigationBar *bar);
UIColor *CDDeskColor(void);   // vertical-grain oak that tiles down a scroll view
UIImage *CDDeskImage(CGSize size);
UIImageView *CDTopShade(CGFloat width);   // the bar's shadow on whatever is under it
UIImage *CDCardImage(BOOL ruled, uint32_t seed);
UIImage *CDStackImage(uint32_t seed, int cards);
UIImage *CDBadgeImage(NSString *count);
UIImage *CDSectionHeaderImage(NSString *title);
UIImage *CDStampImage(int rating, BOOL pressed);
UIImage *CDImpressionImage(int rating, uint32_t seed);
void CDWarmUp(void);           // draws the desk's textures in the background
