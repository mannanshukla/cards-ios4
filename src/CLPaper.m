#import "JRMaterials.h"
#import "CLPaper.h"
#import "ORTextLayout.h"
#import "ORMarkdown.h"
#import <QuartzCore/QuartzCore.h>
void CLPaperTable(UITableView *t) {
t.backgroundView=nil;t.backgroundColor=JRPaper();t.separatorColor=JRRule();
}
UIImage *CLCoachIcon(void) { UIGraphicsBeginImageContextWithOptions(CGSizeMake(28,28),NO,0);CGContextRef c=UIGraphicsGetCurrentContext();CGContextSetFillColorWithColor(c,[UIColor whiteColor].CGColor);UIBezierPath *p=[UIBezierPath bezierPathWithRoundedRect:CGRectMake(2,3,24,18) cornerRadius:5];[p fill];CGContextMoveToPoint(c,7,19);CGContextAddLineToPoint(c,7,26);CGContextAddLineToPoint(c,15,20);CGContextFillPath(c);CGContextSetBlendMode(c,kCGBlendModeClear);CGContextFillRect(c,CGRectMake(7,8,14,2));CGContextFillRect(c,CGRectMake(7,13,10,2));UIImage *im=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();return im; }
@interface CLNotePage : UIView { ORTextLayout *layout; NSUInteger page; }
- (id)initWithLayout:(ORTextLayout *)layout page:(NSUInteger)page;
- (void)setLayout:(ORTextLayout *)layout page:(NSUInteger)page;
@end
@implementation CLNotePage
- (id)initWithLayout:(ORTextLayout *)l page:(NSUInteger)p { if((self=[super initWithFrame:CGRectMake(0,0,[l widthOfPage:p],[l heightOfPage:p])])) { layout=[l retain];page=p;self.backgroundColor=[UIColor clearColor];self.opaque=NO; }return self; }
- (void)setLayout:(ORTextLayout *)l page:(NSUInteger)p { [l retain];[layout release];layout=l;page=p;self.frame=CGRectMake(0,0,[l widthOfPage:p],[l heightOfPage:p]);[self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect { [layout drawPage:page context:UIGraphicsGetCurrentContext() origin:CGPointZero]; }
- (void)dealloc { [layout release];[super dealloc]; }
@end
@implementation CLNoteViewController
- (id)initWithTitle:(NSString *)title text:(NSString *)text { if((self=[super initWithStyle:UITableViewStylePlain])) { self.title=title;note=[text copy]; }return self; }
- (void)viewDidLoad { [super viewDidLoad];CLPaperTable(self.tableView);self.tableView.separatorStyle=UITableViewCellSeparatorStyleNone;layout=[[ORTextLayout alloc] initWithText:note markdown:YES width:self.tableView.bounds.size.width-36];self.navigationItem.rightBarButtonItem=[[[UIBarButtonItem alloc] initWithTitle:@"Copy" style:UIBarButtonItemStyleBordered target:self action:@selector(copyNote)] autorelease];self.tableView.tableFooterView=[[[UIView alloc] initWithFrame:CGRectMake(0,0,1,24)] autorelease]; }
- (void)copyNote { [UIPasteboard generalPasteboard].string=[ORMarkdown plainText:note]; }
- (void)viewDidUnload { [layout release];layout=nil;[super viewDidUnload]; }
- (void)dealloc { [layout release];[note release];[super dealloc]; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return [layout pageCount]; }
- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)p { return [layout heightOfPage:p.row]+16; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    UITableViewCell *cell=[t dequeueReusableCellWithIdentifier:@"paper"];
    if(!cell)cell=[[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"paper"] autorelease];
    // A reused row keeps its holder and page view, so scrolling a long note redraws into the same backing store
    // instead of allocating a new one (up to 0.4 MB) for every page that comes into view.
    UIScrollView *holder=(UIScrollView *)[cell.contentView viewWithTag:31];CLNotePage *page=(CLNotePage *)[holder viewWithTag:32];
    if(!holder || !page) { for(UIView *v in [[cell.contentView.subviews copy] autorelease])[v removeFromSuperview];holder=nil;page=nil; }
    cell.selectionStyle=UITableViewCellSelectionStyleNone;cell.backgroundColor=[UIColor clearColor];
    BOOL box=![[layout kindOfPage:p.row] isEqual:@"text"];CGFloat w=t.bounds.size.width-36;
    if(!holder) { holder=[[[UIScrollView alloc] initWithFrame:CGRectMake(18,8,w,[layout heightOfPage:p.row]) ] autorelease];holder.tag=31;holder.directionalLockEnabled=YES;[cell.contentView addSubview:holder]; }
    holder.frame=CGRectMake(18,8,w,[layout heightOfPage:p.row]);holder.contentOffset=CGPointZero;holder.scrollEnabled=box;holder.contentSize=CGSizeMake([layout widthOfPage:p.row],[layout heightOfPage:p.row]);
    if(box) { holder.backgroundColor=CLColor(0xE8DECC);holder.layer.cornerRadius=5;holder.layer.borderWidth=1;holder.layer.borderColor=CLColor(0xC4B59C).CGColor; }
    else { holder.backgroundColor=nil;holder.layer.cornerRadius=0;holder.layer.borderWidth=0; }
    if(page)[page setLayout:layout page:p.row];
    else { page=[[[CLNotePage alloc] initWithLayout:layout page:p.row] autorelease];page.tag=32;[holder addSubview:page]; }
    return cell;
}
@end
@implementation CLNotesViewController
- (id)init { if((self=[super initWithStyle:UITableViewStyleGrouped]))self.title=@"Coach Notes";return self; }
- (void)viewDidLoad { [super viewDidLoad];CLPaperTable(self.tableView); }
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a];[notes release];notes=[CLCoachNotes() copy];[self.tableView reloadData]; }
- (void)dealloc { [notes release];[super dealloc]; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return MAX(1,[notes count]); }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p { UITableViewCell *c=[[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil] autorelease];c.textLabel.font=[UIFont boldSystemFontOfSize:16];c.textLabel.text=[notes count]?[[notes objectAtIndex:p.row] objectForKey:@"question"]:@"Your notes will appear here.";c.accessoryType=[notes count]?UITableViewCellAccessoryDisclosureIndicator:UITableViewCellAccessoryNone;if([notes count]) { NSDate *date=[[notes objectAtIndex:p.row] objectForKey:@"date"];if(date)c.detailTextLabel.text=[NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle]; }return c; }
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p { [t deselectRowAtIndexPath:p animated:YES];if(![notes count])return;[self.navigationController pushViewController:[[[CLNoteViewController alloc] initWithTitle:@"Claude" text:[[notes objectAtIndex:p.row] objectForKey:@"text"]] autorelease] animated:YES]; }
@end
@implementation CLCheckInController
- (id)initWithSource:(NSString *)s { if((self=[super initWithStyle:UITableViewStyleGrouped])) { source=[s copy];self.title=@"Check-In"; }return self; }
- (UISegmentedControl *)newSegment:(NSArray *)items value:(NSString *)value fallback:(NSInteger)fallback { UISegmentedControl *v=[[UISegmentedControl alloc] initWithItems:items];v.segmentedControlStyle=UISegmentedControlStyleBar;NSUInteger i=[items indexOfObject:value?:@""];v.selectedSegmentIndex=i==NSNotFound?fallback:i;return v; }
- (void)viewDidLoad { [super viewDidLoad];CLPaperTable(self.tableView);NSDictionary *d=[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"coach_checkin"];
    goal=[[UITextView alloc] initWithFrame:CGRectZero];goal.delegate=self;goal.font=[UIFont systemFontOfSize:16];goal.backgroundColor=[UIColor clearColor];goal.text=[d objectForKey:@"goal"]?:@"";
    energy=[self newSegment:[NSArray arrayWithObjects:@"Low",@"Okay",@"High",nil] value:[d objectForKey:@"energy"] fallback:1];
    recovery=[self newSegment:[source isEqual:@"Cards"]?[NSArray arrayWithObjects:@"Struggling",@"Okay",@"Confident",nil]:[NSArray arrayWithObjects:@"Sore",@"Okay",@"Fresh",nil] value:[d objectForKey:@"recovery"] fallback:1];
    time=[self newSegment:[source isEqual:@"Cards"]?[NSArray arrayWithObjects:@"5",@"10",@"20",@"30",nil]:[NSArray arrayWithObjects:@"15",@"30",@"45",@"60",nil] value:[d objectForKey:@"time"] fallback:1];
    self.navigationItem.rightBarButtonItem=[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(save)] autorelease];
}
- (void)releaseInputs { goal.delegate=nil;[goal release];goal=nil;[energy release];energy=nil;[recovery release];recovery=nil;[time release];time=nil; }
- (void)viewDidUnload { [self releaseInputs];[super viewDidUnload]; }
- (void)dealloc { [self releaseInputs];[source release];[super dealloc]; }
- (void)save { NSDictionary *d=[NSDictionary dictionaryWithObjectsAndKeys:goal.text?:@"",@"goal",[energy titleForSegmentAtIndex:energy.selectedSegmentIndex],@"energy",[recovery titleForSegmentAtIndex:recovery.selectedSegmentIndex],@"recovery",[time titleForSegmentAtIndex:time.selectedSegmentIndex],@"time",[NSDate date],@"date",nil];[[NSUserDefaults standardUserDefaults] setObject:d forKey:@"coach_checkin"];[[NSUserDefaults standardUserDefaults] synchronize];[self.navigationController popViewControllerAnimated:YES]; }
- (BOOL)textView:(UITextView *)v shouldChangeTextInRange:(NSRange)r replacementText:(NSString *)t { return [v.text length]-r.length+[t length]<=1000; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 4; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return 1; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s { return [[NSArray arrayWithObjects:@"Your goal & what’s getting in the way",@"Energy",[source isEqual:@"Cards"]?@"Confidence":@"Recovery",@"Time available today (minutes)",nil] objectAtIndex:s]; }
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s { return s==3?@"Saved on this iPod. Included when you next ask your coach.":nil; }
- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)p { return p.section==0?112:44; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p { UITableViewCell *c=[[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];c.selectionStyle=UITableViewCellSelectionStyleNone;UIView *v=p.section==0?(UIView *)goal:p.section==1?(UIView *)energy:p.section==2?(UIView *)recovery:(UIView *)time;v.frame=CGRectMake(8,6,c.contentView.bounds.size.width-16,p.section==0?100:32);v.autoresizingMask=UIViewAutoresizingFlexibleWidth;[c.contentView addSubview:v];return c; }
@end
