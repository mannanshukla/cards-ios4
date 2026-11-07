#import "CLCoachViewController.h"
#import "CLIntegration.h"
#import "CLPaper.h"
@implementation CLCoachViewController
@synthesize questionText;
- (id)initWithSource:(NSString *)s context:(NSString *)c system:(NSString *)p { if((self=[super initWithStyle:UITableViewStyleGrouped])) { source=[s copy];context=[c copy];system=[p copy];self.title=@"Claude";request=[CLAIRequest new];request.delegate=self; }return self; }
- (void)viewDidLoad { [super viewDidLoad];CLPaperTable(self.tableView);question=[[UITextView alloc] initWithFrame:CGRectZero];question.text=questionText?:@"What is working, and what is one practical next step toward my goal?";question.delegate=self;question.font=[UIFont systemFontOfSize:16];question.backgroundColor=[UIColor clearColor];question.autoresizingMask=UIViewAutoresizingFlexibleWidth; }
- (void)viewDidUnload { self.questionText=question.text;[request cancel];question.delegate=nil;[question release];question=nil;[super viewDidUnload]; }
- (void)viewWillDisappear:(BOOL)a { [request cancel];[question resignFirstResponder];[super viewWillDisappear:a]; }
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a];question.editable=!request.running;[self.tableView reloadData]; }
- (void)dealloc { request.delegate=nil;[request cancel];[request release];question.delegate=nil;[question release];[source release];[context release];[system release];[questionText release];[status release];[super dealloc]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 3; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return s==2?2:1; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s { return s==0?@"Your question":s==1?@"Shared with your coach":nil; }
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s { return s==1?@"Your question and this summary are sent only when you tap Ask. Review the summary first if you like.":s==2?(status?:@"Answers are saved in Coach Notes. Discuss in Claude opens an unsent draft."):nil; }
- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)p { return p.section==0?132:44; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p { UITableViewCell *c=[[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];c.textLabel.font=[UIFont boldSystemFontOfSize:16];
    if(p.section==0) { c.selectionStyle=UITableViewCellSelectionStyleNone;question.frame=CGRectMake(5,3,c.contentView.bounds.size.width-10,126);[c.contentView addSubview:question]; }
    else if(p.section==1) { c.textLabel.text=@"Review progress summary";c.accessoryType=UITableViewCellAccessoryDisclosureIndicator; }
    else { c.textLabel.text=p.row==1?@"Discuss in Claude":request.running?@"Stop":[NSString stringWithFormat:@"Ask %@",[CLAIRequest providerName]];c.textLabel.textAlignment=UITextAlignmentCenter;c.textLabel.textColor=CLColor(0x7D4D3B); }return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p { [t deselectRowAtIndexPath:p animated:YES];[question resignFirstResponder];
    if(p.section==1) { [self.navigationController pushViewController:[[[CLNoteViewController alloc] initWithTitle:@"Shared Progress" text:context] autorelease] animated:YES];return; }if(p.section!=2)return;
    NSString *q=[question.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(p.row==1) { NSURL *url=CLDraftURL(source,q,context);if(!url || ![[UIApplication sharedApplication] canOpenURL:url]) { [[[[UIAlertView alloc] initWithTitle:@"Claude" message:@"Install Claude 3.2 or newer to open this draft." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease] show];return; }[request cancel];[[UIApplication sharedApplication] openURL:url];return; }
    if(request.running) { [request cancel];question.editable=YES;[t reloadData];return; }
    if(![q length] || [q length]>2000) { [question becomeFirstResponder];return; }
    self.questionText=q;[status release];status=nil;[request startSystem:system user:[NSString stringWithFormat:@"Question: %@\n<progress>\n%@\n</progress>",q,context]];question.editable=!request.running;[t reloadData];
}
- (BOOL)textView:(UITextView *)v shouldChangeTextInRange:(NSRange)r replacementText:(NSString *)t { return [v.text length]-r.length+[t length]<=2000; }
- (void)aiRequest:(CLAIRequest *)r text:(NSString *)text error:(NSString *)error { if(r!=request)return;question.editable=YES;[status release];status=[error copy];
    if(text) { NSMutableArray *notes=[NSMutableArray arrayWithArray:CLCoachNotes()];[notes insertObject:[NSDictionary dictionaryWithObjectsAndKeys:questionText?:@"Coach note",@"question",text,@"text",[NSDate date],@"date",nil] atIndex:0];while([notes count]>30)[notes removeLastObject];[[NSUserDefaults standardUserDefaults] setObject:notes forKey:@"coach_notes"];[[NSUserDefaults standardUserDefaults] synchronize];[self.navigationController pushViewController:[[[CLNoteViewController alloc] initWithTitle:@"Claude" text:text] autorelease] animated:YES]; }[self.tableView reloadData];
}
@end
