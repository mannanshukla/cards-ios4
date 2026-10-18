#include "CDMaterials.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <dispatch/dispatch.h>

CGFloat CDShadowSign = 1;

enum { InkBlack, InkRed, InkBlue, InkGreen, InkPencil, InkGraphite, InkViolet };
static const CGFloat INK[][4] = {
    { 0.16, 0.15, 0.16, 0.94 },   // black
    { 0.76, 0.13, 0.15, 0.92 },   // red
    { 0.14, 0.33, 0.66, 0.92 },   // blue
    { 0.10, 0.47, 0.22, 0.92 },   // green
    { 0.42, 0.42, 0.45, 0.80 },   // pencil
    { 0.28, 0.29, 0.32, 0.92 },   // graphite pad
    { 0.44, 0.21, 0.61, 0.90 },   // date-stamp violet
};
static const int STAMP_INK[] = { 0, InkRed, InkGraphite, InkGreen, InkBlue };
static const char *STAMP_WORD[] = { "", "AGAIN", "HARD", "GOOD", "EASY" };
static const CGFloat RASPBERRY[4] = { 0.62, 0.15, 0.34, 0.85 };
static const char *HELV = "Helvetica", *HELV_BOLD = "Helvetica-Bold";

#pragma mark - helpers

static uint32_t rnd(uint32_t *s) { uint32_t x = *s ? *s : 0x9e3779b9u; x ^= x << 13; x ^= x >> 17; x ^= x << 5; return *s = x; }
static double frand(uint32_t *s) { return rnd(s) / 4294967296.0; }
static double fr(uint32_t *s, double a, double b) { return a + (b - a) * frand(s); }
static uint32_t mix(uint32_t seed) { uint32_t s = seed * 2654435761u + 0x6d2b79f5u; rnd(&s); rnd(&s); return s; }
static CGFloat scaleOf(CGContextRef c) { CGAffineTransform t = CGContextGetUserSpaceToDeviceSpaceTransform(c); return fmax(1, hypot(t.a, t.b)); }
static CGFloat hair(CGFloat y) { return floor(y * 2) / 2 + 0.25; }   // the centre of a device pixel row at 2x, for a crisp half-point line
static void fill(CGContextRef c, CGFloat r, CGFloat g, CGFloat b, CGFloat a) { CGContextSetRGBFillColor(c, r, g, b, a); }
static void stroke(CGContextRef c, CGFloat r, CGFloat g, CGFloat b, CGFloat a, CGFloat w) { CGContextSetRGBStrokeColor(c, r, g, b, a); CGContextSetLineWidth(c, w); }
static void line(CGContextRef c, CGFloat x0, CGFloat y0, CGFloat x1, CGFloat y1) { CGContextMoveToPoint(c, x0, y0); CGContextAddLineToPoint(c, x1, y1); CGContextStrokePath(c); }
static void castShadow(CGContextRef c, CGFloat dy, CGFloat blur, CGFloat a) {   // warm, never grey: everything sits on honey oak, lit from above
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGFloat k[4] = { 0.22, 0.11, 0.02, a }; CGColorRef col = CGColorCreate(cs, k);
    CGContextSetShadowWithColor(c, CGSizeMake(0, dy * CDShadowSign), blur, col); CGColorRelease(col); CGColorSpaceRelease(cs);
}
static void gradient(CGContextRef c, CGPoint a, CGPoint b, int n, const CGFloat *rgba, const CGFloat *locs) {
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGGradientRef g = CGGradientCreateWithColorComponents(cs, rgba, locs, n);
    CGContextDrawLinearGradient(c, g, a, b, kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation); CGGradientRelease(g); CGColorSpaceRelease(cs);
}
static CGPathRef rounded(CGRect r, CGFloat rad) {   // the caller releases it
    CGMutablePathRef p = CGPathCreateMutable(); CGFloat x0 = r.origin.x, y0 = r.origin.y, x1 = CGRectGetMaxX(r), y1 = CGRectGetMaxY(r);
    CGPathMoveToPoint(p, NULL, x0 + rad, y0); CGPathAddArcToPoint(p, NULL, x1, y0, x1, y1, rad); CGPathAddArcToPoint(p, NULL, x1, y1, x0, y1, rad);
    CGPathAddArcToPoint(p, NULL, x0, y1, x0, y0, rad); CGPathAddArcToPoint(p, NULL, x0, y0, x1, y0, rad); CGPathCloseSubpath(p); return p;
}
static void fillPath(CGContextRef c, CGPathRef p) { CGContextAddPath(c, p); CGContextFillPath(c); }
static void drawImage(CGContextRef c, CGRect r, CGImageRef img) {   // upright in a y-down context
    CGContextSaveGState(c); CGContextTranslateCTM(c, r.origin.x, r.origin.y + r.size.height); CGContextScaleCTM(c, 1, -1);
    CGContextDrawImage(c, CGRectMake(0, 0, r.size.width, r.size.height), img); CGContextRestoreGState(c);
}
// Grain: one tile of light and warm-dark specks, laid down tiled. Per-pixel noise in a blend mode costs most of a
// second a screen on an A4; a 96-pixel tile in plain source-over is nearly free and repeats too finely to see.
static CGImageRef speckTile(void) {
    static CGImageRef tile = NULL; static dispatch_once_t once;
    dispatch_once(&once, ^{
        size_t n = 96; unsigned char *px = malloc(n * n * 4); uint32_t s = 12345;   // px lives as long as the tile: forever
        for (size_t i = 0; i < n * n; i++) {
            int v = (int)(rnd(&s) >> 24) - 128, a = abs(v) * 2 > 255 ? 255 : abs(v) * 2; unsigned char *p = px + i * 4;
            if (v > 0) p[0] = p[1] = p[2] = (unsigned char)a; else { p[0] = (unsigned char)(a * 0.30); p[1] = (unsigned char)(a * 0.18); p[2] = (unsigned char)(a * 0.06); }
            p[3] = (unsigned char)a;
        }
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGDataProviderRef dp = CGDataProviderCreateWithData(NULL, px, n * n * 4, NULL);
        tile = CGImageCreate(n, n, 8, 32, n * 4, cs, kCGImageAlphaPremultipliedLast, dp, NULL, false, kCGRenderingIntentDefault);
        CGDataProviderRelease(dp); CGColorSpaceRelease(cs);
    });
    return tile;
}
static void noise(CGContextRef c, CGRect r, uint32_t seed, CGFloat alpha) {
    CGFloat t = 96 / scaleOf(c); uint32_t s = mix(seed); CGFloat ox = floor(fr(&s, 0, t)), oy = floor(fr(&s, 0, t));   // each surface starts the tile somewhere else
    CGContextSaveGState(c); CGContextClipToRect(c, r); CGContextSetAlpha(c, alpha); CGContextDrawTiledImage(c, CGRectMake(r.origin.x - ox, r.origin.y - oy, t, t), speckTile()); CGContextRestoreGState(c);
}
// Ink that came off a rubber stamp: paint into a scratch bitmap, then thin it unevenly and knock out the odd speck.
typedef void (*Painter)(CGContextRef c, CGRect r, const void *arg);
static void distressed(CGContextRef c, CGRect r, uint32_t seed, double wear, Painter paint, const void *arg) {
    CGFloat sc = scaleOf(c); size_t w = (size_t)ceil(r.size.width * sc), h = (size_t)ceil(r.size.height * sc); if (!w || !h) return;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGContextRef b = CGBitmapContextCreate(NULL, w, h, 8, w * 4, cs, kCGImageAlphaPremultipliedLast);
    CGContextTranslateCTM(b, 0, h); CGContextScaleCTM(b, sc, -sc);
    CGFloat sign = CDShadowSign; CDShadowSign = 1; paint(b, CGRectMake(0, 0, r.size.width, r.size.height), arg); CDShadowSign = sign;
    unsigned char *px = CGBitmapContextGetData(b); uint32_t s = mix(seed); double p1 = fr(&s, 0, 6.3), p2 = fr(&s, 0, 6.3), p3 = fr(&s, 0, 6.3);
    for (size_t y = 0; y < h; y++) for (size_t x = 0; x < w; x++) {
        unsigned char *p = px + (y * w + x) * 4; if (!p[3]) continue;
        double u = x / sc, v = y / sc, blot = 0.5 + 0.25 * sin(u * 0.11 + p1) + 0.25 * sin(v * 0.23 + u * 0.05 + p2) * sin(u * 0.03 + p3);
        double k = 1 - wear + wear * (0.45 * blot + 0.75 * frand(&s)); if (frand(&s) < wear * 0.06) k = 0; if (k > 1) k = 1;
        p[0] = (unsigned char)(p[0] * k); p[1] = (unsigned char)(p[1] * k); p[2] = (unsigned char)(p[2] * k); p[3] = (unsigned char)(p[3] * k);
    }
    CGImageRef img = CGBitmapContextCreateImage(b); drawImage(c, r, img); CGImageRelease(img); CGContextRelease(b); CGColorSpaceRelease(cs);
}

