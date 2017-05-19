//
//  WGInPurchaseController.m
//  
//
//  Created by Veeco on 07/02/2017.
//
//

#import "WGInPurchaseController.h"
#import <StoreKit/StoreKit.h>

// 商品ID头
#define kProductPrefix @"com.xx.xxx_"

@interface WGInPurchaseController ()<SKProductsRequestDelegate, SKPaymentTransactionObserver>

@end

@implementation WGInPurchaseController

// 单例
static id _contrller;

/**
 * 获取单例对象
 */
+ (nonnull __kindof WGInPurchaseController *)controller {

    return [self allocWithZone:nil];
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        _contrller = [[super allocWithZone:zone] init];
        
        // 添加内购队列监听
        [[SKPaymentQueue defaultQueue] addTransactionObserver:_contrller];
    });
    return _contrller;
}

#pragma mark - <入口>

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 初始化UI
    [self setupUI];
}

#pragma mark - <常规逻辑>

/**
 * 初始化UI
 */
- (void)setupUI {

    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapVCView)]];
}

/**
 * 监听VC的VIEW点击 -> 从父VIEW移除VC的VIEW
 */
- (void)didTapVCView {

    [self.view removeFromSuperview];
}

/**
 * 监听商品点击
 */
- (void)didClickProduct {

    // 不支持内购直接 return
    if (![SKPaymentQueue canMakePayments]) return;
    
    // TODO:商品编号
    // ......
    
    // 生成商品集合
    NSString *productStr = [NSString stringWithFormat:@"%@%zd", kProductPrefix, 0];
    NSArray *productArr = @[productStr];
    NSSet *productSet = [NSSet setWithArray:productArr];
    
    // 访问苹果服务器
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:productSet];
    request.delegate = self;
    [request start];
}

/**
 * 购买成功后处理
 */
- (void)didInPurchaseSucceedWithTransactions:(SKPaymentTransaction *)transactions {

    // 获取验证文件url
    NSURL *pathUrl = [[NSBundle mainBundle] appStoreReceiptURL];
    // 文件不存在 return
    if (![[NSFileManager defaultManager] fileExistsAtPath:pathUrl.path]) return;
    // 把文件转成数据流
    NSData *receiptData = [NSData dataWithContentsOfURL:pathUrl];
    // 把数据流转成 ns64 字符串
    NSString *baseString = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    
    // 设置请求参数
    NSMutableDictionary *param = [NSMutableDictionary dictionary];
    param[@"receipt"] = baseString;
    param[@"userID"] = transactions.payment.applicationUsername;
    param[@"transactionID"] = transactions.transactionIdentifier;
    
    // TODO:为防止意外漏单, 把用户ID和交易ID本地化起来, 在下次APP启动时判断存在用户ID和交易ID时重走此方法与服务器进行交互, 当然了, 在确认成功后finish掉交易时要记得把本地化数据清空.
    
    // TODO:向服务器发送验证请求
    // ......
    
    // TODO:得到服务器确认后执行代理方法并将交易从队列中移除
    // if ......
    
    if ([self.delegate respondsToSelector:@selector(didInPurchaseSucceedWithInPurchaseController:)]) {
        
        [self.delegate didInPurchaseSucceedWithInPurchaseController:self];
    }
    [[SKPaymentQueue defaultQueue] finishTransaction:transactions];
}

#pragma mark - <SKProductsRequestDelegate>

/**
 * 查询商品结果回调方法
 */
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    
    // 遍历每一件商品
    for (SKProduct *product in response.products) {
        
        // 生成可变订单
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        
        // TODO:设置用户ID
        // ......
        
        payment.applicationUsername = @"用户ID";
        
        // 添加进交易队列
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}

#pragma mark - <SKPaymentTransactionObserver>

/**
 * 交易状态变化回调方法
 */
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {

    for (SKPaymentTransaction *transaction in transactions) {
        
        switch (transaction.transactionState) {
                
                // 交易成功
            case SKPaymentTransactionStatePurchased:
                [self didInPurchaseSucceedWithTransactions:transaction];
                break;
                
                // 交易失败
            case SKPaymentTransactionStateFailed:
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
                
                // 正在交易
            case SKPaymentTransactionStatePurchasing:break;
                
                // 已够买过
            case SKPaymentTransactionStateRestored:break;
                
                // 状态未确定
            case SKPaymentTransactionStateDeferred:break;
                
            default:break;
        }
    }
}

@end
