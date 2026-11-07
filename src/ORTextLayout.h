#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
@interface ORTextLayout : NSObject {
    NSAttributedString *text;
    CTFramesetterRef framesetter;
    NSArray *pages;
    CGFloat width;
}
- (id)initWithText:(NSString *)source markdown:(BOOL)markdown width:(CGFloat)width;
- (id)initWithText:(NSString *)source markdown:(BOOL)markdown width:(CGFloat)width fontSize:(CGFloat)size highlight:(NSString *)query;
- (CGFloat)widthOfPage:(NSUInteger)page;
- (NSString *)kindOfPage:(NSUInteger)page;
- (NSString *)sourceOfPage:(NSUInteger)page;
- (NSUInteger)firstHighlightedPage;
- (NSUInteger)pageCount;
- (CGFloat)heightOfPage:(NSUInteger)page;
- (void)drawPage:(NSUInteger)page context:(CGContextRef)context origin:(CGPoint)origin;
- (NSString *)linkAtPoint:(CGPoint)point page:(NSUInteger)page;
@end