#pragma mark - type, all of it Helvetica

static CTFontRef font(const char *name, CGFloat size) { CFStringRef n = CFStringCreateWithCString(NULL, name, kCFStringEncodingUTF8); CTFontRef f = CTFontCreateWithName(n, size, NULL); CFRelease(n); return f; }
static void append(CFMutableAttributedStringRef as, const char *utf8, const char *fontName, CGFloat size, const CGFloat *rgba, CGFloat kern) {
    CFStringRef s = CFStringCreateWithCString(NULL, utf8, kCFStringEncodingUTF8); if (!s) return;
    CFIndex at = CFAttributedStringGetLength(as); CFAttributedStringReplaceString(as, CFRangeMake(at, 0), s); CFRange rg = CFRangeMake(at, CFStringGetLength(s));
    CTFontRef f = font(fontName, size); CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGColorRef col = CGColorCreate(cs, rgba); CFNumberRef k = CFNumberCreate(NULL, kCFNumberCGFloatType, &kern);
    CFAttributedStringSetAttribute(as, rg, kCTFontAttributeName, f); CFAttributedStringSetAttribute(as, rg, kCTForegroundColorAttributeName, col); CFAttributedStringSetAttribute(as, rg, kCTKernAttributeName, k);
    CFRelease(k); CGColorRelease(col); CGColorSpaceRelease(cs); CFRelease(f); CFRelease(s);
}
static CTLineRef makeLine(const char *utf8, const char *fontName, CGFloat size, const CGFloat *rgba, CGFloat kern) {
    CFMutableAttributedStringRef as = CFAttributedStringCreateMutable(NULL, 0); append(as, utf8, fontName, size, rgba, kern); CTLineRef l = CTLineCreateWithAttributedString(as); CFRelease(as); return l;
}
static CGFloat widthOf(CTLineRef l) { return (CGFloat)CTLineGetTypographicBounds(l, NULL, NULL, NULL); }
static void showLine(CGContextRef c, CTLineRef l, CGFloat x, CGFloat baseline, CGFloat width, int align) {   // align 0 left, 1 centre, 2 right; truncates past width
    CTLineRef use = (CTLineRef)CFRetain(l);
    if (width > 0 && widthOf(l) > width) {
        CFArrayRef runs = CTLineGetGlyphRuns(l); CFDictionaryRef attrs = CFArrayGetCount(runs) ? CTRunGetAttributes((CTRunRef)CFArrayGetValueAtIndex(runs, 0)) : NULL;
        CFStringRef dots = CFStringCreateWithCString(NULL, "\xE2\x80\xA6", kCFStringEncodingUTF8); CFAttributedStringRef tok = CFAttributedStringCreate(NULL, dots, attrs);
        CTLineRef t = CTLineCreateWithAttributedString(tok), cut = CTLineCreateTruncatedLine(l, width, kCTLineTruncationEnd, t);
        CFRelease(t); CFRelease(tok); CFRelease(dots); if (cut) { CFRelease(use); use = cut; }
    }
    CGFloat w = widthOf(use); if (align == 1) x -= w / 2; else if (align == 2) x -= w;
    CGContextSetTextMatrix(c, CGAffineTransformMakeScale(1, -1)); CGContextSetTextPosition(c, round(x * 2) / 2, baseline); CTLineDraw(use, c); CFRelease(use);
}
static void text(CGContextRef c, const char *s, const char *fontName, CGFloat size, const CGFloat *rgba, CGFloat kern, CGFloat x, CGFloat baseline, CGFloat width, int align) {
    CTLineRef l = makeLine(s, fontName, size, rgba, kern); showLine(c, l, x, baseline, width, align); CFRelease(l);
}
static CGFloat fitSize(const char *s, const char *fontName, CGFloat size, CGFloat kern, CGFloat width) {   // the largest size up to `size` that fits
    static const CGFloat k[4] = { 0, 0, 0, 1 };
    for (;;) { CTLineRef l = makeLine(s, fontName, size, k, kern); CGFloat w = widthOf(l); CFRelease(l); if (w <= width || size < 7) return size; size *= 0.93; }
}
static void letterpress(CGContextRef c, const char *s, const char *fontName, CGFloat size, const CGFloat *ink, CGFloat kern, CGFloat x, CGFloat baseline, CGFloat width, int align) {
    static const CGFloat lit[4] = { 1, 0.97, 0.88, 0.55 };   // pressed into the wood: a lit lower lip
    text(c, s, fontName, size, lit, kern, x, baseline + 1, width, align); text(c, s, fontName, size, ink, kern, x, baseline, width, align);
}

