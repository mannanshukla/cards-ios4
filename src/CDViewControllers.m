#import "CDViewControllers.h"
#import "CDStore.h"
#import "CDSkin.h"
#import <QuartzCore/QuartzCore.h>

static NSString *leaf(NSString *deck) { return [[deck componentsSeparatedByString:@"/"] lastObject]; }
static NSString *folder(NSString *deck) { NSRange r = [deck rangeOfString:@"/" options:NSBackwardsSearch]; return r.location == NSNotFound ? @"" : [deck substringToIndex:r.location]; }
static NSString *plural(NSInteger n, NSString *one, NSString *many) { return [NSString stringWithFormat:@"%ld %@", (long)n, n == 1 ? one : many]; }
static uint32_t seedFor(NSString *s) { uint32_t h = 2166136261u; for (const char *p = [s UTF8String]; *p; p++) h = (h ^ (unsigned char)*p) * 16777619u; return h % 1000; }

#pragma mark - Stacks on the desk

static UILabel *pressedLabel(CGRect f, UIFont *font, UIColor *ink) {   // letterpress: dark ink with a lit lower lip, as the desk is lit from above
    UILabel *l = [[[UILabel alloc] initWithFrame:f] autorelease]; l.font = font; l.textColor = ink; l.backgroundColor = [UIColor clearColor]; l.textAlignment = UITextAlignmentCenter;
    l.shadowColor = [UIColor colorWithRed:1 green:0.97 blue:0.88 alpha:0.55]; l.shadowOffset = CGSizeMake(0, 1); return l;
}
static NSString *countsLine(CDCounts n) {
    NSMutableArray *parts = [NSMutableArray array];
    if (n.fresh) [parts addObject:[NSString stringWithFormat:@"%ld new", (long)n.fresh]];
    if (n.learning) [parts addObject:[NSString stringWithFormat:@"%ld learning", (long)n.learning]];
    if (n.due) [parts addObject:[NSString stringWithFormat:@"%ld due", (long)n.due]];
    if ([parts count]) return [parts componentsJoinedByString:@" · "];
    long days = n.nextDay < 0 ? -1 : n.nextDay - n.today;
    return days < 0 ? @"All done" : days == 1 ? @"Done · more tomorrow" : [NSString stringWithFormat:@"Done · more in %ld days", days];
}

