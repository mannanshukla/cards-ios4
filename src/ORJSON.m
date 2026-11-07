#import "ORJSON.h"
#import <math.h>
@interface ORJSONParser : NSObject { unichar *buf;NSUInteger pos,len,depth;BOOL failed; }
- (id)initWithString:(NSString *)string;
- (id)document;
@end
static int hexDigit(unichar c) { return c>='0'&&c<='9'?c-'0':c>='a'&&c<='f'?c-'a'+10:c>='A'&&c<='F'?c-'A'+10:-1; }
@implementation ORJSONParser
- (id)initWithString:(NSString *)string { if((self=[super init])) { len=[string length];if(len>2097152) { [self release];return nil; }buf=malloc(MAX(len,1)*sizeof(unichar));if(!buf) { [self release];return nil; }[string getCharacters:buf range:NSMakeRange(0,len)]; }return self; }
- (void)dealloc { free(buf);[super dealloc]; }
- (unichar)peek { return pos<len?buf[pos]:0; }
- (void)space { while(pos<len && (buf[pos]==' '||buf[pos]=='\t'||buf[pos]=='\r'||buf[pos]=='\n'))pos++; }
- (id)bad { failed=YES;return nil; }
- (BOOL)consume:(NSString *)literal { NSUInteger n=[literal length];if(n>len-pos)return NO;for(NSUInteger i=0;i<n;i++)if(buf[pos+i]!=[literal characterAtIndex:i])return NO;pos+=n;return YES; }
- (int)unicode { if(len-pos<4) { failed=YES;return 0; }int v=0;for(int i=0;i<4;i++) { int digit=hexDigit(buf[pos++]);if(digit<0) { failed=YES;return 0; }v=v*16+digit; }return v; }
- (NSString *)string {
    if([self peek]!='"')return [self bad];pos++;NSMutableString *result=[NSMutableString string];
    while(pos<len) {
        unichar c=buf[pos++];if(c=='"')return result;if(c<32)return [self bad];
        if(c=='\\') {
            if(pos==len)return [self bad];unichar e=buf[pos++];
            switch(e) {
                case '"':c='"';break;case '\\':c='\\';break;case '/':c='/';break;case 'b':c='\b';break;case 'f':c='\f';break;case 'n':c='\n';break;case 'r':c='\r';break;case 't':c='\t';break;
                case 'u':c=[self unicode];if(failed)return nil;break;default:return [self bad];
            }
            if(c>=0xD800 && c<=0xDBFF) {
                if(![self consume:@"\\u"])return [self bad];unichar low=[self unicode];if(failed || low<0xDC00 || low>0xDFFF)return [self bad];unichar pair[]={c,low};CFStringAppendCharacters((CFMutableStringRef)result,pair,2);continue;
            }
            if(c>=0xDC00 && c<=0xDFFF)return [self bad];CFStringAppendCharacters((CFMutableStringRef)result,&c,1);
        } else {
            NSUInteger start=pos-1;while(pos<len && buf[pos]!='"' && buf[pos]!='\\' && buf[pos]>=32)pos++;
            for(NSUInteger i=start;i<pos;i++) {
                if(buf[i]>=0xD800 && buf[i]<=0xDBFF) { if(i+1>=pos || buf[i+1]<0xDC00 || buf[i+1]>0xDFFF)return [self bad];i++; }
                else if(buf[i]>=0xDC00 && buf[i]<=0xDFFF)return [self bad];
            }
            CFStringAppendCharacters((CFMutableStringRef)result,buf+start,pos-start);
        }
    }return [self bad];
}
- (BOOL)digit { return [self peek]>='0' && [self peek]<='9'; }
- (NSNumber *)number {
    NSUInteger start=pos;BOOL real=NO;if([self peek]=='-')pos++;
    if([self peek]=='0')pos++;else { if(![self digit])return [self bad];while([self digit])pos++; }
    if([self peek]=='.') { real=YES;pos++;if(![self digit])return [self bad];while([self digit])pos++; }
    if([self peek]=='e'||[self peek]=='E') { real=YES;pos++;if([self peek]=='+'||[self peek]=='-')pos++;if(![self digit])return [self bad];while([self digit])pos++; }
    NSString *number=[NSString stringWithCharacters:buf+start length:pos-start];double v=[number doubleValue];if(!isfinite(v))return [self bad];
    return real || v>=9223372036854775807.0 || v< -9223372036854775808.0?[NSNumber numberWithDouble:v]:[NSNumber numberWithLongLong:[number longLongValue]];
}
- (id)value {
    [self space];if(failed || pos>=len || depth>=64)return [self bad];unichar c=[self peek];
    if(c=='"')return [self string];
    if(c=='{'||c=='[') {
        BOOL object=c=='{';pos++;depth++;id result=object?(id)[NSMutableDictionary dictionary]:(id)[NSMutableArray array];[self space];unichar closing=object?'}':']';
        if([self peek]==closing) { pos++;depth--;return result; }
        while(!failed) {
            NSString *key=nil;
            if(object) { [self space];key=[self string];if(failed)return nil;[self space];if(![self consume:@":"])return [self bad]; }
            id next=[self value];if(failed || !next)return nil;if(object)[result setObject:next forKey:key];else [result addObject:next];[self space];
            if([self peek]==closing) { pos++;depth--;return result; }if(![self consume:@","])return [self bad];
        }return nil;
    }
    if([self consume:@"true"])return [NSNumber numberWithBool:YES];if([self consume:@"false"])return [NSNumber numberWithBool:NO];if([self consume:@"null"])return [NSNull null];
    if(c=='-' || [self digit])return [self number];return [self bad];
}
- (id)document { id value=[self value];[self space];return failed || pos!=len?nil:value; }
@end
@implementation ORJSON
+ (id)parse:(NSString *)text { if(![text isKindOfClass:[NSString class]])return nil;ORJSONParser *parser=[[ORJSONParser alloc] initWithString:text];id result=[parser document];[parser release];return result; }
+ (NSString *)escape:(NSString *)s {
    static NSCharacterSet *special = nil;
    if (!special) { NSMutableCharacterSet *m = [NSMutableCharacterSet characterSetWithRange:NSMakeRange(0, 0x20)]; [m addCharactersInString:@"\"\\"]; special = [m copy]; }
    if ([s rangeOfCharacterFromSet:special].location == NSNotFound) return s;   // nothing to escape: ids, names, most text
    NSMutableString *o = [NSMutableString stringWithCapacity:[s length]+8];
    NSUInteger n = [s length];
    for (NSUInteger i = 0; i < n; i++) {
        unichar c = [s characterAtIndex:i];
        switch (c) {
            case '"': [o appendString:@"\\\""]; break;
            case '\\': [o appendString:@"\\\\"]; break;
            case '\n': [o appendString:@"\\n"]; break;
            case '\r': [o appendString:@"\\r"]; break;
            case '\t': [o appendString:@"\\t"]; break;
            default:
                if (c < 0x20) [o appendFormat:@"\\u%04x", c];
                else CFStringAppendCharacters((CFMutableStringRef)o, &c, 1);
        }
    }
    return o;
}
+ (NSString *)stringify:(id)obj {
    if ([obj isKindOfClass:[NSString class]]) return [NSString stringWithFormat:@"\"%@\"", [self escape:obj]];
    if ([obj isKindOfClass:[NSNumber class]]) {
        if (strcmp([obj objCType], @encode(BOOL)) == 0 || strcmp([obj objCType], @encode(char)) == 0) return [obj boolValue] ? @"true" : @"false";
        return [obj stringValue];
    }
    if (obj == nil || [obj isKindOfClass:[NSNull class]]) return @"null";
    if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *parts = [NSMutableArray array];
        for (id v in obj) [parts addObject:[self stringify:v]];
        return [NSString stringWithFormat:@"[%@]", [parts componentsJoinedByString:@","]];
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableArray *parts = [NSMutableArray array];
        for (NSString *k in obj) [parts addObject:[NSString stringWithFormat:@"\"%@\":%@", [self escape:k], [self stringify:[obj objectForKey:k]]]];
        return [NSString stringWithFormat:@"{%@}", [parts componentsJoinedByString:@","]];
    }
    return [NSString stringWithFormat:@"\"%@\"", [self escape:[obj description]]];
}
@end
