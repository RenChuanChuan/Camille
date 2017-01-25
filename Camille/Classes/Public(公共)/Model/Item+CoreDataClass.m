//
//  Item+CoreDataClass.m
//  Camille
//
//  Created by 杨淳引 on 2017/1/24.
//  Copyright © 2017年 shayneyeorg. All rights reserved.
//

#import "Item+CoreDataClass.h"

//缓存
static BOOL needUpdate; //以下这4个容器类对象的内容是否过期，由needUpdate来标识
static NSMutableDictionary *itemNameMapper; //key为itemID，value为itemName
static NSMutableDictionary *itemTypeMapper; //key为itemID，value为itemType
static NSMutableArray *incomeItems; //存放所有的收入item
static NSMutableArray *costItems; //存放所有的支出item

@implementation Item

#pragma mark - Life Cycle

+ (void)load {
    CMLLog(@"%s", __func__);
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        needUpdate = YES;
        itemNameMapper = [NSMutableDictionary dictionary];
        itemTypeMapper = [NSMutableDictionary dictionary];
        incomeItems = [NSMutableArray array];
        costItems = [NSMutableArray array];
    });
}

#pragma mark - Pubilc



#pragma mark - 数据状态管理

+ (void)_setNeedUpdate {
    needUpdate = YES;
}

+ (BOOL)_needUpdate {
    return needUpdate;
}

+ (void)_update {
    
}

#pragma mark - 添加item

+ (void)addItemWithName:(NSString *)itemName type:(NSString *)type callBack:(void(^)(CMLResponse *response))callBack {
    //1、先判断itemName是否存在
    //request和entity
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Item" inManagedObjectContext:kManagedObjectContext];
    [request setEntity:entity];
    
    //设置查询条件
    NSString *str = [NSString stringWithFormat:@"itemName == '%@' AND itemType == '%@'", itemName, type];
    NSPredicate *pre = [NSPredicate predicateWithFormat:str];
    [request setPredicate:pre];
    
    //Response
    CMLResponse *cmlResponse = [[CMLResponse alloc]init];
    
    //2、查询
    NSError *error = nil;
    NSMutableArray *items = [[kManagedObjectContext executeFetchRequest:request error:&error] mutableCopy];
    if (items == nil) {
        //3、查询过程中出错
        CMLLog(@"查询item出错:%@,%@",error,[error userInfo]);
        callBack(nil);
        
    } else if (items.count) {
        //4、查询发现item已存在
        Item *theExistItem = items[0];
        
        if (theExistItem) {
            if ([theExistItem.isAvailable isEqualToString:Record_Available]) {
                //查询对象是有效的
                CMLLog(@"添加的item已存在并且是有效的");
                cmlResponse.responseDic = [NSDictionary dictionaryWithObjectsAndKeys:theExistItem.itemID, KEY_ItemID, theExistItem, KEY_Item,  nil];
                cmlResponse.code = RESPONSE_CODE_FAILD;
                cmlResponse.desc = kTipExist;
                callBack(cmlResponse);
                
            } else {
                //查询对象之前被删除过，将它复原即可
                CMLLog(@"添加的item被删除过，只需复原即可");
                [self restoreItem:theExistItem callBack:^(CMLResponse *response) {
                    if (response && [response.code isEqualToString:RESPONSE_CODE_SUCCEED]) {
                        cmlResponse.responseDic = [NSDictionary dictionaryWithObjectsAndKeys:theExistItem.itemID, KEY_ItemID, theExistItem, KEY_Item,  nil];
                        cmlResponse.code = RESPONSE_CODE_SUCCEED;
                        cmlResponse.desc = kTipRestore;
                        [self _setNeedUpdate];
                        callBack(cmlResponse);
                        
                    } else {
                        [self _setNeedUpdate];
                        callBack(nil);
                    }
                }];
            }
            
        } else {
            callBack(nil);
        }
        
    } else {
        //5、查询发现item不存在，需要添加
        NSString *newID = [self createNewItemID];
        if (newID == nil) {
            CMLLog(@"分配itemID时出错");
            callBack(nil);
            
        } else {
            //Entity
            Item *item = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:kManagedObjectContext];
            item.itemName = itemName;
            item.itemID = newID;
            item.itemType = type;
            item.isAvailable = Record_Available;
            item.useCount = 0;
            
            //保存
            NSError *error = nil;
            if ([kManagedObjectContext save:&error]) {
                if (error) {
                    CMLLog(@"添加item时发生错误:%@,%@",error,[error userInfo]);
                    [self _setNeedUpdate];
                    callBack(nil);
                    
                } else {
                    cmlResponse.code = RESPONSE_CODE_SUCCEED;
                    cmlResponse.desc = kTipSaveSuccess;
                    CMLLog(@"新增item(%@)成功", itemName);
                    cmlResponse.responseDic = [NSDictionary dictionaryWithObjectsAndKeys:item, KEY_Item, nil];
                    [self _setNeedUpdate];
                    callBack(cmlResponse);
                }
                
            } else {
                [self _setNeedUpdate];
                callBack(nil);
            }
        }
    }
}