@implementation CDDecksViewController
- (id)init {
    if ((self = [super init])) {
        self.title = @"Cards"; items = [[NSMutableArray alloc] init]; targets = [[NSMutableArray alloc] init];
        self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Decks" style:UIBarButtonItemStyleBordered target:nil action:nil] autorelease];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:CDStoreChanged object:nil];
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [poll invalidate]; [poll release]; [scroll release]; [items release]; [targets release]; [super dealloc]; }
- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 416)] autorelease]; self.view = v;
    scroll = [[UIScrollView alloc] initWithFrame:v.bounds]; scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scroll.backgroundColor = CDDeskColor(); scroll.alwaysBounceVertical = YES; [v addSubview:scroll]; [v addSubview:CDTopShade(320)];
}
- (void)add:(UIView *)view { [scroll addSubview:view]; [items addObject:view]; }
- (void)stack:(id)d at:(CGPoint)o {   // d is a deck name, or NSNull for every deck
    CDStore *st = [CDStore shared]; BOOL all = [d isKindOfClass:[NSNull class]]; uint32_t seed = seedFor(all ? @"*" : d);
    NSUInteger size = all ? [st cardCount] : [st cardsInDeck:d]; int cards = all ? 4 : size < 10 ? 2 : size < 40 ? 3 : 4;   // a bigger deck makes a taller stack
    CDCounts n = [st countsForDeck:all ? nil : d];
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom]; b.frame = CGRectMake(o.x, o.y, CD_STACK_W, CD_STACK_H); b.adjustsImageWhenHighlighted = NO;
    [b setImage:CDStackImage(seed, cards) forState:UIControlStateNormal];
    if (n.due) {   // the red badge on the top card's corner, as on a home screen icon
        UIImage *bi = CDBadgeImage([NSString stringWithFormat:@"%ld", (long)n.due]); CGRect top = CDStackTopCard(b.bounds, seed);
        UIImageView *badge = [[[UIImageView alloc] initWithImage:bi] autorelease]; badge.frame = CGRectMake(round(CGRectGetMaxX(top) - bi.size.width / 2 - 2), round(top.origin.y - bi.size.height / 2 + 2), bi.size.width, bi.size.height); [b addSubview:badge];
    }
    b.tag = [targets count]; [targets addObject:d];
    [b addTarget:self action:@selector(lift:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [b addTarget:self action:@selector(settle:) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    [b addTarget:self action:@selector(open:) forControlEvents:UIControlEventTouchUpInside];
    [self add:b];
    UILabel *name = pressedLabel(CGRectMake(o.x, o.y + CD_STACK_H - 3, CD_STACK_W, 19), [UIFont boldSystemFontOfSize:15], [UIColor colorWithRed:0.20 green:0.12 blue:0.04 alpha:1]); name.text = all ? @"All Decks" : leaf(d); [self add:name];
    UILabel *counts = pressedLabel(CGRectMake(o.x, o.y + CD_STACK_H + 16, CD_STACK_W, 16), [UIFont systemFontOfSize:12.5], [UIColor colorWithRed:0.33 green:0.21 blue:0.08 alpha:1]); counts.text = countsLine(n); [self add:counts];
}
- (void)viewDidUnload { [super viewDidUnload]; [items removeAllObjects]; [targets removeAllObjects]; [scroll release]; scroll = nil; }   // a memory warning while Study or Stats is up
- (void)refresh {
    if (!self.isViewLoaded) return;
    for (UIView *v in items) [v removeFromSuperview]; [items removeAllObjects]; [targets removeAllObjects];
    CDStore *st = [CDStore shared]; NSArray *decks = [st decks]; CGFloat y = 14;
    if (![st cardCount]) {   // one blank card, and what to do about it
        UIImageView *card = [[[UIImageView alloc] initWithImage:CDCardImage(YES, 1)] autorelease]; card.frame = CGRectMake(12 - CD_CARD_PAD, 40 - CD_CARD_PAD, card.image.size.width, card.image.size.height); [self add:card];
        UILabel *l = pressedLabel(CGRectMake(30, 250, 260, 60), [UIFont systemFontOfSize:15], [UIColor colorWithRed:0.30 green:0.19 blue:0.07 alpha:1]); l.numberOfLines = 0;
        l.text = @"Add Markdown files to ~/Cards on your Mac, then run cards sync with the iPod plugged in."; [self add:l];
        scroll.contentSize = CGSizeMake(320, 416); return;
    }
    NSMutableArray *folders = [NSMutableArray array];
    for (NSString *d in decks) if (![folders containsObject:folder(d)]) [folders addObject:folder(d)];
    if (![folders containsObject:@""]) [folders insertObject:@"" atIndex:0];   // every deck sits in a folder: All Decks still goes first
    for (NSString *f in folders) {
        NSMutableArray *row = [NSMutableArray array];
        if (![f length] && [decks count] > 1) [row addObject:[NSNull null]];
        for (NSString *d in decks) if ([folder(d) isEqualToString:f]) [row addObject:d];
        if (![row count]) continue;
        if ([f length]) { UIImageView *h = [[[UIImageView alloc] initWithImage:CDSectionHeaderImage([f uppercaseString])] autorelease]; h.frame = CGRectMake(0, y, 320, 26); [self add:h]; y += 34; }
        for (NSUInteger i = 0; i < [row count]; i++) { [self stack:[row objectAtIndex:i] at:CGPointMake(i % 2 ? 162 : 8, y)]; if (i % 2 || i == [row count] - 1) y += CD_STACK_H + 46; }
    }
    NSDate *d = [st syncedAt]; NSString *foot = plural([st cardCount], @"card", @"cards");
    if (d) {
        NSDateFormatter *df = [[[NSDateFormatter alloc] init] autorelease], *tf = [[[NSDateFormatter alloc] init] autorelease]; [df setDateStyle:NSDateFormatterMediumStyle]; [tf setTimeStyle:NSDateFormatterShortStyle];
        NSString *day = [df stringFromDate:d], *when = [day isEqualToString:[df stringFromDate:[NSDate date]]] ? @"today" : [day isEqualToString:[df stringFromDate:[NSDate dateWithTimeIntervalSinceNow:-86400]]] ? @"yesterday" : [@"on " stringByAppendingString:day];
        foot = [NSString stringWithFormat:@"%@ · synced %@ at %@%@%@", foot, when, [tf stringFromDate:d], [st syncedFrom] ? @" from " : @"", [st syncedFrom] ?: @""];
    }
    UILabel *l = pressedLabel(CGRectMake(10, y, 300, 16), [UIFont systemFontOfSize:11], [UIColor colorWithRed:0.40 green:0.26 blue:0.10 alpha:1]); l.text = foot; l.adjustsFontSizeToFitWidth = YES; l.minimumFontSize = 9; [self add:l];
    scroll.contentSize = CGSizeMake(320, MAX(y + 30, 417));
}
- (void)lift:(UIButton *)b { [scroll bringSubviewToFront:b]; [UIView animateWithDuration:0.12 animations:^{ b.transform = CGAffineTransformScale(CGAffineTransformMakeTranslation(0, -3), 1.06, 1.06); }]; }   // picked up off the desk
- (void)settle:(UIButton *)b { [UIView animateWithDuration:0.15 animations:^{ b.transform = CGAffineTransformIdentity; }]; }
- (void)open:(UIButton *)b {
    id d = [targets objectAtIndex:b.tag];
    [UIView animateWithDuration:0.1 animations:^{ b.transform = CGAffineTransformScale(CGAffineTransformMakeTranslation(0, -4), 1.08, 1.08); } completion:^(BOOL f) { [self study:[d isKindOfClass:[NSNull class]] ? nil : d]; b.transform = CGAffineTransformIdentity; }];
}
- (void)viewWillAppear:(BOOL)a {
    [super viewWillAppear:a]; if (![[CDStore shared] reloadIfChanged]) [self refresh];
    [poll invalidate]; [poll release]; poll = [[NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(tick) userInfo:nil repeats:YES] retain];
}
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [poll invalidate]; [poll release]; poll = nil; }
- (void)tick { if (![[CDStore shared] reloadIfChanged] && ++ticks % 10 == 0) [self refresh]; }   // a sync lands within 3 s; learning counts tick over every 30
- (void)viewDidAppear:(BOOL)a {
    [super viewDidAppear:a];
    CDWarmUp();
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults]; NSString *t = [u stringForKey:@"cd_test_study"];
    if (t) { [u removeObjectForKey:@"cd_test_study"]; [self study:[t isEqualToString:@"*"] ? nil : t]; }
    if ([u boolForKey:@"cd_test_stats"]) { [u removeObjectForKey:@"cd_test_stats"]; self.tabBarController.selectedIndex = 1; }
    [u synchronize];
}
- (void)study:(NSString *)deck { [self.navigationController pushViewController:[[[CDStudyViewController alloc] initWithDeck:deck] autorelease] animated:YES]; }
@end

