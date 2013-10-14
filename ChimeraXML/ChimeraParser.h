//
//  XmlParser.h


#import <Foundation/Foundation.h>

@interface ChimeraParser : NSObject<NSXMLParserDelegate>

-(id)initWithTargetClass:(Class)targetClass;
-(id)resultObject;

@end
