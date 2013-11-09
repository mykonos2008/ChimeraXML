//
//  XmlParser.m

#import "ChimeraParser.h"
#import "CPElementInfo.h"
#import "CPXmlEntity.h"
#import "CPPropertyInfo.h"
#import "CPPropertyCache.h"

#import <objc/runtime.h>

@implementation ChimeraParser{
    
    NSMutableArray *_elementStack;
    id _rootObject; //デシリアライズ結果のオブジェクト
    int _depth; //現在処理しているXMLの階層を示す変数
}

-(id)initWithTargetClass:(Class)targetClass
{
    self = [super init];
    if(self){
        _elementStack = [NSMutableArray array];
        _rootObject = [[targetClass alloc] init];
    }
    return self;
}

-(id)parse:(NSData *)data
{
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.delegate = self;
    [parser parse];
    
    return _rootObject;
}

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    if(_depth > [_elementStack count]){
        _depth++;
        return;
    }
    
    _depth++;   
    
    //ルート要素の場合
    if([_elementStack count] == 0){
        //最上位階層の情報を管理するElementInfoを生成し、Stackにつめる
        CPElementInfo *info = [[CPElementInfo alloc] init];
        info.elementName = elementName;
        info.target = _rootObject;

        [_elementStack addObject:info];
    }
    //ルート要素以外の場合
    else{
        //親要素の情報を取り出す
        CPElementInfo *parent = [_elementStack lastObject];
        
        //親要素がコレクションの場合
        if([parent.target isKindOfClass:[NSArray class]]){
            CPElementInfo *info = [[CPElementInfo alloc] init];
            info.elementName = elementName;
            
            info.propInfo = [[CPPropertyInfo alloc] init];
            info.propInfo.type = parent.propInfo.subType;            
            
            if(parent.propInfo.subType == [NSString class] || parent.propInfo.subType == [NSNumber class]) {
                info.target = [[NSMutableString alloc] init];
            }
            else {
                info.target = [[parent.propInfo.subType alloc] init];
            }
            [parent.target addObject:info.target];
            [_elementStack addObject:info];
        }
        else{
            //Userクラスから要素に対応するプロパティの情報を取得する
            id propObject = [[parent.target class] propertyInfoForElement:elementName];
            if(!propObject) {
                return;
            }
            
            CPPropertyInfo *propInfo = nil;
            if([propObject isMemberOfClass:[CPPropertyInfo class]]) {
                propInfo = propObject;
            }
            else {
                propInfo = [CPPropertyCache propertyInfoForClass:NSStringFromClass([parent.target class]) propertyName:propObject];
                if(!propInfo) {
                    propInfo = [[CPPropertyInfo alloc] init];
                    propInfo.name = propObject;
                    [CPPropertyCache setPropertyInfo:propInfo forClass:NSStringFromClass([parent.target class]) propertyName:propObject];
                }
            }

            //プロパティが存在しているかチェックする
            objc_property_t prop =  class_getProperty([parent.target class], [propInfo.name UTF8String]);
            if(prop){
               
                if(!propInfo.type) {
                    //プロパティの型を取得する
                    NSString *attributes = [NSString stringWithUTF8String:property_getAttributes(prop)];
                    NSRegularExpression *reg = [[NSRegularExpression alloc] initWithPattern:@"^T@\"(.*)\",.*"
                                                                options:NSRegularExpressionCaseInsensitive error:nil];
                    NSArray *matches = [reg matchesInString:attributes options:0 range:NSMakeRange(0, attributes.length)];
                    
                    for (NSTextCheckingResult *result in matches) {
                        for (int i = 0; i < [result numberOfRanges]; i++) {
                            if(i == 1) {
                                NSRange range = [result rangeAtIndex:i];
                                propInfo.type = NSClassFromString([attributes substringWithRange:range]);
                            }
                        }
                    }
                }
                
                //要素を管理するElementInfoを生成し、Stackにつめる
                CPElementInfo *info = [[CPElementInfo alloc] init];
                info.elementName = elementName;
                info.propInfo = propInfo;
                
                //プロパティの型に応じて処理を分ける
                //NSStringの場合
                if(propInfo.type == [NSString class] || propInfo.type == [NSNumber class]){
                    info.target = [[NSMutableString alloc] init];
                }
                //コレクションの場合
                else if(propInfo.type == [NSArray class] || propInfo.type == [NSMutableArray class]){
                    if(!propInfo.subType) {
                        [NSException raise:@"InvalidPropertyException" format:@"Subtype must be provided for [%@]",propInfo.name];    
                    }
                    
                    if(propInfo.directArray) {
                        NSMutableArray *parentArray = [parent.target valueForKey:propInfo.name];
                        if(!parentArray) {
                            parentArray = [NSMutableArray array];
                            [parent.target setValue:parentArray forKey:propInfo.name];
                        }                        
                     
                        if(propInfo.subType == [NSString class] || propInfo.subType == [NSNumber class]) {
                            info.target = [[NSMutableString alloc] init];
                        }
                        else {
                            info.target = [[propInfo.subType alloc] init];
                        }
                        [parentArray addObject:info.target];
                        info.directParentArray = parentArray;
                    }
                    else {
                       info.target = [NSMutableArray array];
                       [parent.target setValue:info.target forKey:propInfo.name];
                    }
                }
                //XMLエンティティの場合
                else if([propInfo.type isSubclassOfClass:[CPXmlEntity class]]) {
                    info.target = [[propInfo.type alloc] init];
                    [parent.target setValue:info.target forKey:propInfo.name];
                }
                else{
                    [NSException raise:@"InvalidPropertyException" format:@"Type of Property [%@] cannot be handled.",propInfo.name];
                }
                
                [_elementStack addObject:info];
            }
            else{
                [NSException raise:@"InvalidPropertyException" format:@"Property [%@] not found.",propInfo.name];
            }
        }
    }
}

