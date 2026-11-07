#import "CLCoachData.h"
NSArray *CLCoachNotes(void) { NSArray *a=[[NSUserDefaults standardUserDefaults] arrayForKey:@"coach_notes"];if(a)return a;NSString *old=[[NSUserDefaults standardUserDefaults] stringForKey:@"ai_last_review"];return [old length]?[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"Earlier coach note",@"question",old,@"text",nil]]:[NSArray array]; }
NSString *CLCheckInSummary(NSString *source) {
    NSDictionary *d=[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"coach_checkin"];
    if(!d)return @"No check-in recorded yet.";
    NSDateFormatter *f=[[[NSDateFormatter alloc] init] autorelease];f.dateStyle=NSDateFormatterMediumStyle;
    return [NSString stringWithFormat:@"Check-in on %@. Goal / obstacles: %@. Energy: %@. %@: %@. Time available: %@ minutes.",[f stringFromDate:[d objectForKey:@"date"]],[d objectForKey:@"goal"],[d objectForKey:@"energy"],[source isEqual:@"Cards"]?@"Confidence":@"Recovery",[d objectForKey:@"recovery"],[d objectForKey:@"time"]];
}
