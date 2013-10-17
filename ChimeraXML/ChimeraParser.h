//
//  ChimeraParser.h


#import <Foundation/Foundation.h>

@interface ChimeraParser : NSObject<NSXMLParserDelegate>

-(id)initWithTargetClass:(Class)targetClass;
-(id)parse:(NSData *)data;
-(id)resultObject;

@end
