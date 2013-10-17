//
//  XmlEntity.h


#import <Foundation/Foundation.h>

#import "CPPropertyInfo.h"

@interface CPXmlEntity : NSObject

+(CPPropertyInfo *)propertyInfoForElement:(NSString *)element;

@end
