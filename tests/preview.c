// Renders the app's screens on the Mac at the iPod's 640x960 from the same CDMaterials code, for checking the drawing
// without a device. UIKit's parts (bar buttons, the card text in its web view) are stood in for roughly.
//   clang -framework CoreGraphics -framework CoreText -framework ImageIO -framework CoreFoundation tests/preview.c src/CDMaterials.c -o /tmp/preview && /tmp/preview <out dir>
// `/tmp/preview res launch` draws the launch images, Default.png and Default@2x.png.
#include "../src/CDMaterials.h"
#include <ImageIO/ImageIO.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

static CGContextRef screenAt(CGFloat h, CGFloat sc) {
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGContextRef c = CGBitmapContextCreate(NULL, (size_t)(320 * sc), (size_t)(h * sc), 8, (size_t)(320 * sc) * 4, cs, kCGImageAlphaPremultipliedLast); CGColorSpaceRelease(cs);
    CGContextTranslateCTM(c, 0, h * sc); CGContextScaleCTM(c, sc, -sc); return c;   // y down, in points, like a UIKit context
}
static CGContextRef screen(CGFloat h) { return screenAt(h, 2); }
static void save(CGContextRef c, const char *dir, const char *name) {
    char path[1024]; snprintf(path, sizeof path, "%s/%s.png", dir, name);
    CGImageRef img = CGBitmapContextCreateImage(c); CFURLRef u = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)path, strlen(path), false);
    CGImageDestinationRef d = CGImageDestinationCreateWithURL(u, CFSTR("public.png"), 1, NULL); CGImageDestinationAddImage(d, img, NULL); CGImageDestinationFinalize(d);
    CFRelease(d); CFRelease(u); CGImageRelease(img); CGContextRelease(c); printf("%s\n", path);
}
static void launch(const char *dir, CGFloat sc, const char *name) {   // Default.png: the app's chrome with nothing in it yet, as Apple's own apps launch
    CGContextRef c = screenAt(480, sc); CGContextSetRGBFillColor(c, 0, 0, 0, 1); CGContextFillRect(c, CGRectMake(0, 0, 320, 20));
    CGContextSaveGState(c); CGContextClipToRect(c, CGRectMake(0, 64, 320, 416)); CDDrawOak(c, CGRectMake(0, 64, 320, 480), 3, 1); CGContextRestoreGState(c);
    CDDrawCloth(c, CGRectMake(0, 20, 320, 44));
    CGFloat k[] = { 0.25, 0.10, 0.02, 0.35,  0.25, 0.10, 0.02, 0 }, l[] = { 0, 1 }; CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGGradientRef g = CGGradientCreateWithColorComponents(cs, k, l, 2);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, 64), CGPointMake(0, 71), 0); CGGradientRelease(g); CGColorSpaceRelease(cs);
    save(c, dir, name);
}
static void say(CGContextRef c, const char *s, const char *f, CGFloat size, CGFloat x, CGFloat y, CGFloat r, CGFloat g, CGFloat b) {
    CFStringRef str = CFStringCreateWithCString(NULL, s, kCFStringEncodingUTF8), fn = CFStringCreateWithCString(NULL, f, kCFStringEncodingUTF8);
    CTFontRef font = CTFontCreateWithName(fn, size, NULL); CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGFloat k[4] = { r, g, b, 1 }; CGColorRef col = CGColorCreate(cs, k);
    const void *keys[] = { kCTFontAttributeName, kCTForegroundColorAttributeName }, *vals[] = { font, col };
    CFDictionaryRef at = CFDictionaryCreate(NULL, keys, vals, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks); CFAttributedStringRef as = CFAttributedStringCreate(NULL, str, at);
    CTLineRef l = CTLineCreateWithAttributedString(as); CGFloat w = CTLineGetTypographicBounds(l, NULL, NULL, NULL);
    CGContextSetTextMatrix(c, CGAffineTransformMakeScale(1, -1)); CGContextSetTextPosition(c, x - w / 2, y); CTLineDraw(l, c);
    CFRelease(l); CFRelease(as); CFRelease(at); CGColorRelease(col); CGColorSpaceRelease(cs); CFRelease(font); CFRelease(fn); CFRelease(str);
}
static void pressed(CGContextRef c, const char *s, const char *f, CGFloat size, CGFloat x, CGFloat y, CGFloat r, CGFloat g, CGFloat b) { say(c, s, f, size, x, y + 1, 1, 0.97, 0.88); say(c, s, f, size, x, y, r, g, b); }   // letterpress, as a UILabel with a light shadow
static void bar(CGContextRef c, const char *title, const char *left, const char *right) {
    CGContextSetRGBFillColor(c, 0, 0, 0, 1); CGContextFillRect(c, CGRectMake(0, 0, 320, 20));
    CDDrawCloth(c, CGRectMake(0, 20, 320, 44));
    say(c, title, "Helvetica-Bold", 20, 160, 49, 0.25, 0.02, 0.09); say(c, title, "Helvetica-Bold", 20, 160, 48, 1, 1, 1);   // UIKit's own title, white with a dark shadow above
    const char *b[2] = { left, right };
    for (int i = 0; i < 2; i++) if (b[i]) {   // a stand-in for UIKit's tinted bar button
        CGRect r = i ? CGRectMake(255, 27, 58, 30) : CGRectMake(7, 27, 62, 30);
        CGContextSetRGBFillColor(c, 0.45, 0.07, 0.22, 1); CGContextFillRect(c, r); say(c, b[i], "Helvetica-Bold", 12, CGRectGetMidX(r), r.origin.y + 19, 1, 1, 1);
    }
}
static void cardAt(CGContextRef c, CGFloat cx, CGFloat cy, CGFloat deg, uint32_t seed, int ruled) {
    CGContextSaveGState(c); CGContextTranslateCTM(c, cx, cy); CGContextRotateCTM(c, deg * M_PI / 180);
    CDDrawIndexCard(c, CGRectMake(-CD_CARD_W / 2.0, -CD_CARD_H / 2.0, CD_CARD_W, CD_CARD_H), seed, ruled); CGContextRestoreGState(c);
}
static void stack(CGContextRef c, CGFloat x, CGFloat y, uint32_t seed, int n, const char *name, const char *counts, const char *badge) {
    CGRect r = CGRectMake(x, y, CD_STACK_W, CD_STACK_H); CDDrawStack(c, r, seed, n);
    if (badge) { CGRect t = CDStackTopCard(r, seed); CGSize b = CDBadgeSize(badge); CDDrawBadge(c, CGRectMake(CGRectGetMaxX(t) - b.width / 2 - 2, t.origin.y - b.height / 2 + 2, b.width, b.height), badge); }
    pressed(c, name, "Helvetica-Bold", 14, x + CD_STACK_W / 2, y + CD_STACK_H + 10, 0.24, 0.15, 0.06); pressed(c, counts, "Helvetica", 12, x + CD_STACK_W / 2, y + CD_STACK_H + 26, 0.42, 0.28, 0.12);
}
static void desk(CGContextRef c, int answer) {
    CDDrawOak(c, CGRectMake(0, 64, 320, 416), 7, 0); CDDrawVignette(c, CGRectMake(0, 64, 320, 416));
    CDDrawCountTab(c, CGRectMake(40, 69, 240, 30), 19, 1, 0);
    CGFloat cx = 160, cy = 110 + CD_CARD_H / 2.0;
    cardAt(c, cx - 4, cy + 12, -4.2, 4, 0); cardAt(c, cx + 3, cy + 9, 3.2, 3, 0); cardAt(c, cx - 2, cy + 5, -2.4, 2, 0);
    cardAt(c, cx, cy, 0, 1, !answer);
    CGFloat left = cx - CD_CARD_W / 2.0, topY = cy - CD_CARD_H / 2.0;
    if (!answer) {
        say(c, "NEW CARD", "Helvetica", 9, left + CD_CARD_W - 40, topY + 26, 0.55, 0.55, 0.58);
        say(c, "\xE3\x81\xBF\xE3\x81\x9A", "Helvetica", 15, cx, topY + CD_CARD_FIRST_RULE + 2 * CD_CARD_RULE - 32, 0.36, 0.40, 0.52);
        say(c, "\xE6\xB0\xB4", "Helvetica", 40, cx, topY + CD_CARD_FIRST_RULE + 3 * CD_CARD_RULE - 6, 0.12, 0.14, 0.20);
        pressed(c, "Tap the card to turn it over.", "Helvetica", 13, 160, 418, 0.38, 0.23, 0.08);
    } else {
        say(c, "\xE6\xB0\xB4", "Helvetica", 14, cx, topY + 22, 0.55, 0.56, 0.62);
        say(c, "water", "Helvetica", 40, cx, topY + 100, 0.12, 0.14, 0.20);
        CGContextSaveGState(c); CGContextTranslateCTM(c, cx + 62, topY + 140); CGContextRotateCTM(c, -6 * M_PI / 180); CDDrawImpression(c, CGRectMake(-66, -24, 132, 46), 3, 11); CGContextRestoreGState(c);
        const char *ivl[] = { "1m", "6m", "10m", "16d" };
        for (int i = 0; i < 4; i++) { CDDrawStamp(c, CGRectMake(8 + i * 77, 404, 73, 70), i + 1, i == 2); say(c, ivl[i], "Helvetica", 10, 8 + i * 77 + 36.5, 404 + 50 + (i == 2 ? 3 : 0), 0.35, 0.35, 0.38); }
    }
}
int main(int argc, char **argv) {
    const char *dir = argc > 1 ? argv[1] : "."; CDShadowSign = -1;   // a flipped Mac bitmap: positive shadow heights go up
    if (argc > 2 && !strcmp(argv[2], "launch")) { launch(dir, 2, "Default@2x"); launch(dir, 1, "Default"); return 0; }
    CGContextRef c = screen(480); bar(c, "Cards", NULL, "Stats");
    CDDrawOak(c, CGRectMake(0, 64, 320, 416), 3, 1);
    stack(c, 8, 76, 11, 4, "All Decks", "20 new \xC2\xB7 7 learning", NULL); stack(c, 162, 76, 12, 3, "Welcome", "7 learning", NULL);
    CDDrawSectionHeader(c, CGRectMake(0, 230, 320, 24), "JAPANESE");
    stack(c, 8, 258, 14, 4, "N5 Vocab", "20 new \xC2\xB7 3 due", "3");
    pressed(c, "29 cards \xC2\xB7 synced today at 3:42 AM from MrLeeM1", "Helvetica", 11, 160, 428, 0.40, 0.26, 0.10);
    save(c, dir, "decks");
    c = screen(480); bar(c, "N5 Vocab", "Decks", "Undo"); desk(c, 0); save(c, dir, "front");
    c = screen(480); bar(c, "N5 Vocab", "Decks", "Undo"); desk(c, 1); save(c, dir, "answer");
    CDStatsData d = { 5, { "OCT 12 2026", "OCT 13 2026", "OCT 15 2026", "OCT 16 2026", "OCT 18 2026" }, { 34, 12, 41, 18, 22 },
        { "OCT 19 2026", "OCT 20 2026", "OCT 21 2026", "OCT 22 2026", "OCT 23 2026", "OCT 24 2026", "OCT 25 2026" }, { 7, 12, 0, 3, 18, 5, 1 },
        22, 6, 9, 3, 91, 64, 90, 140, 12, 58, 21 };
    CGFloat h = CDDateDueHeight(&d) + 64; c = screen(h); bar(c, "Stats", NULL, "Done");
    CDDrawOak(c, CGRectMake(0, 64, 320, h - 64), 5, 1); CGContextTranslateCTM(c, 0, 64); CDDrawDateDue(c, 320, &d); save(c, dir, "stats");
    return 0;
}
