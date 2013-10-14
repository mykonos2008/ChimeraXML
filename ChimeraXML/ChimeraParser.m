//
//  XmlParser.m

#import "ChimeraParser.h"
#import "ElementInfo.h"
#import "XmlEntity.h"
#import "PropertyInfo.h"

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
        ElementInfo *info = [[ElementInfo alloc] init];
        info.elementName = elementName;
        info.target = _rootObject;

        [_elementStack addObject:info];
    }
    //ルート要素以外の場合
    else{
        //親要素の情報を取り出す
        ElementInfo *parent = [_elementStack lastObject];
        
        //親要素がコレクションの場合
        if([parent.target isKindOfClass:[NSArray class]]){
            ElementInfo *info = [[ElementInfo alloc] init];
            info.elementName = elementName;
            info.target = [[parent.propInfo.subType alloc] init];
            [parent.target addObject:info.target];
            [_elementStack addObject:info];
        }
        else{
            //Userクラスから要素に対応するプロパティの情報を取得する
            PropertyInfo *propInfo =[[parent.target class] propertyInfoForElement:elementName];
            if(!propInfo){
                return;
            }
            //プロパティが存在しているかチェックする
            objc_property_t prop =  class_getProperty([parent.target class], [propInfo.name UTF8String]);
            if(prop){
               
                //要素を管理するElementInfoを生成し、Stackにつめる
                ElementInfo *info = [[ElementInfo alloc] init];
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
                    info.target = [NSMutableArray array];
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
        ElementInfo *lastElement = [_elementStack lastObject];
        if([lastElement.elementName isEqualToString:elementName]){
            //targetオブジェクトがNSMutableStringの場合(テキストノードの場合）
            if([lastElement.target isKindOfClass:[NSMutableString class]]){
                //もう一つ上の階層のオブジェクトのプロパティにテキストノードの値を設定する
                ElementInfo *parentElement = [_elementStack objectAtIndex:[_elementStack count] -2];
                
                if(lastElement.propInfo.type == [NSString class]) {
                    [parentElement.target setValue:lastElement.target forKey:lastElement.propInfo.name];
                }
                else if(lastElement.propInfo.type == [NSNumber class]){
                    int intValue = [lastElement.target intValue];
                    [parentElement.target setValue:[NSNumber numberWithInt:intValue] forKey:lastElement.propInfo.name];
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
    ElementInfo *lastElement = [_elementStack lastObject];
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