#pragma mark - honey oak

// One field of flow for the whole board so the grain lines run together rather than crossing.
typedef struct { CGFloat L, a1, w1, p1, k1, a2, w2, p2, k2; } Flow;
static CGFloat flowAt(const Flow *f, CGFloat x, CGFloat y) { return f->a1 * sin(2 * M_PI * x / f->w1 + f->p1 + y * f->k1) + f->a2 * sin(2 * M_PI * x / f->w2 + f->p2 + y * f->k2); }
static void grainLine(CGMutablePathRef p, const Flow *f, CGFloat y, CGFloat jitter, CGFloat jp) {
    for (CGFloat x = -6; ; x += 8) {
        CGFloat yy = y + flowAt(f, x, y) + jitter * sin(2 * M_PI * x / f->L * 2 + jp);
        if (x < -5) CGPathMoveToPoint(p, NULL, x, yy); else CGPathAddLineToPoint(p, NULL, x, yy);
        if (x > f->L + 6) break;
    }
}
static void grainLayer(CGContextRef c, const Flow *f, uint32_t *s, int n, CGFloat H, CGFloat r, CGFloat g, CGFloat b, CGFloat a0, CGFloat a1, CGFloat w0, CGFloat w1, CGFloat jitter) {
    CGMutablePathRef p[9]; for (int i = 0; i < 9; i++) p[i] = CGPathCreateMutable();   // three tones by three widths, each stroked once
    for (int i = 0; i < n; i++) grainLine(p[rnd(s) % 9], f, fr(s, -6, H + 6), fr(s, 0, jitter), fr(s, 0, 6.3));
    for (int i = 0; i < 9; i++) { stroke(c, r, g, b, a0 + (a1 - a0) * (i / 3 + 0.5) / 3, w0 + (w1 - w0) * (i % 3 + 0.5) / 3); CGContextAddPath(c, p[i]); CGContextStrokePath(c); CGPathRelease(p[i]); }
}
static void oakBoard(CGContextRef c, CGFloat L, CGFloat H, uint32_t seed, int vertical) {   // L along the grain, H across it
    uint32_t s = mix(seed);
    CGFloat base[] = { 0.94, 0.81, 0.59, 1,  0.96, 0.85, 0.64, 1,  0.92, 0.77, 0.54, 1 }, locs[] = { 0, 0.45, 1 };
    gradient(c, CGPointMake(0, 0), CGPointMake(0, H), 3, base, locs);
    Flow f = { L, fr(&s, 1.5, 4), vertical ? L : fr(&s, 500, 1100), fr(&s, 0, 6.3), fr(&s, 0.004, 0.02), fr(&s, 0.3, 1.2), vertical ? L / (2 + (int)fr(&s, 0, 2)) : fr(&s, 180, 400), fr(&s, 0, 6.3), fr(&s, 0.01, 0.05) };   // a vertical board's waves divide its length, so it tiles
    CGContextSetLineCap(c, kCGLineCapRound);
    grainLayer(c, &f, &s, H / 6, H, 0.86, 0.66, 0.39, 0.06, 0.16, 2, 9, 1.5);      // growth bands
    grainLayer(c, &f, &s, H / 1.6, H, 0.68, 0.47, 0.25, 0.06, 0.24, 0.3, 1.1, 1.2);  // fine grain
    grainLayer(c, &f, &s, H / 5, H, 1.0, 0.95, 0.83, 0.10, 0.25, 0.4, 1.4, 1.0);     // pale figure
    CGMutablePathRef pores[3]; for (int k = 0; k < 3; k++) pores[k] = CGPathCreateMutable();
    for (int i = 0; i < L * H / 36; i++) {   // pores, wrapping at the ends
        CGFloat x = fr(&s, 0, L), y0 = fr(&s, 0, H), y = y0 + flowAt(&f, x, y0), len = fr(&s, 1.2, 4.5); CGMutablePathRef p = pores[rnd(&s) % 3];
        CGPathAddRect(p, NULL, CGRectMake(x, y, len, 0.45)); if (x + len > L) CGPathAddRect(p, NULL, CGRectMake(x - L, y, len, 0.45));
    }
    for (int k = 0; k < 3; k++) { fill(c, 0.52, 0.34, 0.16, 0.12 + 0.08 * k); CGContextAddPath(c, pores[k]); CGContextFillPath(c); CGPathRelease(pores[k]); }
}
void CDDrawOak(CGContextRef c, CGRect r, uint32_t seed, int vertical) {
    // The grain is drawn at a pixel per point and scaled up, a quarter of the work on a Retina screen (a full screen of it
    // took over a second on the A4); the specks laid over it afterwards are at full resolution and keep the wood crisp.
    size_t w = (size_t)ceil(r.size.width), h = (size_t)ceil(r.size.height); if (!w || !h) return;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGContextRef b = CGBitmapContextCreate(NULL, w, h, 8, w * 4, cs, kCGImageAlphaPremultipliedLast);
    CGContextTranslateCTM(b, 0, h); CGContextScaleCTM(b, 1, -1);
    if (vertical) { CGContextTranslateCTM(b, w, 0); CGContextRotateCTM(b, M_PI / 2); oakBoard(b, h, w, seed, 1); } else oakBoard(b, w, h, seed, 0);
    CGImageRef img = CGBitmapContextCreateImage(b); drawImage(c, r, img); CGImageRelease(img); CGContextRelease(b); CGColorSpaceRelease(cs);
    noise(c, r, seed, 0.06);
}
void CDDrawVignette(CGContextRef c, CGRect r) {   // the lamp lights the middle of the desk
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGFloat k[] = { 0.35, 0.18, 0.04, 0,  0.35, 0.18, 0.04, 0.04,  0.35, 0.18, 0.04, 0.20 }, l[] = { 0, 0.55, 1 };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, k, l, 3); CGPoint m = CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r) - r.size.height * 0.1);
    CGContextSaveGState(c); CGContextClipToRect(c, r); CGContextDrawRadialGradient(c, g, m, 0, m, hypot(r.size.width, r.size.height) * 0.62, kCGGradientDrawsAfterEndLocation); CGContextRestoreGState(c);
    CGGradientRelease(g); CGColorSpaceRelease(cs);
}

