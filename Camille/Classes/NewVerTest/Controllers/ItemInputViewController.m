//
//  ItemInputViewController.m
//  Camille
//
//  Created by 杨淳引 on 2017/2/5.
//  Copyright © 2017年 shayneyeorg. All rights reserved.
//

#import "ItemInputViewController.h"
#import "CMLDataManager.h"

@interface ItemInputViewController () <UITextFieldDelegate>

@property (nonatomic, assign) CGRect initialPosition;
@property (nonatomic, copy) NSString *itemType;
@property (nonatomic, strong) NSArray *itemsArr;

@property (nonatomic, strong) UIView *backgroundView;

@property (nonatomic, strong) UIView *inputFieldBackgroundView;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIButton *dismissBtn;
@property (nonatomic, strong) UIButton *confirmBtn;

@end

@implementation ItemInputViewController

#pragma mark - Life Cycle

+ (instancetype)initWithInitialPosition:(CGRect)initialPosition itemType:(NSString *)itemType {
    ItemInputViewController *itemInputViewController = [ItemInputViewController new];
    itemInputViewController.initialPosition = initialPosition;
    itemInputViewController.itemType = itemType;
    return itemInputViewController;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self configBackgroundView];
    
    if (self.initialPosition.size.width > 0 && self.initialPosition.size.height > 0 && self.itemType.length) {
        [CMLDataManager fetchItemsWithItemType:self.itemType callback:^(CMLResponse *response) {
            if (PHRASE_ResponseSuccess && [response.responseDic[KEY_Items] isKindOfClass:[NSArray class]]) {
                self.itemsArr = response.responseDic[KEY_Items];
                
                self.inputFieldBackgroundView = [[UIView alloc]initWithFrame:self.initialPosition];
                self.inputFieldBackgroundView.backgroundColor = RGB(230, 230, 230);
                self.inputFieldBackgroundView.layer.cornerRadius = 5;
                self.inputFieldBackgroundView.clipsToBounds = YES;
                [self.backgroundView addSubview:self.inputFieldBackgroundView];
                
                self.inputField = [[UITextField alloc]initWithFrame:CGRectMake(10, 0, self.inputFieldBackgroundView.width - 20, self.inputFieldBackgroundView.height)];
                self.inputField.delegate = self;
                self.inputField.placeholder = @"项目";
                self.inputField.backgroundColor = RGB(230, 230, 230);
                self.inputField.borderStyle = UITextBorderStyleNone;
                [self.inputFieldBackgroundView addSubview:self.inputField];
                self.inputField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                
                [self configDismissBtn];
                [self configConfirmBtn];
                [self startInitialAnamation];
                
            } else {
                CMLLog(@"数据出错");
            }
        }];
        
        
    } else {
        CMLLog(@"需要使用initWithInitialPosition:方法先指定inputField的初始位置");
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - UI Configuration

- (void)configBackgroundView {
    self.backgroundView = [[UIView alloc]initWithFrame:self.view.frame];
    self.backgroundView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.backgroundView];
}

- (void)startInitialAnamation {
    CMLLog(@"%f", self.backgroundView.frame.size.width);
    [UIView animateWithDuration:0.2 animations:^{
        self.inputFieldBackgroundView.frame = CGRectMake(10, 30, self.backgroundView.frame.size.width - 20, self.inputFieldBackgroundView.frame.size.height);
        
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2 animations:^{
            self.inputFieldBackgroundView.frame = CGRectMake(10, 30, self.backgroundView.frame.size.width - 70, self.inputFieldBackgroundView.frame.size.height);
            self.dismissBtn.frame = CGRectMake(self.backgroundView.frame.size.width - 50, 30, 40, self.inputFieldBackgroundView.frame.size.height);
            self.dismissBtn.alpha = 1;
            
            [self.inputField becomeFirstResponder];
            
        } completion:^(BOOL finished) {
            
        }];
    }];
}

#pragma mark - Private

- (void)showConfirmBtn {
    self.confirmBtn.hidden = NO;
    self.dismissBtn.hidden = YES;
}

- (void)showDismissBtn {
    self.confirmBtn.hidden = YES;
    self.dismissBtn.hidden = NO;
}

- (void)dismiss {
    if (self.dismissBlock) {
        [self.dismissBtn removeFromSuperview];
        [self.confirmBtn removeFromSuperview];
        [UIView animateWithDuration:0.2 animations:^{
            self.inputFieldBackgroundView.frame = self.initialPosition;
            
        } completion:^(BOOL finished) {
            self.dismissBlock(nil);
        }];
    }
}

- (void)confirm {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"itemName == %@", self.inputField.text];
    NSArray *selectedItems = [self.itemsArr filteredArrayUsingPredicate:predicate];
    if (selectedItems.count) {
        //此item已存在
        if (self.dismissBlock) {
            Item *selectedItem = selectedItems.firstObject;
            [self.dismissBtn removeFromSuperview];
            [self.confirmBtn removeFromSuperview];
            [UIView animateWithDuration:0.2 animations:^{
                self.inputFieldBackgroundView.frame = self.initialPosition;
                
            } completion:^(BOOL finished) {
                self.dismissBlock(selectedItem.itemID);
            }];
        }
        
    } else {
        //此item不存在
        [CMLDataManager addItemWithName:self.inputField.text type:self.itemType callBack:^(CMLResponse * _Nonnull response) {
            if (response && [response.code isEqualToString:RESPONSE_CODE_SUCCEED]) {
                Item *selectedItem = response.responseDic[KEY_Item];
                [self.dismissBtn removeFromSuperview];
                [self.confirmBtn removeFromSuperview];
                [UIView animateWithDuration:0.2 animations:^{
                    self.inputFieldBackgroundView.frame = self.initialPosition;
                    
                } completion:^(BOOL finished) {
                    self.dismissBlock(selectedItem.itemID);
                }];
            }
        }];
    }
}

#pragma mark - Getter

- (void)configDismissBtn {
    self.dismissBtn = [[UIButton alloc]initWithFrame:CGRectMake(self.backgroundView.frame.size.width, 30, 40, self.inputFieldBackgroundView.frame.size.height)];
    self.dismissBtn.backgroundColor = [UIColor clearColor];
    self.dismissBtn.alpha = 0;
    [self.dismissBtn setTitle:@"取消" forState:UIControlStateNormal];
    [self.dismissBtn setTitleColor:kAppTextColor forState:UIControlStateNormal];
    [self.dismissBtn addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [self.backgroundView addSubview:self.dismissBtn];
}

- (void)configConfirmBtn {
    self.confirmBtn = [[UIButton alloc]initWithFrame:CGRectMake(self.backgroundView.frame.size.width - 50, 30, 40, self.inputFieldBackgroundView.frame.size.height)];
    self.confirmBtn.backgroundColor = [UIColor clearColor];
    [self.confirmBtn setTitle:@"确定" forState:UIControlStateNormal];
    [self.confirmBtn setTitleColor:kAppTextColor forState:UIControlStateNormal];
    [self.confirmBtn addTarget:self action:@selector(confirm) forControlEvents:UIControlEventTouchUpInside];
    self.confirmBtn.hidden = YES;
    [self.backgroundView addSubview:self.confirmBtn];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSMutableString *newText = textField.text.mutableCopy;
    [newText replaceCharactersInRange:range withString:string];
    if (newText.length > 0) {
        [self showConfirmBtn];
        
    } else {
        [self showDismissBtn];
    }
    
    return YES;
}

@end