//复原item
+ (void)restoreItem:(Item *)item callBack:(void(^)(CMLResponse *response))callBack {
    item.isAvailable = Record_Available;
    CMLResponse *response = [[CMLResponse alloc]init];
    NSError *error = nil;
    if ([kManagedObjectContext save:&error]) {
        CMLLog(@"复原item成功");
        response.code = RESPONSE_CODE_SUCCEED;
        callBack(response);
        
    } else {
        CMLLog(@"复原item失败");
        callBack(nil);
    }
}

//为新item创建ID
+ (NSString *)createNewItemID {
    //分配一个ID并检查新分配ID在当前一级科目下是否有重名，有则返回nil
    NSString *newID = [self createANewItemID];
    if (![self verifyItemID:newID]) {
        return nil;
    }
    
    //返回新分配的二级科目ID
    return newID;
}

//为新item创建ID
+ (NSString *)createANewItemID {
    //用当前时间做ID
    NSDate *now = [NSDate date];
    NSDateFormatter *fmt = [[NSDateFormatter alloc]init];
    [fmt setDateFormat:@"YYYYMMddHHmmss"];
    fmt.locale = [[NSLocale alloc]initWithLocaleIdentifier:@"en_US"];
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
    [fmt setTimeZone:timeZone];
    NSString *newID = [fmt stringFromDate:now];
    return newID;
}

//校验新ID
+ (BOOL)verifyItemID:(NSString *)newID {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Item" inManagedObjectContext:kManagedObjectContext];
    [request setEntity:entity];
    
    NSString *str = [NSString stringWithFormat:@"itemID == '%@'", newID];
    NSPredicate *pre = [NSPredicate predicateWithFormat:str];
    [request setPredicate:pre];
    
    NSError *error = nil;
    NSMutableArray *items = [[kManagedObjectContext executeFetchRequest:request error:&error] mutableCopy];
    if (!error && !items.count) {
        return YES;
        
    } else {
        return NO;
    }
}

#pragma mark - 删除item

+ (void)deleteItem:(Item *)item callBack:(void(^)(CMLResponse *response))callBack {
    item.isAvailable = Record_Unavailable;
    CMLResponse *response = [[CMLResponse alloc]init];
    NSError *error = nil;
    if ([kManagedObjectContext save:&error]) {
        CMLLog(@"删除item成功");
        response.code = RESPONSE_CODE_SUCCEED;
        [self _setNeedUpdate];
        callBack(response);
        
    } else {
        CMLLog(@"删除item失败");
        [self _setNeedUpdate];
        callBack(nil);
    }
}

#pragma mark - 查询item

+ (void)fetchItemsWithType:(Item_Fetch_Type)itemFetchType callBack:(void(^)(CMLResponse *response))callBack {
    //request和entity
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Item" inManagedObjectContext:kManagedObjectContext];
    [request setEntity:entity];
    
    //Response
    CMLResponse *cmlResponse = [[CMLResponse alloc]init];
    
    //设置查询条件
    switch (itemFetchType) {
        case Item_Fetch_Cost: {
            NSString *str = [NSString stringWithFormat:@"itemType == '%@'", Item_Type_Cost];
            NSPredicate *pre = [NSPredicate predicateWithFormat:str];
            [request setPredicate:pre];
        }
            break;
            
        case Item_Fetch_Income: {
            NSString *str = [NSString stringWithFormat:@"itemType == '%@'", Item_Type_Income];
            NSPredicate *pre = [NSPredicate predicateWithFormat:str];
            [request setPredicate:pre];
        }
            break;
            
        case Item_Fetch_All:
        default:
            break;
    }
    
    //查询
    NSError *error = nil;
    NSMutableArray *items = [[kManagedObjectContext executeFetchRequest:request error:&error] mutableCopy];
    
    //取数据
    if (items == nil) {
        CMLLog(@"查询items时发生错误:%@,%@", error, [error userInfo]);
        callBack(nil);
        
    } else {
        cmlResponse.code = RESPONSE_CODE_SUCCEED;
        cmlResponse.desc = kTipFetchSuccess;
        [items sortUsingComparator:^NSComparisonResult(Item *i1, Item *i2) {
            return [@(i2.useCount) compare:@(i1.useCount)];
        }];
        cmlResponse.responseDic = [NSDictionary dictionaryWithObjectsAndKeys:items, KEY_Items, nil];
        callBack(cmlResponse);
    }
}

@end