#pragma mark - raspberry book cloth

void CDDrawCloth(CGContextRef c, CGRect r) {
    CGContextSaveGState(c); CGContextClipToRect(c, r);
    CGFloat g[] = { 0.83, 0.27, 0.46, 1,  0.74, 0.18, 0.37, 1,  0.64, 0.13, 0.31, 1 }, l[] = { 0, 0.5, 1 };
    gradient(c, r.origin, CGPointMake(r.origin.x, CGRectGetMaxY(r)), 3, g, l);
    // the weave, pixel by pixel: threads of slightly uneven thickness going over and under each other
    CGFloat sc = scaleOf(c); size_t w = (size_t)ceil(r.size.width * sc), h = (size_t)ceil(r.size.height * sc), t = (size_t)(1.5 * sc + 0.5);
    unsigned char *px = malloc(w * h), *weft = malloc(h / t + 2), *warp = malloc(w / t + 2); uint32_t s = 77;
    for (size_t i = 0; i < h / t + 2; i++) weft[i] = 108 + rnd(&s) % 40;
    for (size_t i = 0; i < w / t + 2; i++) warp[i] = 108 + rnd(&s) % 40;
    for (size_t y = 0; y < h; y++) for (size_t x = 0; x < w; x++) {
        size_t ty = y / t, tx = x / t; int over = (tx + ty) & 1, v = over ? weft[ty] : warp[tx];
        if ((over ? y : x) % t == 0) v -= 26; else if ((over ? y : x) % t == t - 1) v += 10;   // the gap between threads, the crown of each
        v += (int)(rnd(&s) % 13) - 6; px[y * w + x] = (unsigned char)(v < 0 ? 0 : v > 255 ? 255 : v);
    }
    CGColorSpaceRef gs = CGColorSpaceCreateDeviceGray(); CGDataProviderRef dp = CGDataProviderCreateWithData(NULL, px, w * h, NULL);
    CGImageRef img = CGImageCreate(w, h, 8, 8, w, gs, kCGImageAlphaNone, dp, NULL, false, kCGRenderingIntentDefault);
    CGContextSaveGState(c); CGContextSetBlendMode(c, kCGBlendModeOverlay); CGContextSetAlpha(c, 0.4); CGContextDrawImage(c, r, img); CGContextRestoreGState(c);   // one bar, once: the blend's cost is fine here
    CGImageRelease(img); CGDataProviderRelease(dp); CGColorSpaceRelease(gs); free(px); free(weft); free(warp);
    fill(c, 1, 0.82, 0.89, 0.40); CGContextFillRect(c, CGRectMake(r.origin.x, r.origin.y, r.size.width, 0.5));                // the lit top edge
    fill(c, 0.30, 0.03, 0.11, 0.80); CGContextFillRect(c, CGRectMake(r.origin.x, CGRectGetMaxY(r) - 0.5, r.size.width, 0.5));  // and the hairline under it
    CGContextRestoreGState(c);
}

#pragma mark - paper and index cards

static void paper(CGContextRef c, CGPathRef p, CGRect r, uint32_t seed, const CGFloat *tone, CGFloat fibre) {
    fill(c, tone[0], tone[1], tone[2], 1); fillPath(c, p);
    CGContextSaveGState(c); CGContextAddPath(c, p); CGContextClip(c);
    CGFloat v[] = { 1, 1, 1, 0.22,  1, 1, 1, 0,  0.6, 0.5, 0.3, 0.05 }, vl[] = { 0, 0.55, 1 };   // lit from above, a touch aged at the edges
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGGradientRef g = CGGradientCreateWithColorComponents(cs, v, vl, 3);
    CGContextDrawRadialGradient(c, g, CGPointMake(CGRectGetMidX(r), r.origin.y + r.size.height * 0.3), 0, CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r)), hypot(r.size.width, r.size.height) * 0.6, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(g); CGColorSpaceRelease(cs);
    uint32_t s = mix(seed); CGContextSetLineCap(c, kCGLineCapRound); CGMutablePathRef fib[3]; for (int k = 0; k < 3; k++) fib[k] = CGPathCreateMutable();
    for (int i = 0; i < r.size.width * r.size.height / 70 * fibre; i++) {   // fibres
        CGFloat x = r.origin.x + fr(&s, 0, r.size.width), y = r.origin.y + fr(&s, 0, r.size.height), a = fr(&s, 0, 6.3), len = fr(&s, 2, 8); CGMutablePathRef q = fib[rnd(&s) % 3];
        CGPathMoveToPoint(q, NULL, x, y); CGPathAddQuadCurveToPoint(q, NULL, x + cos(a + 0.6) * len * 0.5, y + sin(a + 0.6) * len * 0.5, x + cos(a) * len, y + sin(a) * len);
    }
    for (int k = 0; k < 3; k++) { stroke(c, 0.50, 0.45, 0.36, 0.04 + 0.025 * k, 0.25 + 0.08 * k); CGContextAddPath(c, fib[k]); CGContextStrokePath(c); CGPathRelease(fib[k]); }
    noise(c, r, seed + 1, 0.035);
    CGContextRestoreGState(c);
}
static void cardShadow(CGContextRef c, CGRect r) {
    CGFloat k = r.size.width / CD_CARD_W; CGPathRef path = rounded(r, fmax(0.8, 1.5 * k));
    CGContextSaveGState(c); castShadow(c, 0.6 + 1.2 * k, 1.5 + 2.5 * k, 0.40); fill(c, 1, 1, 1, 1); fillPath(c, path); CGContextRestoreGState(c); CGPathRelease(path);
}
static void cardFace(CGContextRef c, CGRect r, uint32_t seed, int ruled) {
    CGFloat k = r.size.width / CD_CARD_W; CGPathRef path = rounded(r, fmax(0.8, 1.5 * k)); static const CGFloat tone[] = { 0.995, 0.986, 0.955 };
    paper(c, path, r, seed, tone, k > 0.6 ? 1 : 0.5);
    if (ruled) {   // one red line under the heading, blue lines below it
        CGFloat y = hair(r.origin.y + CD_CARD_HEADER * k); stroke(c, 0.86, 0.32, 0.38, 0.80, k > 0.6 ? 1.0 : 0.5); line(c, r.origin.x, y, CGRectGetMaxX(r), y);
        stroke(c, 0.42, 0.60, 0.86, k > 0.6 ? 0.55 : 0.42, 0.5); CGContextBeginPath(c);
        for (CGFloat yy = r.origin.y + CD_CARD_FIRST_RULE * k; yy < CGRectGetMaxY(r) - 8 * k; yy += CD_CARD_RULE * k) { CGContextMoveToPoint(c, r.origin.x, hair(yy)); CGContextAddLineToPoint(c, CGRectGetMaxX(r), hair(yy)); }
        CGContextStrokePath(c);
    }
    stroke(c, 0.70, 0.66, 0.58, 0.50, 0.5); CGContextAddPath(c, path); CGContextStrokePath(c); CGPathRelease(path);
}
void CDDrawIndexCard(CGContextRef c, CGRect r, uint32_t seed, int ruled) { cardShadow(c, r); cardFace(c, r, seed, ruled); }

