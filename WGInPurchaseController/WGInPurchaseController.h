//
//  WGInPurchaseController.h
//  
//
//  Created by Veeco on 07/02/2017.
//
//

#import <UIKit/UIKit.h>
@class WGInPurchaseController;

@protocol WGInPurchaseControllerDelegate <NSObject>

@optional

/**
 * 支付成功后回调
 */
- (void)didInPurchaseSucceedWithInPurchaseController:(nonnull __kindof WGInPurchaseController *)inPurchaseController;

@end

@interface WGInPurchaseController : UIViewController

/**
 * 获取单例对象
 */
+ (nonnull __kindof WGInPurchaseController *)controller;

/** 代理 */
@property (nonatomic, weak, nullable) id<WGInPurchaseControllerDelegate> delegate;

@end
