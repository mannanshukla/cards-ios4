#import "ORMarkdown.h"

static void appendRun(NSMutableArray *runs, NSString *text, NSString *style, NSString *url) {
    if (![text length]) return;
    [runs addObject:[NSDictionary dictionaryWithObjectsAndKeys:[[text copy] autorelease],@"text",style ?: @"normal",@"style",url ?: @"",@"url",nil]];
}
static BOOL safeURL(NSString *url) {
    NSString *scheme = [[[NSURL URLWithString:url] scheme] lowercaseString];
    if([scheme isEqual:@"claude-source"]) { NSString *host=[[NSURL URLWithString:url] host];return [host length] && [host rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location==NSNotFound; }
    return [scheme isEqual:@"https"] || [scheme isEqual:@"http"] || [scheme isEqual:@"mailto"];
}
static NSArray *inlineRuns(NSString *text, NSUInteger depth) {
    NSMutableArray *runs = [NSMutableArray array];
    if (depth > 4) { appendRun(runs,text,@"normal",nil); return runs; }
    NSMutableString *plain = [NSMutableString string]; NSUInteger i=0, n=[text length], budget=MAX(4096,[text length]*8);
    while (i<n) {
        if (budget < n-i || [runs count]>4096) { [plain appendString:[text substringFromIndex:i]]; break; }
        unichar c=[text characterAtIndex:i];
        if (c=='\\' && i+1<n) { unichar escaped=[text characterAtIndex:i+1];CFStringAppendCharacters((CFMutableStringRef)plain,&escaped,1); i+=2; continue; }
        NSString *delimiter = nil, *style = nil;
        if (c=='`') { delimiter=@"`"; style=@"code"; }
        else if (i+2<n && (c=='*' || c=='_') && [text characterAtIndex:i+1]==c && [text characterAtIndex:i+2]==c) { delimiter=[text substringWithRange:NSMakeRange(i,3)];style=@"bolditalic"; }
        else if (i+1<n && ((c=='*' && [text characterAtIndex:i+1]=='*') || (c=='_' && [text characterAtIndex:i+1]=='_'))) { delimiter=[text substringWithRange:NSMakeRange(i,2)]; style=@"bold"; }
        else if (c=='*' || (c=='_' && (i==0 || [[NSCharacterSet whitespaceCharacterSet] characterIsMember:[text characterAtIndex:i-1]]))) { delimiter=[text substringWithRange:NSMakeRange(i,1)]; style=@"italic"; }
        if (delimiter) {
            budget-=n-i;
            NSUInteger start=i+[delimiter length]; NSRange end=[text rangeOfString:delimiter options:0 range:NSMakeRange(start,n-start)];
            if (end.location!=NSNotFound && end.location>start) {
                appendRun(runs,plain,@"normal",nil); [plain setString:@""];
                NSString *inside=[text substringWithRange:NSMakeRange(start,end.location-start)];
                if ([style isEqual:@"code"]) appendRun(runs,inside,style,nil);
                else for (NSDictionary *r in inlineRuns(inside,depth+1)) {
                    NSString *nested=[r objectForKey:@"style"];
                    NSString *combined=[nested isEqual:@"normal"] ? style : (([nested isEqual:@"bold"] && [style isEqual:@"italic"]) || ([nested isEqual:@"italic"] && [style isEqual:@"bold"])) ? @"bolditalic" : nested;
                    appendRun(runs,[r objectForKey:@"text"],combined,[r objectForKey:@"url"]);
                }
                i=end.location+[delimiter length]; continue;
            }
        }
        if (c=='[') {
            budget-=MIN(budget,n-i);

            NSRange middle=[text rangeOfString:@"](" options:0 range:NSMakeRange(i+1,n-i-1)];
            if (middle.location!=NSNotFound) {
                NSUInteger start=middle.location+2; NSRange end=[text rangeOfString:@")" options:0 range:NSMakeRange(start,n-start)];
                if (end.location!=NSNotFound) {
                    NSString *label=[text substringWithRange:NSMakeRange(i+1,middle.location-i-1)];
                    NSString *url=[text substringWithRange:NSMakeRange(start,end.location-start)];
                    appendRun(runs,plain,@"normal",nil);[plain setString:@""];
                    appendRun(runs,label,safeURL(url)?@"link":@"normal",safeURL(url)?url:nil);i=end.location+1;continue;
                }
            }
        }
        CFStringAppendCharacters((CFMutableStringRef)plain,&c,1); i++;
    }
    appendRun(runs,plain,@"normal",nil);return runs;
}
static NSDictionary *block(NSString *kind, NSString *text, NSInteger level, NSString *prefix, BOOL literal) {
    text=[[text copy] autorelease];
    return [NSDictionary dictionaryWithObjectsAndKeys:kind,@"kind",text,@"source",[NSNumber numberWithInteger:level],@"level",prefix ?: @"",@"prefix",literal ? [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:text,@"text",@"code",@"style",@"",@"url",nil]] : inlineRuns(text,0),@"runs",nil];
}
static NSArray *tableCells(NSString *line) {
    NSMutableArray *cells=[NSMutableArray array];NSMutableString *cell=[NSMutableString string];BOOL escaped=NO;
    for(NSUInteger i=0;i<[line length];i++) { unichar c=[line characterAtIndex:i];if(c=='|' && !escaped) { [cells addObject:[cell stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];[cell setString:@""]; }else { if(c=='|' && escaped && [cell length])[cell deleteCharactersInRange:NSMakeRange([cell length]-1,1)];CFStringAppendCharacters((CFMutableStringRef)cell,&c,1); }escaped=c=='\\' && !escaped; }
    [cells addObject:[cell stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];if([cells count] && ![[cells objectAtIndex:0] length])[cells removeObjectAtIndex:0];if([cells count] && ![[cells lastObject] length])[cells removeLastObject];return cells;
}
static BOOL tableSeparator(NSString *line) { NSArray *cells=tableCells(line);if([cells count]<2 || [cells count]>12)return NO;for(NSString *cell in cells) { NSString *s=[cell stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@": "]];if([s length]<3 || [s rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"-"] invertedSet]].location!=NSNotFound)return NO; }return YES; }
static NSDictionary *tableBlock(NSArray *lines) {
    NSMutableArray *rows=[NSMutableArray array];NSUInteger columns=[tableCells([lines objectAtIndex:0]) count];if(columns<2 || columns>12)return block(@"code",[lines componentsJoinedByString:@"\n"],0,nil,YES);
    NSUInteger widths[12]={0};
    for(NSUInteger i=0;i<[lines count];i++) { if(i==1)continue;NSArray *cells=tableCells([lines objectAtIndex:i]);[rows addObject:cells];for(NSUInteger j=0;j<MIN(columns,[cells count]);j++) widths[j]=MIN(32,MAX(widths[j],[[cells objectAtIndex:j] length])); }
    NSMutableString *formatted=[NSMutableString string];
    for(NSUInteger i=0;i<[rows count];i++) { NSArray *cells=[rows objectAtIndex:i];NSUInteger wrapped=1;for(NSUInteger j=0;j<MIN(columns,[cells count]);j++)wrapped=MAX(wrapped,([[cells objectAtIndex:j] length]+MAX(1,widths[j])-1)/MAX(1,widths[j]));
        for(NSUInteger k=0;k<wrapped;k++) { for(NSUInteger j=0;j<columns;j++) { NSString *cell=j<[cells count]?[cells objectAtIndex:j]:@"";NSUInteger start=k*MAX(1,widths[j]);NSString *part=start<[cell length]?[cell substringWithRange:NSMakeRange(start,MIN(MAX(1,widths[j]),[cell length]-start))]:@"";[formatted appendString:part];for(NSUInteger pad=[part length];pad<widths[j];pad++)[formatted appendString:@" "];if(j+1<columns)[formatted appendString:@" | "]; }[formatted appendString:@"\n"]; }
        if(i==0) { for(NSUInteger j=0;j<columns;j++) { for(NSUInteger k=0;k<widths[j];k++)[formatted appendString:@"-"];if(j+1<columns)[formatted appendString:@"-+-"]; }[formatted appendString:@"\n"]; }
    }
    NSMutableDictionary *result=[NSMutableDictionary dictionaryWithDictionary:block(@"table",formatted,0,nil,YES)];[result setObject:[lines componentsJoinedByString:@"\n"] forKey:@"source"];return result;
}
@implementation ORMarkdown
+ (NSArray *)blocks:(NSString *)source {
    if (![source isKindOfClass:[NSString class]]) source=@"";
    if ([source length]>131072) source=[[source substringWithRange:[source rangeOfComposedCharacterSequencesForRange:NSMakeRange(0,131072)]] stringByAppendingString:@"\n[Message truncated for display]"];
    source=[[source stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"] stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    NSMutableArray *out=[NSMutableArray array]; NSMutableString *paragraph=[NSMutableString string], *code=[NSMutableString string];
    NSString *fence=nil;NSUInteger codeLines=0;
    NSArray *lines=[source componentsSeparatedByString:@"\n"];
    for (NSUInteger lineIndex=0;lineIndex<[lines count];lineIndex++) {
        NSString *line=[lines objectAtIndex:lineIndex]; NSString *trim=[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        BOOL isFence=[trim hasPrefix:@"```"] || [trim hasPrefix:@"~~~"];
        if (fence) {
            if ([trim hasPrefix:fence]) { [out addObject:block(@"code",code,0,nil,YES)];[code setString:@""];fence=nil;codeLines=0; }
            else { if (codeLines++) [code appendString:@"\n"];[code appendString:line]; }
            continue;
        }
        if(lineIndex+1<[lines count] && [line rangeOfString:@"|"].location!=NSNotFound && tableSeparator([lines objectAtIndex:lineIndex+1])) {
            if([paragraph length]) { [out addObject:block(@"paragraph",paragraph,0,nil,NO)];[paragraph setString:@""]; }
            NSMutableArray *table=[NSMutableArray arrayWithObjects:line,[lines objectAtIndex:++lineIndex],nil];
            while(lineIndex+1<[lines count] && [[lines objectAtIndex:lineIndex+1] rangeOfString:@"|"].location!=NSNotFound)[table addObject:[lines objectAtIndex:++lineIndex]];
            [out addObject:tableBlock(table)];continue;
        }
        NSInteger heading=0; while (heading<6 && heading<(NSInteger)[trim length] && [trim characterAtIndex:heading]=='#') heading++;
        BOOL isHeading=heading>0 && (NSUInteger)heading<[trim length] && [trim characterAtIndex:heading]==' ';
        BOOL quote=[trim hasPrefix:@"> "]; BOOL list=[trim hasPrefix:@"- "] || [trim hasPrefix:@"* "] || [trim hasPrefix:@"+ "];
        NSUInteger digits=0;while(digits<[trim length] && [trim characterAtIndex:digits]>='0' && [trim characterAtIndex:digits]<='9')digits++;
        BOOL numbered=digits>0 && digits+1<[trim length] && ([trim characterAtIndex:digits]=='.' || [trim characterAtIndex:digits]==')') && [trim characterAtIndex:digits+1]==' ';
        BOOL rule=[trim isEqual:@"---"] || [trim isEqual:@"***"] || [trim isEqual:@"___"];
        if (![trim length] || isFence || isHeading || quote || list || numbered || rule) {
            if ([paragraph length]) { [out addObject:block(@"paragraph",paragraph,0,nil,NO)];[paragraph setString:@""]; }
            if (isFence) { fence=[trim substringToIndex:3];continue; }
            if (![trim length]) continue;
            if (rule) [out addObject:block(@"rule",@"",0,nil,NO)];
            else if(isHeading) [out addObject:block(@"heading",[trim substringFromIndex:heading+1],heading,nil,NO)];
            else if(quote) [out addObject:block(@"quote",[trim substringFromIndex:2],0,nil,NO)];
            else if(list||numbered) [out addObject:block(@"list",[trim substringFromIndex:numbered?digits+2:2],(NSInteger)([line length]-[trim length])/2,numbered?[trim substringToIndex:digits+1]:@"•",NO)];
        } else {
            if ([paragraph length]) [paragraph appendString:@"\n"];
            [paragraph appendString:line];
        }
    }
    if (fence) [out addObject:block(@"code",code,0,nil,YES)];
    if ([paragraph length]) [out addObject:block(@"paragraph",paragraph,0,nil,NO)];
    return out;
}
+ (NSString *)plainText:(NSString *)source {
    NSMutableArray *lines=[NSMutableArray array];
    for(NSDictionary *b in [self blocks:source]) {
        NSMutableString *line=[NSMutableString string];if([[b objectForKey:@"prefix"] length])[line appendFormat:@"%@ ",[b objectForKey:@"prefix"]];
        for(NSDictionary *r in [b objectForKey:@"runs"]) [line appendString:[r objectForKey:@"text"]];
        [lines addObject:line];
    }
    return [lines componentsJoinedByString:@"\n\n"];
}
@end