#pragma mark - stacks of cards

#define STACK_CARD_W 118
#define STACK_CARD_H 75
static void stackPose(uint32_t seed, int i, int n, CGPoint *off, CGFloat *deg) {   // the lower cards fan out a little; the top one sits nearly square
    uint32_t s = mix(seed * 31 + i); CGFloat sign = i % 2 ? 1 : -1;
    if (i == n - 1) { *deg = fr(&s, -1.5, 1.5); *off = CGPointMake(fr(&s, -1, 1), 0); return; }
    *deg = sign * fr(&s, 2.5, 6.5); *off = CGPointMake(sign * fr(&s, 0.5, 3), fr(&s, 1, 3.5));
}
CGRect CDStackTopCard(CGRect r, uint32_t seed) { CGPoint o; CGFloat d; stackPose(seed, 3, 4, &o, &d); return CGRectMake(CGRectGetMidX(r) + o.x - STACK_CARD_W / 2.0, r.origin.y + 58 + o.y - STACK_CARD_H / 2.0, STACK_CARD_W, STACK_CARD_H); }
static CGImageRef stackCard(CGFloat sc, int ruled) {   // one card face at stack size, drawn once and shared by every stack
    static CGImageRef made[2]; static dispatch_once_t once[2];
    dispatch_once(&once[ruled], ^{
        size_t w = (size_t)(STACK_CARD_W * sc), h = (size_t)(STACK_CARD_H * sc); CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGContextRef b = CGBitmapContextCreate(NULL, w, h, 8, w * 4, cs, kCGImageAlphaPremultipliedLast); CGContextTranslateCTM(b, 0, h); CGContextScaleCTM(b, sc, -sc);
        cardFace(b, CGRectMake(0, 0, STACK_CARD_W, STACK_CARD_H), 70 + ruled, ruled); made[ruled] = CGBitmapContextCreateImage(b); CGContextRelease(b); CGColorSpaceRelease(cs);
    });
    return made[ruled];
}
void CDDrawStack(CGContextRef c, CGRect r, uint32_t seed, int n) {
    if (n < 1) n = 1; if (n > 4) n = 4; CGFloat sc = scaleOf(c);
    for (int i = 0; i < n; i++) {
        CGPoint o; CGFloat d; stackPose(seed, i + (4 - n), 4, &o, &d); CGRect card = CGRectMake(-STACK_CARD_W / 2.0, -STACK_CARD_H / 2.0, STACK_CARD_W, STACK_CARD_H);
        CGContextSaveGState(c); CGContextTranslateCTM(c, CGRectGetMidX(r) + o.x, r.origin.y + 58 + o.y); CGContextRotateCTM(c, d * M_PI / 180);
        cardShadow(c, card); drawImage(c, card, stackCard(sc, i == n - 1));
        CGContextRestoreGState(c);
    }
}
CGSize CDBadgeSize(const char *t) { static const CGFloat k[4] = { 1, 1, 1, 1 }; CTLineRef l = makeLine(t, HELV_BOLD, 14, k, 0); CGSize s = CGSizeMake(fmax(28, ceil(widthOf(l)) + 18), 28); CFRelease(l); return s; }
void CDDrawBadge(CGContextRef c, CGRect r, const char *t) {
    CGRect pill = CGRectInset(r, 2, 2); pill.size.height -= 1; CGPathRef outer = rounded(pill, pill.size.height / 2);
    CGContextSaveGState(c); castShadow(c, 1, 1.5, 0.5); fill(c, 1, 1, 1, 1); fillPath(c, outer); CGContextRestoreGState(c);   // the white rim
    CGRect in = CGRectInset(pill, 2, 2); CGPathRef inner = rounded(in, in.size.height / 2);
    CGContextSaveGState(c); CGContextAddPath(c, inner); CGContextClip(c);
    CGFloat red[] = { 0.96, 0.33, 0.33, 1,  0.86, 0.06, 0.07, 1,  0.74, 0.00, 0.02, 1 }, rl[] = { 0, 0.5, 1 };
    gradient(c, in.origin, CGPointMake(in.origin.x, CGRectGetMaxY(in)), 3, red, rl);
    CGFloat gloss[] = { 1, 1, 1, 0.55,  1, 1, 1, 0.08 }, gl[] = { 0, 1 }; CGPathRef top = rounded(CGRectMake(in.origin.x + 1, in.origin.y + 0.5, in.size.width - 2, in.size.height * 0.5), in.size.height * 0.25);
    CGContextAddPath(c, top); CGContextClip(c); gradient(c, in.origin, CGPointMake(in.origin.x, CGRectGetMidY(in)), 2, gloss, gl); CGPathRelease(top);
    CGContextRestoreGState(c);
    static const CGFloat white[4] = { 1, 1, 1, 1 }; text(c, t, HELV_BOLD, 14, white, 0, CGRectGetMidX(in), CGRectGetMidY(in) + 5, 0, 1);
    CGPathRelease(inner); CGPathRelease(outer);
}
void CDDrawSectionHeader(CGContextRef c, CGRect r, const char *title) {   // like a collection's name in iBooks: letterpressed, between engraved hairlines
    static const CGFloat ink[4] = { 0.36, 0.22, 0.08, 0.85 }, k[4] = { 0, 0, 0, 1 };
    CTLineRef l = makeLine(title, HELV_BOLD, 12, k, 1.4); CGFloat w = fmin(widthOf(l), r.size.width - 80), mid = CGRectGetMidX(r), y = hair(CGRectGetMidY(r)); CFRelease(l);
    letterpress(c, title, HELV_BOLD, 12, ink, 1.4, mid, CGRectGetMidY(r) + 4.5, r.size.width - 80, 1);
    for (int side = 0; side < 2; side++) {
        CGFloat x0 = side ? mid + w / 2 + 12 : r.origin.x + 12, x1 = side ? CGRectGetMaxX(r) - 12 : mid - w / 2 - 12;
        stroke(c, 0.40, 0.25, 0.10, 0.35, 0.5); line(c, x0, y, x1, y); stroke(c, 1, 0.97, 0.88, 0.55, 0.5); line(c, x0, y + 0.5, x1, y + 0.5);
    }
}
void CDDrawCountTab(CGContextRef c, CGRect r, long fresh, long learning, long due) {
    CGRect p = CGRectInset(r, 3, 3); p.origin.y = floor(p.origin.y); CGPathRef path = rounded(p, 1.5); static const CGFloat tone[] = { 0.99, 0.975, 0.92 };
    CGContextSaveGState(c); castShadow(c, 1, 2, 0.4); fill(c, 1, 1, 1, 1); fillPath(c, path); CGContextRestoreGState(c);
    paper(c, path, p, 9, tone, 0.5); stroke(c, 0.70, 0.66, 0.58, 0.45, 0.5); CGContextAddPath(c, path); CGContextStrokePath(c); CGPathRelease(path);
    char a[32], b[32], d[32]; snprintf(a, sizeof a, "%ld new", fresh); snprintf(b, sizeof b, "%ld learning", learning); snprintf(d, sizeof d, "%ld due", due);
    CFMutableAttributedStringRef as = CFAttributedStringCreateMutable(NULL, 0); static const CGFloat dot[4] = { 0.55, 0.53, 0.50, 1 };
    append(as, a, HELV_BOLD, 12, INK[InkBlue], 0); append(as, "   \xC2\xB7   ", HELV, 12, dot, 0);
    append(as, b, HELV_BOLD, 12, INK[InkRed], 0); append(as, "   \xC2\xB7   ", HELV, 12, dot, 0); append(as, d, HELV_BOLD, 12, INK[InkGreen], 0);
    CTLineRef l = CTLineCreateWithAttributedString(as); showLine(c, l, CGRectGetMidX(p), CGRectGetMidY(p) + 4.5, p.size.width - 10, 1); CFRelease(l); CFRelease(as);
}

