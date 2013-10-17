//
//  PropertyInfo.h


#import <Foundation/Foundation.h>

@interface CPPropertyInfo : NSObject

@property(strong,nonatomic) NSString *name;
@property(strong,nonatomic) Class type;
@property(strong,nonatomic) Class subType;

@end
