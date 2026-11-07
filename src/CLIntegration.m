#import "CLIntegration.h"
static NSString *escaped(NSString *s) { return [(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef)s,NULL,CFSTR("!*'();:@&=+$,/?%#[]"),kCFStringEncodingUTF8) autorelease]; }
NSURL *CLDraftURL(NSString *source,NSString *question,NSString *context) {
    if(![@"Habits" isEqual:source] && ![@"Sets" isEqual:source] && ![@"Cards" isEqual:source])return nil;
    NSString *text=[NSString stringWithFormat:@"%@\n\nProgress shared from %@:\n%@",question?:@"Help me choose a practical next step toward my goal.",source,context?:@""];
    if(![text length] || [text length]>12000)return nil;
    return [NSURL URLWithString:[NSString stringWithFormat:@"claude-ipod://compose?source=%@&text=%@",escaped(source),escaped(text)]];
}
NSString *CLDraftTextFromURL(NSURL *url,NSString **error) {
    if(![[[url scheme] lowercaseString] isEqual:@"claude-ipod"] || ![[url host] isEqual:@"compose"] || [[url absoluteString] length]>150000 || [[url path] length]>1 || [url user] || [url password] || [url port] || [url fragment])goto invalid;
    NSMutableDictionary *values=[NSMutableDictionary dictionary];
    for(NSString *part in [[url query] componentsSeparatedByString:@"&"]) {
        NSRange separator=[part rangeOfString:@"="];if(separator.location==NSNotFound)goto invalid;
        NSString *key=[part substringToIndex:separator.location],*value=[[part substringFromIndex:separator.location+1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if(!value || [values objectForKey:key] || (![key isEqual:@"text"] && ![key isEqual:@"source"]))goto invalid;[values setObject:value forKey:key];
    }
    NSString *source=[values objectForKey:@"source"],*text=[values objectForKey:@"text"];
    if((![source isEqual:@"Habits"] && ![source isEqual:@"Sets"] && ![source isEqual:@"Cards"]) || ![[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] || [text length]>12000)goto invalid;
    return text;
invalid: if(error)*error=@"This app draft could not be opened. Return to Habits, Sets or Cards and try again.";return nil;
}
