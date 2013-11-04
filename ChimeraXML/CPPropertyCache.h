//
//  CPPropertyCache.h
//  ChimeraXML

#import <Foundation/Foundation.h>
#import "CPPropertyInfo.h"

@interface CPPropertyCache : NSObject

+ (void)setPropertyInfo:(CPPropertyInfo *)propertyInfo forClass:(NSString *)className propertyName:(NSString *)propertyName;
+ (CPPropertyInfo *)propertyInfoForClass:(NSString *)className propertyName:(NSString *)propertyName;

@end
