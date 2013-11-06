//
//  ElementInfo.h

#import <Foundation/Foundation.h>
@class CPPropertyInfo;

@interface CPElementInfo : NSObject

//一つ下の階層の要素の値をセットする先となるオブジェクト
@property(strong,nonatomic) id target;

//要素名
@property(strong,nonatomic) NSString *elementName;

//要素に対応するプロパティの情報を管理するオブジェクト
@property(strong,nonatomic) CPPropertyInfo *propInfo;

@end
