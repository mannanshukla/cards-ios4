#import "CDViewControllers.h"
#import "CDStore.h"
#import <QuartzCore/QuartzCore.h>

UIColor *CDTint(void) { return [UIColor colorWithRed:0.62 green:0.17 blue:0.36 alpha:1]; }   // the icon's raspberry, darkened for the bar
static NSString *leaf(NSString *deck) { return [[deck componentsSeparatedByString:@"/"] lastObject]; }
static NSString *folder(NSString *deck) { NSRange r = [deck rangeOfString:@"/" options:NSBackwardsSearch]; return r.location == NSNotFound ? @"" : [deck substringToIndex:r.location]; }
static NSString *plural(NSInteger n, NSString *one, NSString *many) { return [NSString stringWithFormat:@"%ld %@", (long)n, n == 1 ? one : many]; }
static NSString *summary(CDCounts c) {
    NSMutableArray *parts = [NSMutableArray array];
    if (c.due) [parts addObject:[NSString stringWithFormat:@"%ld due", (long)c.due]];
    if (c.learning) [parts addObject:[NSString stringWithFormat:@"%ld learning", (long)c.learning]];
    if (c.fresh) [parts addObject:[NSString stringWithFormat:@"%ld new", (long)c.fresh]];
    if ([parts count]) return [parts componentsJoinedByString:@"  ·  "];
    if (c.nextDay < 0) return @"Done for today";
    return c.nextDay == c.today + 1 ? @"Done for today  ·  more tomorrow" : [NSString stringWithFormat:@"Done for today  ·  more in %ld days", c.nextDay - c.today];
}

#pragma mark - Decks
@implementation CDDecksViewController
- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.title = @"Cards"; sections = [[NSMutableArray alloc] init];
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Stats" style:UIBarButtonItemStyleBordered target:self action:@selector(stats)] autorelease];
        self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Decks" style:UIBarButtonItemStyleBordered target:nil action:nil] autorelease];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:CDStoreChanged object:nil];
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [sections release]; [poll invalidate]; [poll release]; [super dealloc]; }
- (void)refresh {
    [sections removeAllObjects]; NSArray *decks = [[CDStore shared] decks];
    if ([decks count] > 1) [sections addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"", @"title", [NSArray arrayWithObject:[NSNull null]], @"decks", nil]];
    for (NSString *d in decks) {   // a section per folder, in the order the folders first appear
        NSString *f = folder(d); NSMutableArray *rows = nil;
        for (NSDictionary *s in sections) if ([[s objectForKey:@"title"] isEqualToString:f] && ![[[s objectForKey:@"decks"] lastObject] isKindOfClass:[NSNull class]]) rows = [s objectForKey:@"decks"];
        if (!rows) { rows = [NSMutableArray array]; [sections addObject:[NSDictionary dictionaryWithObjectsAndKeys:f, @"title", rows, @"decks", nil]]; }
        [rows addObject:d];
    }
    [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)a {
    [super viewWillAppear:a]; if (![[CDStore shared] reloadIfChanged]) [self refresh];
    [poll invalidate]; [poll release]; poll = [[NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(tick) userInfo:nil repeats:YES] retain];
}
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [poll invalidate]; [poll release]; poll = nil; }
- (void)tick { if (![[CDStore shared] reloadIfChanged] && ++ticks % 10 == 0) [self.tableView reloadData]; }   // a sync lands within 3 s; learning counts tick over every 30
- (void)viewDidAppear:(BOOL)a {
    [super viewDidAppear:a];
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults]; NSString *t = [u stringForKey:@"cd_test_study"];
    if (t) { [u removeObjectForKey:@"cd_test_study"]; [u synchronize]; [self study:[t isEqualToString:@"*"] ? nil : t]; }
    if ([u boolForKey:@"cd_test_stats"]) { [u removeObjectForKey:@"cd_test_stats"]; [u synchronize]; [self stats]; }
}
- (void)study:(NSString *)deck { CDStudyViewController *v = [[[CDStudyViewController alloc] initWithDeck:deck] autorelease]; [self.navigationController pushViewController:v animated:YES]; }
- (void)stats {
    UINavigationController *n = [[[UINavigationController alloc] initWithRootViewController:[[[CDStatsViewController alloc] init] autorelease]] autorelease];
    n.navigationBar.tintColor = CDTint(); [self presentModalViewController:n animated:YES];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return MAX([sections count], 1); }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [sections count] ? [[[sections objectAtIndex:s] objectForKey:@"decks"] count] : 0; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { NSString *t = [sections count] ? [[sections objectAtIndex:s] objectForKey:@"title"] : nil; return [t length] ? t : nil; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    CDStore *st = [CDStore shared];
    if (![st cardCount]) return @"No cards yet.\n\nWrite them in Markdown in the Cards folder in your home folder on the Mac, one deck per file:\n\nfront::back\n\nThen plug in the iPod and run cards sync in Terminal.";
    if (s != (NSInteger)[sections count] - 1) return nil;
    NSDate *d = [st syncedAt]; if (!d) return plural([st cardCount], @"card", @"cards");
    NSDateFormatter *df = [[[NSDateFormatter alloc] init] autorelease], *tf = [[[NSDateFormatter alloc] init] autorelease]; [df setDateStyle:NSDateFormatterMediumStyle]; [tf setTimeStyle:NSDateFormatterShortStyle];
    NSString *day = [df stringFromDate:d], *when = [day isEqualToString:[df stringFromDate:[NSDate date]]] ? @"today" : [day isEqualToString:[df stringFromDate:[NSDate dateWithTimeIntervalSinceNow:-86400]]] ? @"yesterday" : [@"on " stringByAppendingString:day];
    return [NSString stringWithFormat:@"%@, synced %@ at %@%@%@.", plural([st cardCount], @"card", @"cards"), when, [tf stringFromDate:d], [st syncedFrom] ? @" from " : @"", [st syncedFrom] ?: @""];
}
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return 52; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"deck"] ?: [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"deck"] autorelease];
    id d = [[[sections objectAtIndex:ip.section] objectForKey:@"decks"] objectAtIndex:ip.row]; BOOL all = [d isKindOfClass:[NSNull class]];
    CDCounts n = [[CDStore shared] countsForDeck:all ? nil : d];
    c.textLabel.text = all ? @"All Decks" : leaf(d); c.detailTextLabel.text = summary(n);
    c.detailTextLabel.textColor = n.due + n.learning + n.fresh ? CDTint() : [UIColor grayColor];
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    id d = [[[sections objectAtIndex:ip.section] objectForKey:@"decks"] objectAtIndex:ip.row];
    [self study:[d isKindOfClass:[NSNull class]] ? nil : d];
}
@end