#pragma mark - The desk

// The card's writing, bold and centred; its line height is the card's rule spacing, so the words sit on the blue lines.
static NSString *const CSS = @"html{-webkit-text-size-adjust:none}"
    "body{margin:0;padding:0 14px;background:transparent;color:#1b1f2a;font:bold 18px/20px Helvetica,'Hiragino Kaku Gothic ProN';text-align:center;word-wrap:break-word;-webkit-user-select:none;-webkit-touch-callout:none;-webkit-tap-highlight-color:rgba(0,0,0,0)}"
    ".head{height:32px;position:relative;font:normal 9px/12px Helvetica;color:#8f8c93;letter-spacing:1px;text-transform:uppercase}"
    ".deck{position:absolute;left:0;bottom:6px;max-width:170px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.kind{position:absolute;right:0;bottom:6px}"
    "p{margin:0 0 20px}p:last-child,.face>:last-child{margin-bottom:0}"
    ".big{font-size:42px;line-height:40px}.big ruby rt{font-size:15px}"
    "ruby rt{font-size:10px;font-weight:normal;color:#666c7c}"
    "ul,ol{display:inline-block;text-align:left;margin:0 0 20px;padding-left:22px}pre{display:inline-block;text-align:left;font:13px/20px Courier;margin:0 0 20px;white-space:pre-wrap}code{font-family:Courier;font-size:16px}"
    "blockquote{margin:0 0 20px;font-style:italic}mark{background:rgba(255,160,195,.5);color:inherit}"
    ".q{font-weight:normal;font-size:13px;line-height:20px;color:#8b8fa1;padding-top:6px}.q .big{font-size:inherit;line-height:inherit;padding:0}.q ruby rt{font-size:8px}.q p{margin:0}"
    ".a{padding-top:14px}"
    ".done{font-weight:normal;color:#4a4f5c}.done b{display:block;font-size:24px;line-height:40px;color:#1b1f2a}";
