#import "ORTextLayout.h"

#import "ORMarkdown.h"
#import "CLPaper.h"

static NSString *const kLink=@"ORLink", *const kCode=@"ORCode", *const kQuote=@"ORQuote";
static NSDictionary *attributes(NSString *style, CGFloat size) {
    NSString *name=[style isEqual:@"code"]?@"Courier":[style isEqual:@"bold"]?@"Helvetica-Bold":[style isEqual:@"italic"]?@"Helvetica-Oblique":[style isEqual:@"bolditalic"]?@"Helvetica-BoldOblique":@"Helvetica";
    CTFontRef font=CTFontCreateWithName((CFStringRef)name,size,NULL);
    NSDictionary *result=[NSDictionary dictionaryWithObjectsAndKeys:(id)font,(id)kCTFontAttributeName,(id)CLColor([style isEqual:@"link"]?0x32658A:0x29251F).CGColor,(id)kCTForegroundColorAttributeName,nil];
    CFRelease(font);return result;
}
@implementation ORTextLayout
- (id)initWithText:(NSString *)source markdown:(BOOL)markdown width:(CGFloat)w {
    return [self initWithText:source markdown:markdown width:w fontSize:16 highlight:nil];
}
- (id)initWithText:(NSString *)source markdown:(BOOL)markdown width:(CGFloat)w fontSize:(CGFloat)fontSize highlight:(NSString *)query {
    if ((self=[super init])) {
        width=MAX(40,w); NSMutableAttributedString *out=[[[NSMutableAttributedString alloc] init] autorelease];
        NSArray *blocks=markdown?[ORMarkdown blocks:source]:[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"paragraph",@"kind",[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:source?:@"",@"text",@"normal",@"style",nil]],@"runs",nil]];
        NSMutableArray *segments=[NSMutableArray array];
        fontSize=MIN(21,MAX(13,fontSize));
        for(NSDictionary *b in blocks) {
            NSString *kind=[b objectForKey:@"kind"];BOOL wide=[kind isEqual:@"code"] || [kind isEqual:@"table"],code=wide,quote=[kind isEqual:@"quote"],heading=[kind isEqual:@"heading"];
            NSUInteger start=[out length];CGFloat size=code?fontSize-2:heading?MAX(fontSize+1,fontSize+8-[[b objectForKey:@"level"] intValue]*2):fontSize;
            NSString *prefix=[b objectForKey:@"prefix"];
            if([prefix length]) [out appendAttributedString:[[[NSAttributedString alloc] initWithString:[prefix stringByAppendingString:@" "] attributes:attributes(@"normal",fontSize)] autorelease]];
            if([kind isEqual:@"rule"]) [out appendAttributedString:[[[NSAttributedString alloc] initWithString:@"──────────────" attributes:attributes(@"normal",13)] autorelease]];
            for(NSDictionary *run in [b objectForKey:@"runs"]) {
                NSString *style=code?@"code":heading?@"bold":[run objectForKey:@"style"];
                NSMutableDictionary *a=[NSMutableDictionary dictionaryWithDictionary:attributes(style,size)];
                if([[run objectForKey:@"url"] length]) { [a setObject:[run objectForKey:@"url"] forKey:kLink];[a setObject:[NSNumber numberWithInt:1] forKey:(id)kCTUnderlineStyleAttributeName]; }
                // Fenced blocks have one enclosing card; only inline code gets a glyph highlight.
                if(!wide && [style isEqual:@"code"]) [a setObject:[NSNumber numberWithBool:YES] forKey:kCode];
                if(quote) [a setObject:[NSNumber numberWithBool:YES] forKey:kQuote];
                [out appendAttributedString:[[[NSAttributedString alloc] initWithString:[run objectForKey:@"text"] attributes:a] autorelease]];
            }
            [out appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n" attributes:attributes(@"normal",fontSize)] autorelease]];
            CGFloat spacing=6,lineSpacing=3,indent=quote||code?7:0;
            if([kind isEqual:@"list"]) indent=MIN(30,10+[[b objectForKey:@"level"] integerValue]*8);
            CGFloat firstIndent=quote||code?7:MAX(0,indent-10);
            CTLineBreakMode wrap=kCTLineBreakByWordWrapping;
            CTParagraphStyleSetting settings[]={{kCTParagraphStyleSpecifierParagraphSpacing,sizeof(spacing),&spacing},{kCTParagraphStyleSpecifierLineSpacingAdjustment,sizeof(lineSpacing),&lineSpacing},{kCTParagraphStyleSpecifierHeadIndent,sizeof(indent),&indent},{kCTParagraphStyleSpecifierFirstLineHeadIndent,sizeof(firstIndent),&firstIndent},{kCTParagraphStyleSpecifierLineBreakMode,sizeof(wrap),&wrap}};
            CTParagraphStyleRef paragraph=CTParagraphStyleCreate(settings,5);
            [out addAttribute:(id)kCTParagraphStyleAttributeName value:(id)paragraph range:NSMakeRange(start,[out length]-start)];CFRelease(paragraph);
            // The inset block card has a narrower viewport than ordinary prose.
            CGFloat segmentWidth=wide?MAX(40,width-10):width;
            if(wide) { for(NSString *line in [[[out string] substringFromIndex:start] componentsSeparatedByString:@"\n"])segmentWidth=MAX(segmentWidth,MIN(2048,ceilf([line sizeWithFont:[UIFont fontWithName:@"Courier" size:size]].width)+20)); }
            NSMutableDictionary *last=[segments lastObject];
            if(!wide && [[last objectForKey:@"kind"] isEqual:@"text"]) { NSRange range=[[last objectForKey:@"range"] rangeValue];range.length=[out length]-range.location;[last setObject:[NSValue valueWithRange:range] forKey:@"range"]; }
            else [segments addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithRange:NSMakeRange(start,[out length]-start)],@"range",wide?kind:@"text",@"kind",[NSNumber numberWithFloat:segmentWidth],@"width",[b objectForKey:@"source"]?:@"",@"source",nil]];

        }
        if(![out length]) [out appendAttributedString:[[[NSAttributedString alloc] initWithString:@" " attributes:attributes(@"normal",fontSize)] autorelease]];
        if(![segments count])[segments addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithRange:NSMakeRange(0,[out length])],@"range",@"text",@"kind",[NSNumber numberWithFloat:width],@"width",nil]];
        if([query length]) { NSRange remaining=NSMakeRange(0,[out length]);while(remaining.length) { NSRange match=[[out string] rangeOfString:query options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch range:remaining];if(match.location==NSNotFound)break;[out addAttribute:@"ORHighlight" value:[NSNumber numberWithBool:YES] range:match];remaining=NSMakeRange(NSMaxRange(match),[out length]-NSMaxRange(match)); } }
        text=[out copy];framesetter=CTFramesetterCreateWithAttributedString((CFAttributedStringRef)text);
        NSMutableArray *chunks=[NSMutableArray array];
        for(NSDictionary *segment in segments) { NSRange range=[[segment objectForKey:@"range"] rangeValue];CFIndex offset=range.location;CGFloat pageWidth=[[segment objectForKey:@"width"] floatValue];
            while(offset<(CFIndex)NSMaxRange(range)) {
                CGMutablePathRef path=CGPathCreateMutable();CGPathAddRect(path,NULL,CGRectMake(0,0,pageWidth,380));
                CTFrameRef frame=CTFramesetterCreateFrame(framesetter,CFRangeMake(offset,NSMaxRange(range)-offset),path,NULL);CFRange visible=CTFrameGetVisibleStringRange(frame);
                if(visible.length==0) { CFRelease(frame);CGPathRelease(path);break; }
                CFRange fitted;CGSize size=CTFramesetterSuggestFrameSizeWithConstraints(framesetter,visible,NULL,CGSizeMake(pageWidth,10000),&fitted);
                CGFloat height=MIN(380,MAX(22,ceilf(size.height)+3));NSMutableDictionary *chunk=[NSMutableDictionary dictionaryWithDictionary:segment];[chunk setObject:[NSValue valueWithRange:NSMakeRange(visible.location,visible.length)] forKey:@"range"];[chunk setObject:[NSNumber numberWithFloat:height] forKey:@"height"];[chunks addObject:chunk];
                offset=visible.location+visible.length;CFRelease(frame);CGPathRelease(path);
            }
        }
        pages=[chunks copy];
    }return self;
}
- (void)dealloc { [text release];[pages release];if(framesetter)CFRelease(framesetter);[super dealloc]; }
- (NSUInteger)firstHighlightedPage { for(NSUInteger page=0;page<[pages count];page++) { NSRange range=[[[pages objectAtIndex:page] objectForKey:@"range"] rangeValue];NSUInteger i=range.location;while(i<NSMaxRange(range)) { NSRange effective;id value=[text attribute:@"ORHighlight" atIndex:i effectiveRange:&effective];if(value)return page;i=NSMaxRange(effective); } }return 0; }
- (NSUInteger)pageCount{return [pages count];}
- (CGFloat)heightOfPage:(NSUInteger)page{return [[[pages objectAtIndex:page] objectForKey:@"height"] floatValue];}
- (CGFloat)widthOfPage:(NSUInteger)page { return [[[pages objectAtIndex:page] objectForKey:@"width"] floatValue]; }
- (NSString *)kindOfPage:(NSUInteger)page { return [[pages objectAtIndex:page] objectForKey:@"kind"]; }
- (NSString *)sourceOfPage:(NSUInteger)page { return [[pages objectAtIndex:page] objectForKey:@"source"]; }
- (CTFrameRef)newFrame:(NSUInteger)page {
    NSRange range=[[[pages objectAtIndex:page] objectForKey:@"range"] rangeValue];
    CGMutablePathRef path=CGPathCreateMutable();CGPathAddRect(path,NULL,CGRectMake(0,0,[self widthOfPage:page],[self heightOfPage:page]));
    CTFrameRef frame=CTFramesetterCreateFrame(framesetter,CFRangeMake(range.location,range.length),path,NULL);CGPathRelease(path);return frame;
}
- (void)drawPage:(NSUInteger)page context:(CGContextRef)ctx origin:(CGPoint)origin {
    if(page>=[pages count])return;
    CGFloat height=[self heightOfPage:page];CTFrameRef frame=[self newFrame:page];
    CGContextSaveGState(ctx);CGContextTranslateCTM(ctx,origin.x,origin.y+height);CGContextScaleCTM(ctx,1,-1);CGContextSetTextMatrix(ctx,CGAffineTransformIdentity);
    CFArrayRef lines=CTFrameGetLines(frame);CFIndex count=CFArrayGetCount(lines);CGPoint *origins=calloc(MAX(count,1),sizeof(CGPoint));
    if(origins) {
        CTFrameGetLineOrigins(frame,CFRangeMake(0,0),origins);
        for(CFIndex i=0;i<count;i++) {
            CTLineRef line=CFArrayGetValueAtIndex(lines,i);CFArrayRef runs=CTLineGetGlyphRuns(line);
            for(CFIndex j=0;j<CFArrayGetCount(runs);j++) {
                CTRunRef run=CFArrayGetValueAtIndex(runs,j);NSDictionary *a=(NSDictionary *)CTRunGetAttributes(run);CGFloat ascent,descent;
                CGFloat rw=CTRunGetTypographicBounds(run,CFRangeMake(0,0),&ascent,&descent,NULL);
                CFRange range=CTRunGetStringRange(run);CGFloat x=origins[i].x+CTLineGetOffsetForStringIndex(line,range.location,NULL);
                if([a objectForKey:kCode]) { CGContextSetFillColorWithColor(ctx,CLColor(0xE2D7C3).CGColor);CGContextFillRect(ctx,CGRectMake(x-2,origins[i].y-descent-2,rw+4,ascent+descent+4)); }
                if([a objectForKey:@"ORHighlight"]) { CGContextSetFillColorWithColor(ctx,CLColor(0xF2CE75).CGColor);CGContextFillRect(ctx,CGRectMake(x-1,origins[i].y-descent-2,rw+2,ascent+descent+4)); }
                if([a objectForKey:kQuote]) { CGContextSetFillColorWithColor(ctx,CLColor(0xC4B59C).CGColor);CGContextFillRect(ctx,CGRectMake(0,origins[i].y-descent-2,2,ascent+descent+5)); }
            }
        }
        free(origins);
    }
    CTFrameDraw(frame,ctx);CGContextRestoreGState(ctx);CFRelease(frame);
}
- (NSString *)linkAtPoint:(CGPoint)p page:(NSUInteger)page {
    if(page>=[pages count])return nil;
    CTFrameRef frame=[self newFrame:page];CFArrayRef lines=CTFrameGetLines(frame);CFIndex count=CFArrayGetCount(lines);
    CGPoint *origins=calloc(MAX(count,1),sizeof(CGPoint));NSString *url=nil;
    if(origins) {
        CTFrameGetLineOrigins(frame,CFRangeMake(0,0),origins);CGFloat y=[self heightOfPage:page]-p.y;
        for(CFIndex i=0;i<count;i++) {
            CTLineRef line=CFArrayGetValueAtIndex(lines,i);CGFloat ascent,descent;double lineWidth=CTLineGetTypographicBounds(line,&ascent,&descent,NULL);
            if(y>=origins[i].y-descent-3 && y<=origins[i].y+ascent+3 && p.x>=origins[i].x && p.x<=origins[i].x+lineWidth) {
                CFIndex idx=CTLineGetStringIndexForPosition(line,CGPointMake(p.x-origins[i].x,0));
                if(idx>=0 && idx<(CFIndex)[text length])url=[text attribute:kLink atIndex:idx effectiveRange:NULL];break;
            }
        }free(origins);
    }
    CFRelease(frame);return url;
}
@end
