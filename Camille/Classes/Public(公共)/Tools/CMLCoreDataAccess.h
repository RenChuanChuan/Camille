//
//  CMLCoreDataAccess.h
//  Camille
//
//  Created by 杨淳引 on 16/2/28.
//  Copyright © 2016年 shayneyeorg. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CMLAccounting.h"
#import "CMLResponse.h"

@interface CMLCoreDataAccess : NSObject

/**
 *  保存账务
 *
 *  @param item         项目名称
 *  @param amount       项目金额
 *  @param happenTime   发生时间
 *  @param callBack     回调
 */
+ (void)addAccountingWithItem:(NSString *)item amount:(NSNumber *)amount happneTime:(NSDate *)happenTime callBack:(void(^)(CMLResponse *response))callBack;

@end