// Centre the writing down the card. On the front it moves in whole rules so every line still sits on a blue one;
// the back has no rules, so the answer is simply centred under the grey question.
static NSString *const CENTRE = @"var f=document.getElementById('f'),a=document.getElementById('a'),q=document.querySelector('.q');"
    "if(f)f.style.paddingTop=Math.max(0,Math.floor((%d-f.offsetHeight)/%d)*%d)+'px';"
    "if(a)a.style.paddingTop=Math.max(12,Math.floor((%d-(q?q.offsetHeight:0)-a.offsetHeight)/2))+'px';";
static NSString *page(NSString *body) {
    return [NSString stringWithFormat:@"<!DOCTYPE html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=%d,initial-scale=1,maximum-scale=1,user-scalable=no\"><style>%@</style></head><body>%@<script>%@</script></body></html>", CD_CARD_W, CSS, body,
            [NSString stringWithFormat:CENTRE, CD_CARD_FIRST_RULE + 6 * CD_CARD_RULE - CD_CARD_HEADER, 2 * CD_CARD_RULE, CD_CARD_RULE, CD_CARD_H - 4 - 14]];
}
static NSString *esc(NSString *s) { return [[[s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"] stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"] stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"]; }

@implementation CDStudyViewController
- (id)initWithDeck:(NSString *)d {
    if ((self = [super init])) {
        deck = [d copy]; current = -1; self.title = d ? leaf(d) : @"All Decks"; self.hidesBottomBarWhenPushed = YES;
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Undo" style:UIBarButtonItemStyleBordered target:self action:@selector(undo)] autorelease];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storeChanged) name:CDStoreChanged object:nil];
    }
    return self;
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self]; [NSObject cancelPreviousPerformRequestsWithTarget:self]; [waitTimer invalidate];
    frontWeb.delegate = nil; backWeb.delegate = nil; [frontWeb release]; [backWeb release]; [front release]; [back release]; [host release]; [tab release];
    for (int k = 0; k < 3; k++) [peek[k] release];
    [deck release]; [shownAt release]; [stamps release]; [intervals release]; [hint release]; [super dealloc];
}
- (UIWebView *)web:(CGRect)r {
    UIWebView *w = [[UIWebView alloc] initWithFrame:r]; w.delegate = self; w.opaque = NO; w.backgroundColor = [UIColor clearColor];
    for (UIView *s in [[[w subviews] lastObject] subviews]) if ([s isKindOfClass:[UIImageView class]]) s.hidden = YES;   // the scroll view's shadow images
    return w;
}
- (UIView *)face:(BOOL)ruled seed:(uint32_t)seed web:(UIWebView **)w {
    UIView *f = [[UIView alloc] initWithFrame:host.bounds];
    UIImageView *paper = [[[UIImageView alloc] initWithImage:CDCardImage(ruled, seed)] autorelease]; paper.frame = CGRectInset(f.bounds, -CD_CARD_PAD, -CD_CARD_PAD); [f addSubview:paper];
    *w = [self web:CGRectMake(0, 0, CD_CARD_W, CD_CARD_H - 4)]; [f addSubview:*w]; return f;
}
- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 416)] autorelease]; self.view = v;
    [v addSubview:[[[UIImageView alloc] initWithImage:CDDeskImage(CGSizeMake(320, 416))] autorelease]];
    tab = [[UIImageView alloc] initWithFrame:CGRectMake(40, 5, 240, 30)]; [v addSubview:tab];
    CGRect card = CGRectMake(12, 46, CD_CARD_W, CD_CARD_H);
    static const CGFloat lean[3][3] = { { -2.4, -2, 5 }, { 3.2, 3, 9 }, { -4.2, -4, 12 } };   // the cards still to come, squared up badly
    for (int k = 2; k >= 0; k--) {
        peek[k] = [[UIImageView alloc] initWithImage:CDCardImage(NO, 2 + k)]; peek[k].frame = CGRectInset(card, -CD_CARD_PAD, -CD_CARD_PAD);
        peekAt[k] = CGAffineTransformRotate(CGAffineTransformMakeTranslation(lean[k][1], lean[k][2]), lean[k][0] * M_PI / 180); peek[k].transform = peekAt[k]; [v addSubview:peek[k]];
    }
    host = [[UIView alloc] initWithFrame:card];
    back = [self face:NO seed:5 web:&backWeb]; back.hidden = YES; [host addSubview:back];
    front = [self face:YES seed:1 web:&frontWeb]; [host addSubview:front];
    [frontWeb retain]; [backWeb retain];
    UITapGestureRecognizer *tap = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(flip)] autorelease]; tap.delegate = self; [host addGestureRecognizer:tap];
    [v addSubview:host];
    hint = [pressedLabel(CGRectMake(20, 416 - 56, 280, 22), [UIFont systemFontOfSize:13], [UIColor colorWithRed:0.38 green:0.23 blue:0.08 alpha:1]) retain]; hint.text = @"Tap the card to turn it over."; [v addSubview:hint];
    stamps = [[NSMutableArray alloc] init]; intervals = [[NSMutableArray alloc] init];
    for (int k = 0; k < 4; k++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom]; b.frame = CGRectMake(8 + k * 77, 416 - 76, 73, 70); b.tag = k + 1; b.adjustsImageWhenHighlighted = NO;
        [b setImage:CDStampImage(k + 1, NO) forState:UIControlStateNormal]; [b setImage:CDStampImage(k + 1, YES) forState:UIControlStateHighlighted];
        UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(7, 41, 59, 12)] autorelease]; l.font = [UIFont systemFontOfSize:10]; l.textAlignment = UITextAlignmentCenter; l.backgroundColor = [UIColor clearColor];
        l.textColor = [UIColor colorWithRed:0.35 green:0.35 blue:0.38 alpha:1]; l.userInteractionEnabled = NO; [b addSubview:l];
        [b addTarget:self action:@selector(press:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
        [b addTarget:self action:@selector(release:) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
        [b addTarget:self action:@selector(stampButton:) forControlEvents:UIControlEventTouchUpInside];
        [v addSubview:b]; [stamps addObject:b]; [intervals addObject:l];
    }
    [v addSubview:CDTopShade(320)];
}
- (void)viewDidLoad { [super viewDidLoad]; [self next:NO]; }
- (void)viewDidAppear:(BOOL)a {
    [super viewDidAppear:a];
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    if ([u boolForKey:@"cd_test_reveal"]) { [u removeObjectForKey:@"cd_test_reveal"]; revealOnLoad = YES; }
    if ([u integerForKey:@"cd_test_answer"]) { answerOnLoad = (int)[u integerForKey:@"cd_test_answer"]; [u removeObjectForKey:@"cd_test_answer"]; }
    [u synchronize];
    if (revealOnLoad && !frontWeb.loading) { revealOnLoad = NO; [self flip]; }
}
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [waitTimer invalidate]; waitTimer = nil; }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)o { return YES; }