#pragma mark - rubber stamps

typedef struct { int rating; CGFloat size; } StampArt;
static void paintImpression(CGContextRef c, CGRect r, const void *arg) {   // a double border and the word, in the stamp's ink
    const StampArt *a = arg; const CGFloat *ink = INK[STAMP_INK[a->rating]]; CGFloat k[4] = { ink[0], ink[1], ink[2], 1 };
    CGRect o = CGRectInset(r, 1.5, 1.5); CGPathRef p = rounded(o, 3); stroke(c, k[0], k[1], k[2], 1, fmax(1, a->size * 0.08)); CGContextAddPath(c, p); CGContextStrokePath(c); CGPathRelease(p);
    p = rounded(CGRectInset(o, a->size * 0.2, a->size * 0.2), 2); stroke(c, k[0], k[1], k[2], 1, 0.75); CGContextAddPath(c, p); CGContextStrokePath(c); CGPathRelease(p);
    CGFloat size = fitSize(STAMP_WORD[a->rating], HELV_BOLD, a->size, a->size * 0.12, r.size.width - a->size * 0.8);
    text(c, STAMP_WORD[a->rating], HELV_BOLD, size, k, size * 0.12, CGRectGetMidX(r), CGRectGetMidY(r) + size * 0.36, 0, 1);
}
void CDDrawImpression(CGContextRef c, CGRect r, int rating, uint32_t seed) {
    StampArt a = { rating, r.size.height * 0.46 }; CGContextSaveGState(c); CGContextSetAlpha(c, INK[STAMP_INK[rating]][3]); distressed(c, r, seed, 0.38, paintImpression, &a); CGContextRestoreGState(c);
}
void CDDrawStamp(CGContextRef c, CGRect r, int rating, int pressed) {
    // a wooden stamp mount seen from above, a proof of its impression pasted on top; the block's front face shows below
    CGFloat sink = pressed ? 3 : 0, depth = pressed ? 5 : 8;
    CGRect top = CGRectMake(r.origin.x + 2, r.origin.y + 1 + sink, r.size.width - 4, r.size.height - 13), side = CGRectMake(top.origin.x, CGRectGetMaxY(top), top.size.width, depth);
    CGPathRef block = rounded(CGRectUnion(top, side), 3);
    CGContextSaveGState(c); castShadow(c, pressed ? 1 : 2.5, pressed ? 1.5 : 3.5, 0.45); fill(c, 0.7, 0.5, 0.3, 1); fillPath(c, block); CGContextRestoreGState(c);
    CGContextSaveGState(c); CGContextAddPath(c, block); CGContextClip(c);
    CDDrawOak(c, CGRectUnion(top, side), 40 + rating, 0);
    CGFloat sh[] = { 0.45, 0.27, 0.10, 0.30,  0.40, 0.22, 0.06, 0.45 }, sl[] = { 0, 1 };   // the front face, turned away from the light
    CGContextSaveGState(c); CGContextClipToRect(c, side); gradient(c, side.origin, CGPointMake(side.origin.x, CGRectGetMaxY(side)), 2, sh, sl); CGContextRestoreGState(c);
    fill(c, 1, 0.97, 0.88, 0.55); CGContextFillRect(c, CGRectMake(top.origin.x, top.origin.y, top.size.width, 0.5));   // 1px of light on the top edge
    fill(c, 0.35, 0.20, 0.06, 0.30); CGContextFillRect(c, CGRectMake(side.origin.x, side.origin.y, side.size.width, 0.5));
    CGContextRestoreGState(c);
    stroke(c, 0.40, 0.24, 0.08, 0.45, 0.5); CGContextAddPath(c, block); CGContextStrokePath(c); CGPathRelease(block);
    CGRect label = CGRectInset(top, 5, 4.5); CGPathRef lp = rounded(label, 1); static const CGFloat tone[] = { 0.995, 0.98, 0.94 };
    CGContextSaveGState(c); castShadow(c, 0.5, 0.6, 0.3); fill(c, 1, 1, 1, 1); fillPath(c, lp); CGContextRestoreGState(c);
    paper(c, lp, label, 60 + rating, tone, 0.3); CGPathRelease(lp);
    const CGFloat *ink = INK[STAMP_INK[rating]]; CGRect proof = CGRectMake(label.origin.x + 4, label.origin.y + 4, label.size.width - 8, label.size.height - 19);
    CGPathRef pp = rounded(proof, 2); stroke(c, ink[0], ink[1], ink[2], 0.85, 0.75); CGContextAddPath(c, pp); CGContextStrokePath(c); CGPathRelease(pp);
    CGFloat size = fitSize(STAMP_WORD[rating], HELV_BOLD, 12, 1, proof.size.width - 6);
    text(c, STAMP_WORD[rating], HELV_BOLD, size, ink, 1, CGRectGetMidX(proof), CGRectGetMidY(proof) + size * 0.36, 0, 1);
}