-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if(_depth == [_elementStack count]){
        //スタックにつめられている最後のオブジェクトを取得し、その要素名が引数のelementNameと一致するか判定する
        CPElementInfo *lastElement = [_elementStack lastObject];
        if([lastElement.elementName isEqualToString:elementName]){
            //targetオブジェクトがNSMutableStringの場合(テキストノードの場合）
            if([lastElement.target isKindOfClass:[NSMutableString class]]){
                //もう一つ上の階層のオブジェクトのプロパティにテキストノードの値を設定する
                CPElementInfo *parentElement = [_elementStack objectAtIndex:[_elementStack count] -2];
                
                if(((parentElement.propInfo.type == [NSArray class] || parentElement.propInfo.type == [NSMutableArray class])
                     && [parentElement.target isKindOfClass:[NSArray class]])
                   || lastElement.directParentArray) {
                    
                    NSMutableArray *parentArray = nil;
                    if(lastElement.directParentArray) {
                        parentArray = lastElement.directParentArray;
                    }
                    else {
                        parentArray = parentElement.target;
                    }
                    
                    if(lastElement.propInfo.type == [NSNumber class] || lastElement.propInfo.subType == [NSNumber class]){
                        [parentArray removeObject:lastElement.target];
                        //check if number
                        NSRange match = [lastElement.target rangeOfString:@"^([1-9]\\d*|0)(\\.\\d+)?$" options:NSRegularExpressionSearch];
                        if(match.location != NSNotFound) {
                            match = [lastElement.target rangeOfString:@"." options:NSCaseInsensitiveSearch];
                            //check if double
                            if(match.location != NSNotFound) {
                                double doubleValue = [lastElement.target doubleValue];
                                [parentArray addObject:[NSNumber numberWithDouble:doubleValue]];
                            }
                            else {
                                int intValue = [lastElement.target intValue];
                                [parentArray addObject:[NSNumber numberWithInt:intValue]];
                            }
                        }
                    }
                }
                else {
                    if(lastElement.propInfo.type == [NSString class]) {
                        [parentElement.target setValue:lastElement.target forKey:lastElement.propInfo.name];
                    }
                    else if(lastElement.propInfo.type == [NSNumber class]){
                        //check if number
                        NSRange match = [lastElement.target rangeOfString:@"^([1-9]\\d*|0)(\\.\\d+)?$" options:NSRegularExpressionSearch];
                        if(match.location != NSNotFound) {
                            match = [lastElement.target rangeOfString:@"." options:NSCaseInsensitiveSearch];
                            //check if double
                            if(match.location != NSNotFound) {
                                double doubleValue = [lastElement.target doubleValue];
                                [parentElement.target setValue:[NSNumber numberWithDouble:doubleValue] forKey:lastElement.propInfo.name];
                            }
                            else {
                                int intValue = [lastElement.target intValue];
                                [parentElement.target setValue:[NSNumber numberWithInt:intValue] forKey:lastElement.propInfo.name];
                            }
                        }
                    }
                }
            }
        }
        
        [_elementStack removeLastObject];
        
    }
    _depth--;
}

-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    //stackの最後のオブジェクトがNSMutableStringの場合、テキストノードの値をそれにつめる
    CPElementInfo *lastElement = [_elementStack lastObject];
    if([lastElement.target isKindOfClass:[NSMutableString class]]){
        [((NSMutableString *)lastElement.target) appendString:string];
    }
}

//解析結果のオブジェクトを返却する
-(id)resultObject
{
    return _rootObject;
}

@end