- (void)updateTab {
    CDCounts c = [[CDStore shared] countsForDeck:deck];
    tab.image = CDRender(tab.bounds.size, ^(CGContextRef ctx) { CDDrawCountTab(ctx, CGRectMake(0, 0, 240, 30), c.fresh, c.learning, c.due); });
    NSInteger left = c.fresh + c.learning + c.due - (current >= 0 ? 1 : 0);
    for (int k = 0; k < 3; k++) peek[k].hidden = k >= left;   // up to three cards wait under this one
    self.navigationItem.rightBarButtonItem.enabled = [[CDStore shared] canUndo] && !busy;
}
- (void)showStamps:(BOOL)on animated:(BOOL)a {
    hint.hidden = on || current < 0;
    for (UIButton *b in stamps) {
        if (on && a) { b.alpha = 0; b.transform = CGAffineTransformMakeTranslation(0, 24); }
        b.userInteractionEnabled = on;
    }
    void (^go)(void) = ^{ for (UIButton *b in stamps) { b.alpha = on ? 1 : 0; b.transform = CGAffineTransformIdentity; } };
    if (a) [UIView animateWithDuration:0.22 animations:go]; else go();
}
- (void)load:(UIWebView *)w body:(NSString *)body { w.alpha = 0; [w loadHTMLString:page(body) baseURL:nil]; }
- (void)webViewDidFinishLoad:(UIWebView *)w {
    [UIView animateWithDuration:0.15 animations:^{ w.alpha = 1; }];
    if (w == frontWeb && revealOnLoad) { revealOnLoad = NO; [self performSelector:@selector(flip) withObject:nil afterDelay:0.3]; }
}
- (void)next:(BOOL)animated {   // the next card comes off the stack
    [waitTimer invalidate]; waitTimer = nil; revealed = NO;
    long long wait; current = [[CDStore shared] nextCardInDeck:deck wait:&wait];
    for (UIView *f in [NSArray arrayWithObjects:front, back, nil]) for (UIView *s in [NSArray arrayWithArray:[f subviews]]) if (s.tag == 77) [s removeFromSuperview];
    front.hidden = NO; back.hidden = YES; host.transform = CGAffineTransformIdentity;
    [self updateTab]; [self showStamps:NO animated:NO]; hint.alpha = 0; [UIView animateWithDuration:0.3 animations:^{ hint.alpha = 1; }];
    if (current < 0) {
        NSInteger n = [[CDStore shared] answersToday]; NSMutableString *s = [NSMutableString stringWithFormat:@"<div class=\"head\"><span class=\"kind\">%@</span></div><div class=\"done\" id=\"f\"><b>%@</b>", wait > 0 ? @"Learning" : @"Done", wait > 0 ? @"Nothing more just now." : @"That's all for today!"];
        if (n) [s appendFormat:@"%@ today.<br>", plural(n, @"answer", @"answers")];
        if (wait > 0) { [s appendFormat:@"A learning card comes back in %@.", plural((long)((wait + 59) / 60), @"minute", @"minutes")]; waitTimer = [NSTimer scheduledTimerWithTimeInterval:15 target:self selector:@selector(checkWaiting) userInfo:nil repeats:YES]; }
        else if (![[CDStore shared] cardCount]) [s appendString:@"There are no cards yet. Sync some from the Mac."];
        else [s appendString:@"Come back tomorrow."];
        [s appendString:@"</div>"]; [self load:frontWeb body:s]; [self load:backWeb body:@""]; return;
    }
    NSDictionary *c = [[CDStore shared] card:current]; [shownAt release]; shownAt = [[NSDate alloc] init];
    NSString *kinds[] = { @"New card", @"Learning", @"Review", @"Relearning" };
    [self load:frontWeb body:[NSString stringWithFormat:@"<div class=\"head\"><span class=\"deck\">%@</span><span class=\"kind\">%@</span></div><div class=\"face\" id=\"f\">%@</div>",
                              esc(deck ? @"" : [c objectForKey:@"deck"]), kinds[[[CDStore shared] kindOfCard:current]], [c objectForKey:@"front"]]];
    [self load:backWeb body:[NSString stringWithFormat:@"<div class=\"q\">%@</div><div class=\"face a\" id=\"a\">%@</div>", [c objectForKey:@"front"], [c objectForKey:@"back"]]];
    if (animated) {
        host.transform = peekAt[0]; busy = YES;
        [UIView animateWithDuration:0.26 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{ host.transform = CGAffineTransformIdentity; } completion:^(BOOL f) { busy = NO; [self updateTab]; }];
    }
}
- (void)checkWaiting { long long wait; if ([[CDStore shared] nextCardInDeck:deck wait:&wait] >= 0) [self next:YES]; }
- (void)flip {   // turn the card over (and back again, to look at the question)
    if (busy || current < 0) return;
    BOOL toBack = back.hidden; busy = YES;
    [UIView transitionWithView:host duration:0.45 options:toBack ? UIViewAnimationOptionTransitionFlipFromRight : UIViewAnimationOptionTransitionFlipFromLeft
                    animations:^{ front.hidden = toBack; back.hidden = !toBack; } completion:^(BOOL f) { busy = NO; if (toBack && !revealed) [self revealed]; }];
}
- (void)revealed {
    revealed = YES;
    for (int k = 0; k < 4; k++) [[intervals objectAtIndex:k] setText:[[CDStore shared] intervalForCard:current rating:k + 1]];
    [self showStamps:YES animated:YES];
    if (answerOnLoad) { int r = answerOnLoad; answerOnLoad = 0; [self performSelector:@selector(stampWith:) withObject:[NSNumber numberWithInt:r] afterDelay:0.8]; }
}
- (void)press:(UIButton *)b { [[intervals objectAtIndex:b.tag - 1] setFrame:CGRectMake(7, 44, 59, 12)]; }   // the proof label sinks with the block
- (void)release:(UIButton *)b { [[intervals objectAtIndex:b.tag - 1] setFrame:CGRectMake(7, 41, 59, 12)]; }
- (void)stampButton:(UIButton *)b { [self release:b]; [self stampWith:[NSNumber numberWithInt:(int)b.tag]]; }
- (void)stampWith:(NSNumber *)rating {   // slam, a thunk through the stack, then the card goes on the done pile
    if (!revealed || busy || current < 0) return;
    int r = [rating intValue]; busy = YES; [self updateTab];
    [[CDStore shared] answerCard:current rating:r ms:(int)MIN(60000, -[shownAt timeIntervalSinceNow] * 1000)];   // the answer is saved before any of the show
    UIView *face = back.hidden ? front : back; slams++;
    UIImageView *ink = [[[UIImageView alloc] initWithImage:CDImpressionImage(r, slams % 3)] autorelease]; ink.tag = 77;
    CGFloat angle = ((int)(arc4random() % 140) - 90) / 10.0 * M_PI / 180;
    ink.center = CGPointMake(CD_CARD_W * 0.63 + (int)(arc4random() % 20) - 10, CD_CARD_H * 0.70 + (int)(arc4random() % 12) - 6);
    ink.transform = CGAffineTransformScale(CGAffineTransformMakeRotation(angle * 1.8), 1.6, 1.6); ink.alpha = 0; [face addSubview:ink];
    [UIView animateWithDuration:0.11 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{ ink.transform = CGAffineTransformMakeRotation(angle); ink.alpha = 1; } completion:^(BOOL f) {
        [UIView animateWithDuration:0.05 animations:^{
            host.transform = CGAffineTransformMakeTranslation(0, 3); for (int k = 0; k < 3; k++) peek[k].transform = CGAffineTransformConcat(peekAt[k], CGAffineTransformMakeTranslation(0, 2));
        } completion:^(BOOL f2) {
            [UIView animateWithDuration:0.10 animations:^{ host.transform = CGAffineTransformIdentity; for (int k = 0; k < 3; k++) peek[k].transform = peekAt[k]; }
                             completion:^(BOOL f3) { [self performSelector:@selector(toss) withObject:nil afterDelay:0.3]; }];
        }];
    }];
}
- (void)toss {   // a picture of the stamped card goes on the done pile, so the real one can bring up the next card meanwhile (a web view stops drawing while it's flung about)
    [UIView animateWithDuration:0.2 animations:^{ for (UIButton *b in stamps) b.alpha = 0; }];   // the hint waits for the next card, rather than showing through
    CGRect area = CGRectInset(host.bounds, -CD_CARD_PAD, -CD_CARD_PAD);
    UIGraphicsBeginImageContextWithOptions(area.size, NO, 0); CGContextTranslateCTM(UIGraphicsGetCurrentContext(), CD_CARD_PAD, CD_CARD_PAD); [host.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImageView *done = [[[UIImageView alloc] initWithImage:UIGraphicsGetImageFromCurrentImageContext()] autorelease]; UIGraphicsEndImageContext();
    done.frame = CGRectOffset(area, host.frame.origin.x, host.frame.origin.y); [self.view insertSubview:done aboveSubview:host];
    busy = NO; [self next:YES];
    [UIView animateWithDuration:0.34 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{ done.transform = CGAffineTransformRotate(CGAffineTransformMakeTranslation(390, 40), 0.38); }
                     completion:^(BOOL f) { [done removeFromSuperview]; }];
}
- (void)undo { if (busy) return; NSInteger c = [[CDStore shared] undo]; if (c < 0) return; [self next:YES]; }   // the undone card is due again at once, so it comes straight back
- (void)storeChanged { if (!revealed && !busy) [self next:NO]; else [self updateTab]; }   // a sync replaced the cards; don't pull the card out from under an answer
@end

#pragma mark - Stats

@implementation CDStatsViewController
- (id)init {
    if ((self = [super init])) {
        self.title = @"Stats"; items = [[NSMutableArray alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:CDStoreChanged object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgrounded) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [scroll release]; [items release]; [drawn release]; [super dealloc]; }
- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 367)] autorelease]; self.view = v;
    scroll = [[UIScrollView alloc] initWithFrame:v.bounds]; scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scroll.backgroundColor = CDDeskColor(); scroll.alwaysBounceVertical = YES; [v addSubview:scroll]; [v addSubview:CDTopShade(320)];
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; if (![[CDStore shared] reloadIfChanged]) [self refresh]; }
- (void)dropCharts { for (UIView *v in items) [v removeFromSuperview]; [items removeAllObjects]; [drawn release]; drawn = nil; }   // about 5 MB of sheets; drawn again when the tab next appears
- (void)viewDidUnload { [super viewDidUnload]; [self dropCharts]; [scroll release]; scroll = nil; }   // otherwise the new scroll view stays empty while `drawn` still matches
- (void)backgrounded { if (self.isViewLoaded && !self.view.window) [self dropCharts]; }
- (void)refresh {
    if (!self.isViewLoaded) return;
    NSDictionary *st = [[CDStore shared] statsSummary]; NSString *key = [st description];
    if ([key isEqualToString:drawn]) return;   // nothing has changed since these were drawn
    [drawn release]; drawn = [key copy];
    for (UIView *v in items) [v removeFromSuperview]; [items removeAllObjects];
    #define N(k) [[st objectForKey:k] intValue]
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease]; [f setDateFormat:@"MMM d"]; NSDate *today = [st objectForKey:@"today"];
    NSString *(^day)(int) = ^(int k) { return [f stringFromDate:[today dateByAddingTimeInterval:k * 86400.0]]; };
    CDChartData ch; memset(&ch, 0, sizeof ch);
    NSArray *answers = [st objectForKey:@"answers"], *forecast = [st objectForKey:@"forecast"], *weeks = [st objectForKey:@"weeks"];
    for (int i = 0; i < 30; i++) { for (int k = 0; k < 4; k++) ch.answers[i][k] = [[[answers objectAtIndex:i] objectAtIndex:k] intValue]; ch.forecast[i] = [[forecast objectAtIndex:i] intValue]; }
    for (int i = 0; i < 12; i++) { ch.weekPass[i] = [[[weeks objectAtIndex:i] objectAtIndex:0] intValue]; ch.weekTotal[i] = [[[weeks objectAtIndex:i] objectAtIndex:1] intValue]; }
    ch.states[0] = N(@"cardsNew"); ch.states[1] = N(@"cardsLearning"); ch.states[2] = N(@"cardsYoung"); ch.states[3] = N(@"cardsMature");
    ch.answersToday = N(@"answersToday"); ch.minutesToday = N(@"minutesToday"); ch.streak = N(@"streak"); ch.target = N(@"target");
    ch.answersFrom = [day(-29) UTF8String]; ch.answersMid = [day(-15) UTF8String]; ch.forecastMid = [day(15) UTF8String]; ch.forecastTo = [day(29) UTF8String];
    CGFloat heights[5] = { 76, 208, 176, 176, 104 }, y = 8;
    void (*charts[5])(CGContextRef, CGRect, const CDChartData *) = { CDDrawSummary, CDDrawAnswersChart, CDDrawForecastChart, CDDrawRetentionChart, CDDrawStatesChart };
    for (int i = 0; i < 5; i++) {   // the paper is drawn once and kept; only the ink on it changes
        UIImage *sheet = CDSheetImage(heights[i], 80 + i); void (*draw)(CGContextRef, CGRect, const CDChartData *) = charts[i]; CGFloat h = heights[i];
        UIImageView *v = [[[UIImageView alloc] initWithImage:CDRender(sheet.size, ^(CGContextRef c) { [sheet drawAtPoint:CGPointZero]; draw(c, CGRectMake(10, 4, 300, h), &ch); })] autorelease];
        v.frame = CGRectMake(0, y, sheet.size.width, sheet.size.height); [scroll addSubview:v]; [items addObject:v]; y += h + 14;
    }
    NSArray *past = [st objectForKey:@"past"], *coming = [st objectForKey:@"coming"];   // and the date-due slip, as the history
    CDStatsData d; memset(&d, 0, sizeof d); d.npast = (int)MIN([past count], 8); d.plainPocket = 1;
    for (int i = 0; i < d.npast; i++) { d.pastDay[i] = [[[past objectAtIndex:i] objectAtIndex:0] UTF8String]; d.pastAnswers[i] = [[[past objectAtIndex:i] objectAtIndex:1] intValue]; }
    for (int i = 0; i < 7 && i < (int)[coming count]; i++) { d.nextDay[i] = [[[coming objectAtIndex:i] objectAtIndex:0] UTF8String]; d.nextDue[i] = [[[coming objectAtIndex:i] objectAtIndex:1] intValue]; }
    CGFloat sh = CDDateDueHeight(&d);
    UIImageView *slip = [[[UIImageView alloc] initWithImage:CDRender(CGSizeMake(320, sh), ^(CGContextRef c) { CDDrawDateDue(c, 320, &d); })] autorelease];
    slip.frame = CGRectMake(0, y - 6, 320, sh); [scroll addSubview:slip]; [items addObject:slip];
    scroll.contentSize = CGSizeMake(320, y - 6 + sh);
}
@end