#pragma mark - the date-due slip

#define DD_ROW 24
#define DD_PAST 6
typedef struct { const char *s; CGFloat size; } DateArt;
static void paintDate(CGContextRef c, CGRect r, const void *arg) { const DateArt *a = arg; CGFloat k[4] = { INK[InkViolet][0], INK[InkViolet][1], INK[InkViolet][2], 1 }; text(c, a->s, HELV_BOLD, a->size, k, 1.2, CGRectGetMidX(r), CGRectGetMidY(r) + a->size * 0.36, 0, 1); }
static void dateStamp(CGContextRef c, CGFloat cx, CGFloat cy, const char *s, uint32_t seed) {
    uint32_t q = mix(seed); DateArt a = { s, 12 }; CGRect r = CGRectMake(-52, -11, 104, 22);
    CGContextSaveGState(c); CGContextTranslateCTM(c, cx + fr(&q, -2, 2), cy); CGContextRotateCTM(c, fr(&q, -1.5, 1.5) * M_PI / 180); CGContextSetAlpha(c, INK[InkViolet][3]);
    distressed(c, r, seed, 0.3, paintDate, &a); CGContextRestoreGState(c);
}
static void tally(CGContextRef c, CGFloat x, CGFloat base, int n) {   // pencil strokes in fives
    stroke(c, INK[InkPencil][0], INK[InkPencil][1], INK[InkPencil][2], 0.7, 1); CGContextSetLineCap(c, kCGLineCapRound);
    for (int i = 0; i < n && i < 15; i++) {
        int g = i / 5, k = i % 5; CGFloat gx = x + g * 24;
        if (k < 4) line(c, gx + k * 4.5, base - 11, gx + k * 4.5, base); else line(c, gx - 2.5, base - 2.5, gx + 16, base - 9);
    }
}
CGFloat CDDateDueHeight(const CDStatsData *d) { return 16 + 58 + 16 + DD_PAST * DD_ROW + 28 + 7 * DD_ROW + 8 + 232 + 20; }
void CDDrawDateDue(CGContextRef c, CGFloat width, const CDStatsData *d) {
    static const CGFloat tone[] = { 0.995, 0.98, 0.94 }, black[4] = { 0.15, 0.14, 0.16, 0.95 }, grey[4] = { 0.45, 0.44, 0.47, 1 }, rule[4] = { 0.50, 0.58, 0.78, 0.45 };
    CGFloat sx = 34, sw = width - 68, top = 16, colX = sx + floor(sw * 0.5);
    CGFloat rowsY = top + 58 + 16, nextY = rowsY + DD_PAST * DD_ROW + 28, pocketY = nextY + 7 * DD_ROW + 8;
    // the slip, its foot hidden in the pocket
    CGRect slip = CGRectMake(sx, top, sw, pocketY + 50 - top); CGPathRef sp = rounded(slip, 1);
    CGContextSaveGState(c); castShadow(c, 1.5, 3, 0.35); fill(c, 1, 1, 1, 1); fillPath(c, sp); CGContextRestoreGState(c);
    paper(c, sp, slip, 31, tone, 0.6); CGPathRelease(sp);
    text(c, "DATE DUE", HELV_BOLD, 20, black, 4, CGRectGetMidX(slip) + 2, top + 37, 0, 1);
    stroke(c, black[0], black[1], black[2], 0.8, 1); line(c, sx + 12, top + 48.5, sx + sw - 12, top + 48.5);
    stroke(c, black[0], black[1], black[2], 0.8, 0.5); line(c, sx + 12, hair(top + 51), sx + sw - 12, hair(top + 51));
    text(c, "STUDIED", HELV_BOLD, 8, grey, 1.2, (sx + colX) / 2, rowsY - 5, 0, 1); text(c, "ANSWERED", HELV_BOLD, 8, grey, 1.2, (colX + sx + sw) / 2, rowsY - 5, 0, 1);
    stroke(c, rule[0], rule[1], rule[2], rule[3], 0.5); CGContextBeginPath(c);
    for (int i = 0; i <= DD_PAST; i++) { CGContextMoveToPoint(c, sx, hair(rowsY + i * DD_ROW)); CGContextAddLineToPoint(c, sx + sw, hair(rowsY + i * DD_ROW)); }
    for (int i = 0; i <= 7; i++) { CGContextMoveToPoint(c, sx, hair(nextY + i * DD_ROW)); CGContextAddLineToPoint(c, sx + sw, hair(nextY + i * DD_ROW)); }
    CGContextMoveToPoint(c, colX + 0.25, rowsY - 14); CGContextAddLineToPoint(c, colX + 0.25, rowsY + DD_PAST * DD_ROW); CGContextMoveToPoint(c, colX + 0.25, nextY); CGContextAddLineToPoint(c, colX + 0.25, nextY + 7 * DD_ROW);
    CGContextStrokePath(c);
    int from = d->npast > DD_PAST ? d->npast - DD_PAST : 0; char buf[64];
    for (int i = from; i < d->npast; i++) {
        CGFloat y = rowsY + (i - from) * DD_ROW; dateStamp(c, (sx + colX) / 2, y + DD_ROW / 2, d->pastDay[i], 200 + i);
        snprintf(buf, sizeof buf, "%d", d->pastAnswers[i]); text(c, buf, HELV, 13, black, 0, (colX + sx + sw) / 2, y + 17, 0, 1);
    }
    if (!d->npast) text(c, "Not yet", HELV, 12, grey, 0, (sx + colX) / 2, rowsY + 17, 0, 1);
    text(c, "COMING DUE", HELV_BOLD, 9, black, 2, CGRectGetMidX(slip) + 1, nextY - 9, 0, 1);
    for (int i = 0; i < 7; i++) {
        CGFloat y = nextY + i * DD_ROW; dateStamp(c, (sx + colX) / 2, y + DD_ROW / 2, d->nextDay[i], 300 + i);
        if (d->nextDue[i]) { tally(c, colX + 12, y + 17.5, d->nextDue[i]); snprintf(buf, sizeof buf, "%d", d->nextDue[i]); text(c, buf, HELV, 13, black, 0, sx + sw - 10, y + 17, 0, 2); }
        else text(c, "\xE2\x80\x94", HELV, 12, grey, 0, (colX + sx + sw) / 2, y + 17, 0, 1);
    }
    // the manila pocket, with a thumb notch to pull the slip by
    CGRect pk = CGRectMake(18, pocketY, width - 36, 232); CGFloat nx = CGRectGetMidX(pk), nr = 15;
    CGMutablePathRef pp = CGPathCreateMutable(); CGPathMoveToPoint(pp, NULL, pk.origin.x, pk.origin.y); CGPathAddLineToPoint(pp, NULL, nx - nr, pk.origin.y);
    CGPathAddArc(pp, NULL, nx, pk.origin.y, nr, M_PI, 0, true); CGPathAddLineToPoint(pp, NULL, CGRectGetMaxX(pk), pk.origin.y);
    CGPathAddLineToPoint(pp, NULL, CGRectGetMaxX(pk), CGRectGetMaxY(pk) - 2); CGPathAddArcToPoint(pp, NULL, CGRectGetMaxX(pk), CGRectGetMaxY(pk), CGRectGetMaxX(pk) - 2, CGRectGetMaxY(pk), 2);
    CGPathAddArcToPoint(pp, NULL, pk.origin.x, CGRectGetMaxY(pk), pk.origin.x, CGRectGetMaxY(pk) - 2, 2); CGPathCloseSubpath(pp);
    static const CGFloat manila[] = { 0.97, 0.90, 0.72 };
    CGContextSaveGState(c); castShadow(c, 2, 4, 0.42); fill(c, 1, 1, 1, 1); fillPath(c, pp); CGContextRestoreGState(c);
    paper(c, pp, pk, 41, manila, 0.9);
    CGContextSaveGState(c); CGContextAddPath(c, pp); CGContextClip(c); fill(c, 1, 1, 1, 0.55); CGContextFillRect(c, CGRectMake(pk.origin.x, pk.origin.y, pk.size.width, 0.5)); CGContextRestoreGState(c);
    CGPathRelease(pp);
    stroke(c, RASPBERRY[0], RASPBERRY[1], RASPBERRY[2], 0.5, 1); CGContextStrokeRect(c, CGRectInset(pk, 9.5, 24.5)); stroke(c, RASPBERRY[0], RASPBERRY[1], RASPBERRY[2], 0.5, 0.5); CGContextStrokeRect(c, CGRectInset(pk, 12.25, 27.25));
    text(c, "CARDS \xC2\xB7 LENDING RECORD", HELV_BOLD, 10, RASPBERRY, 1.6, nx, pk.origin.y + 46, 0, 1);
    const char *labels[] = { "TODAY", "STREAK", "RETENTION", "IN THE FILE" }; char vals[4][2][64];
    snprintf(vals[0][0], 64, "%d answered, %d new", d->answersToday, d->newToday); snprintf(vals[0][1], 64, "%d min at the desk", d->minutesToday);
    snprintf(vals[1][0], 64, "%d day%s", d->streak, d->streak == 1 ? "" : "s"); vals[1][1][0] = 0;
    if (d->retention >= 0) snprintf(vals[2][0], 64, "%d%% of %d reviews", d->retention, d->reviews30); else snprintf(vals[2][0], 64, "No reviews yet");
    snprintf(vals[2][1], 64, "aiming for %d%%", d->target);
    snprintf(vals[3][0], 64, "%d new, %d learning", d->cardsNew, d->cardsLearning); snprintf(vals[3][1], 64, "%d young, %d mature", d->cardsYoung, d->cardsMature);
    CGFloat fy = pk.origin.y + 74, vx = pk.origin.x + 102;
    for (int i = 0; i < 4; i++) {
        text(c, labels[i], HELV_BOLD, 8.5, RASPBERRY, 1, pk.origin.x + 22, fy, 0, 0);
        CGFloat dash[2] = { 1, 2 }; CGContextSetLineDash(c, 0, dash, 2); stroke(c, RASPBERRY[0], RASPBERRY[1], RASPBERRY[2], 0.45, 0.5);
        line(c, vx - 4, hair(fy + 3), CGRectGetMaxX(pk) - 22, hair(fy + 3)); CGContextSetLineDash(c, 0, NULL, 0);
        text(c, vals[i][0], HELV, 12, black, 0, vx, fy, CGRectGetMaxX(pk) - 22 - vx, 0);
        if (vals[i][1][0]) { text(c, vals[i][1], HELV, 12, grey, 0, vx, fy + 16, CGRectGetMaxX(pk) - 22 - vx, 0); fy += 16; }
        fy += 26;
    }
}