#pragma mark - Study
static NSString *const CSS = @"html{-webkit-text-size-adjust:none}"
    "body{margin:0;padding:8px 9px 14px;background:transparent;font:20px/1.45 Helvetica;color:#1c1c1c;-webkit-user-select:none;-webkit-touch-callout:none;-webkit-tap-highlight-color:rgba(0,0,0,0)}"
    ".card{position:relative;background:#fff;border:1px solid #b5b8be;border-radius:6px;-webkit-box-shadow:0 1px 3px rgba(0,0,0,.2);padding:44px 16px 26px;text-align:center;word-wrap:break-word}"
    ".card:before{content:'';position:absolute;left:0;right:0;top:30px;border-top:1px solid #eaa5bd}"   // the red rule across an index card
    ".deck,.kind{position:absolute;top:8px;font-size:11px;line-height:14px;color:#a3a3a9;white-space:nowrap}.deck{left:12px;right:90px;text-align:left;overflow:hidden;text-overflow:ellipsis}.kind{right:12px;text-transform:uppercase;letter-spacing:1px;font-size:10px}"
    ".big{font-size:46px;line-height:1.25;padding-top:18px}.big p{margin:0}"
    "p{margin:0 0 12px}.face>p:last-child,.face>ul:last-child,.face>ol:last-child{margin-bottom:0}"
    "ruby rt{font-size:.5em;color:#7d7d86}.big ruby rt{font-size:.38em}"
    "hr{border:0;border-top:1px dashed #cdd0d5;margin:24px -16px 22px}"
    "code{font:.8em Courier;background:#f0f1f3;border-radius:3px;padding:1px 4px}"
    "pre{font:14px/1.35 Courier;background:#f4f5f7;border-radius:4px;padding:8px 10px;text-align:left;white-space:pre-wrap;word-wrap:break-word;margin:0 0 12px}"
    "ul,ol{display:inline-block;text-align:left;margin:0 0 12px;padding-left:26px}"
    "blockquote{margin:0 0 12px;color:#555;font-style:italic}mark{background:#fbdbe7;color:inherit;padding:0 2px}"
    ".done{color:#666;font-size:16px;line-height:1.5;padding-top:64px}.done b{display:block;font-size:22px;color:#222;margin-bottom:10px}";
