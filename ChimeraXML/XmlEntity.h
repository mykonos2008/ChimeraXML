//
//  XmlEntity.h


#import <Foundation/Foundation.h>

#import "PropertyInfo.h"

@interface XmlEntity : NSObject

+(PropertyInfo *)propertyInfoForElement:(NSString *)element;

@end
