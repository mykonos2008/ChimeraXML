//
//  CPPropertyCache.m
//  ChimeraXML

#import "CPPropertyCache.h"

@implementation CPPropertyCache

static NSMutableDictionary *_cacheDic;

+ (void)initialize
{
    _cacheDic = [NSMutableDictionary dictionary];
}

+ (void)setPropertyInfo:(CPPropertyInfo *)propertyInfo forClass:(NSString *)className propertyName:(NSString *)propertyName;
{
    if(![self propertyInfoForClass:className propertyName:propertyName]) {
        NSString *key = [NSString stringWithFormat:@"%@;%@",className,propertyName];
        _cacheDic[key] = propertyInfo;
    }
}

+ (CPPropertyInfo *)propertyInfoForClass:(NSString *)className propertyName:(NSString *)propertyName
{
    NSString *key = [NSString stringWithFormat:@"%@;%@",className,propertyName];
    return _cacheDic[key];
}

@end
