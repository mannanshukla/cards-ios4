#import "CDCoachText.h"
NSString *CDCoachPlain(NSString *html,NSUInteger limit) {
 if(![html isKindOfClass:[NSString class]])return @"";NSMutableString *out=[NSMutableString string];BOOL tag=NO;
 for(NSUInteger i=0;i<MIN([html length],20000) && [out length]<limit;i++) { unichar c=[html characterAtIndex:i];if(c=='<') { tag=YES;[out appendString:@" "]; }else if(c=='>')tag=NO;else if(!tag)[out appendFormat:@"%C",c]; }
 NSArray *from=[NSArray arrayWithObjects:@"&nbsp;",@"&lt;",@"&gt;",@"&quot;",@"&#39;",@"&amp;",nil],*to=[NSArray arrayWithObjects:@" ",@"<",@">",@"\"",@"'",@"&",nil];for(NSUInteger i=0;i<[from count];i++)[out replaceOccurrencesOfString:[from objectAtIndex:i] withString:[to objectAtIndex:i] options:0 range:NSMakeRange(0,[out length])];return [out stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