static NSString *page(NSString *body) {
    return [NSString stringWithFormat:@"<!DOCTYPE html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no\"><style>%@</style></head><body>%@</body></html>", CSS, body];
}
static NSString *esc(NSString *s) { return [[[s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"] stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"] stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"]; }

@implementation CDStudyViewController
- (id)initWithDeck:(NSString *)d {
    if ((self = [super init])) {
        deck = [d copy]; current = -1; self.title = d ? leaf(d) : @"All Decks";
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Undo" style:UIBarButtonItemStyleBordered target:self action:@selector(undo)] autorelease];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storeChanged) name:CDStoreChanged object:nil];
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [waitTimer invalidate]; [deck release]; [shownAt release]; [web release]; [showButton release]; [rateButtons release]; [rateIntervals release]; [newLabel release]; [learnLabel release]; [dueLabel release]; [super dealloc]; }
- (UILabel *)countLabel:(CGRect)r color:(UIColor *)col {
    UILabel *l = [[UILabel alloc] initWithFrame:r]; l.font = [UIFont boldSystemFontOfSize:12]; l.textColor = col; l.backgroundColor = [UIColor clearColor];
    l.shadowColor = [UIColor colorWithWhite:1 alpha:0.8]; l.shadowOffset = CGSizeMake(0, 1); l.textAlignment = UITextAlignmentCenter; [self.view addSubview:l]; return l;
}
- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 416)] autorelease]; v.backgroundColor = [UIColor groupTableViewBackgroundColor]; self.view = v;
    CGFloat w = v.bounds.size.width, h = v.bounds.size.height;
    newLabel = [self countLabel:CGRectMake(0, 6, w / 3, 16) color:[UIColor colorWithRed:0.16 green:0.36 blue:0.70 alpha:1]];
    learnLabel = [self countLabel:CGRectMake(w / 3, 6, w / 3, 16) color:[UIColor colorWithRed:0.72 green:0.18 blue:0.18 alpha:1]];
    dueLabel = [self countLabel:CGRectMake(2 * w / 3, 6, w / 3, 16) color:[UIColor colorWithRed:0.16 green:0.50 blue:0.22 alpha:1]];
    web = [[UIWebView alloc] initWithFrame:CGRectMake(0, 22, w, h - 22 - 70)]; web.delegate = self; web.opaque = NO; web.backgroundColor = [UIColor clearColor]; web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    for (UIView *s in [[[web subviews] lastObject] subviews]) if ([s isKindOfClass:[UIImageView class]]) s.hidden = YES;   // the scroll view's shadow images
    UITapGestureRecognizer *tap = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)] autorelease]; tap.delegate = self; [web addGestureRecognizer:tap];
    [v addSubview:web];
    UIView *panel = [[[UIView alloc] initWithFrame:CGRectMake(0, h - 70, w, 70)] autorelease]; panel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth; [v addSubview:panel];
    showButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain]; showButton.frame = CGRectMake(9, 8, w - 18, 52); showButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [showButton setTitle:@"Show Answer" forState:UIControlStateNormal]; [showButton setTitleColor:CDTint() forState:UIControlStateNormal]; [showButton addTarget:self action:@selector(reveal) forControlEvents:UIControlEventTouchUpInside]; [panel addSubview:showButton];
    NSArray *names = [NSArray arrayWithObjects:@"Again", @"Hard", @"Good", @"Easy", nil];
    NSArray *colors = [NSArray arrayWithObjects:[UIColor colorWithRed:0.72 green:0.18 blue:0.18 alpha:1], [UIColor colorWithWhite:0.33 alpha:1], [UIColor colorWithRed:0.16 green:0.50 blue:0.22 alpha:1], [UIColor colorWithRed:0.16 green:0.36 blue:0.70 alpha:1], nil];
    rateButtons = [[NSMutableArray alloc] init]; rateIntervals = [[NSMutableArray alloc] init]; CGFloat bw = (w - 18 - 3 * 5) / 4;
    for (int k = 0; k < 4; k++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeRoundedRect]; b.frame = CGRectMake(9 + k * (bw + 5), 8, bw, 52); b.tag = k + 1; [b addTarget:self action:@selector(rate:) forControlEvents:UIControlEventTouchUpInside];
        UILabel *ivl = [[[UILabel alloc] initWithFrame:CGRectMake(0, 7, bw, 15)] autorelease]; ivl.font = [UIFont systemFontOfSize:12]; ivl.textColor = [UIColor grayColor]; ivl.textAlignment = UITextAlignmentCenter; ivl.backgroundColor = [UIColor clearColor]; ivl.userInteractionEnabled = NO; [b addSubview:ivl];
        UILabel *name = [[[UILabel alloc] initWithFrame:CGRectMake(0, 24, bw, 20)] autorelease]; name.font = [UIFont boldSystemFontOfSize:16]; name.textColor = [colors objectAtIndex:k]; name.text = [names objectAtIndex:k]; name.textAlignment = UITextAlignmentCenter; name.backgroundColor = [UIColor clearColor]; name.userInteractionEnabled = NO; [b addSubview:name];
        [panel addSubview:b]; [rateButtons addObject:b]; [rateIntervals addObject:ivl];
    }
}
- (void)viewDidLoad { [super viewDidLoad]; [self next]; }
- (void)viewDidAppear:(BOOL)a {
    [super viewDidAppear:a];
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    if ([u boolForKey:@"cd_test_reveal"]) { [u removeObjectForKey:@"cd_test_reveal"]; revealOnLoad = YES; }
    if ([u integerForKey:@"cd_test_answer"]) { answerOnLoad = (int)[u integerForKey:@"cd_test_answer"]; [u removeObjectForKey:@"cd_test_answer"]; }
    [u synchronize];
    if (revealOnLoad && !web.loading) { revealOnLoad = NO; [self reveal]; }
}
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [waitTimer invalidate]; waitTimer = nil; }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)o { return YES; }
- (void)updateCounts {
    CDCounts c = [[CDStore shared] countsForDeck:deck];
    newLabel.text = [NSString stringWithFormat:@"%ld new", (long)c.fresh]; learnLabel.text = [NSString stringWithFormat:@"%ld learning", (long)c.learning]; dueLabel.text = [NSString stringWithFormat:@"%ld due", (long)c.due];
    self.navigationItem.rightBarButtonItem.enabled = [[CDStore shared] canUndo];
}
- (void)showButtons:(BOOL)rate { showButton.hidden = rate || current < 0; for (UIButton *b in rateButtons) b.hidden = !rate || current < 0; }
- (void)load:(NSString *)body { web.alpha = 0; [web loadHTMLString:page(body) baseURL:nil]; }
- (void)webViewDidFinishLoad:(UIWebView *)w {
    [UIView beginAnimations:nil context:NULL]; [UIView setAnimationDuration:0.18]; web.alpha = 1; [UIView commitAnimations];
    if (revealOnLoad) { revealOnLoad = NO; [self reveal]; }
}
- (void)next {
    [waitTimer invalidate]; waitTimer = nil; revealed = NO;
    long long wait; current = [[CDStore shared] nextCardInDeck:deck wait:&wait];
    [self updateCounts]; [self showButtons:NO];
    if (current < 0) {
        NSInteger n = [[CDStore shared] answersToday]; NSMutableString *s = [NSMutableString stringWithString:@"<div class=\"card done\"><b>"];
        [s appendString:wait > 0 ? @"Nothing more for now.</b>" : @"That's all for today.</b>"];
        if (n) [s appendFormat:@"%@ today.<br>", plural(n, @"answer", @"answers")];
        if (wait > 0) { long m = (long)((wait + 59) / 60); [s appendFormat:@"A learning card comes back in %@.", plural(m, @"minute", @"minutes")]; waitTimer = [NSTimer scheduledTimerWithTimeInterval:15 target:self selector:@selector(checkWaiting) userInfo:nil repeats:YES]; }
        else if (![[CDStore shared] cardCount]) [s appendString:@"There are no cards yet. Sync some from the Mac."];
        [s appendString:@"</div>"]; [self load:[s stringByReplacingOccurrencesOfString:@"card done\">" withString:[NSString stringWithFormat:@"card done\" style=\"min-height:%dpx\">", [self cardHeight] - 20]]]; return;
    }
    NSDictionary *c = [[CDStore shared] card:current]; [shownAt release]; shownAt = [[NSDate alloc] init];
    int kind = [[CDStore shared] kindOfCard:current]; NSString *kinds[] = { @"New card", @"Learning", @"Review", @"Relearning" };
    [self load:[NSString stringWithFormat:@"<div class=\"card\" style=\"min-height:%dpx\"><div class=\"deck\">%@</div><div class=\"kind\">%@</div><div class=\"face\">%@</div><div id=\"a\" style=\"display:none\"><hr><div class=\"face\">%@</div></div></div>",
                [self cardHeight], esc(deck ? @"" : [c objectForKey:@"deck"]), kinds[kind], [c objectForKey:@"front"], [c objectForKey:@"back"]]];
}
- (int)cardHeight { return (int)web.bounds.size.height - 8 - 14 - 44 - 26 - 2; }   // the card fills the view: less body padding, card padding and border
- (void)checkWaiting { long long wait; if ([[CDStore shared] nextCardInDeck:deck wait:&wait] >= 0) [self next]; }
- (void)tapped { if (!revealed && current >= 0) [self reveal]; }
- (void)reveal {
    if (revealed || current < 0) return;
    if (web.loading) { revealOnLoad = YES; return; }
    revealed = YES;
    [web stringByEvaluatingJavaScriptFromString:@"var a=document.getElementById('a');a.style.display='block';if(a.offsetTop+120>window.innerHeight)window.scrollTo(0,a.offsetTop-70);"];
    for (int k = 0; k < 4; k++) [[rateIntervals objectAtIndex:k] setText:[[CDStore shared] intervalForCard:current rating:k + 1]];
    [self showButtons:YES];
    if (answerOnLoad) { int r = answerOnLoad; answerOnLoad = 0; [self performSelector:@selector(rateWith:) withObject:[NSNumber numberWithInt:r] afterDelay:1.0]; }
}
- (void)rateWith:(NSNumber *)r { if (revealed && current >= 0) { int ms = (int)MIN(60000, -[shownAt timeIntervalSinceNow] * 1000); [[CDStore shared] answerCard:current rating:[r intValue] ms:ms]; [self next]; } }
- (void)rate:(UIButton *)b { [self rateWith:[NSNumber numberWithInt:(int)b.tag]]; }
- (void)undo { NSInteger c = [[CDStore shared] undo]; if (c < 0) return; [self next]; }   // the undone card is due again at once, so it comes straight back
- (void)storeChanged { if (!revealed) [self next]; else [self updateCounts]; }   // a sync replaced the cards; don't pull the card out from under an answer
@end

#pragma mark - Stats
@implementation CDStatsViewController
- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.title = @"Stats"; sections = [[[CDStore shared] statsSections] retain];
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)] autorelease];
    }
    return self;
}
- (void)dealloc { [sections release]; [super dealloc]; }
- (void)done { [self dismissModalViewControllerAnimated:YES]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return [sections count]; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [[[sections objectAtIndex:s] objectForKey:@"rows"] count]; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return [[sections objectAtIndex:s] objectForKey:@"title"]; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s { return [[sections objectAtIndex:s] objectForKey:@"footer"]; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil] autorelease]; c.selectionStyle = UITableViewCellSelectionStyleNone;
    NSArray *row = [[[sections objectAtIndex:ip.section] objectForKey:@"rows"] objectAtIndex:ip.row]; c.textLabel.text = [row objectAtIndex:0]; c.detailTextLabel.text = [row objectAtIndex:1];
    return c;
}
@end
