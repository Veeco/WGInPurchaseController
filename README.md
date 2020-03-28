# WGInPurchaseController
iOS内购控制器


公司的项目最近集成了iOS内购, 尽管网上有很多相当详细的内购集成教程, 但可能由于集成内购的应用比较少, 市场需求不大, 所以教程都比较旧, 而且有几个重点没有提及到, 以至于小弟我踩了不少的坑...所以在这里打算就内购的几个注意点作一个小小的补充, 希望可以一解大家在集成内购时所产生的困惑. 当然如果大家有好的做法也欢迎指正, 毕竟小弟也是第一次集成内购.

##1. 漏单问题
交易状态变化回调方法是由系统进行回调的, 无论是正在购买, 购买失败, 购买成功等都会被调用, 我们只需要在此方法中进行相应的操作即可. 
```objectivec
// 交易状态变化回调方法
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions NS_AVAILABLE_IOS(3_0);
```
一般来说, 对于消耗性商品, 我们用得最多的是在判断用户购买成功之后交给我们的服务器进行校验, 收到服务器的确认后把交易 finish 掉. 
```objectivec
// finish 交易
[[SKPaymentQueue defaultQueue] finishTransaction:transactions];
```
如果不把交易 finish 掉的话, 在下次重新打开应用待代码执行到监听内购队列后此方法都会被回调, 直到被 finish 掉为止. 所以为了防止漏单, 建议将内购抽类做成单例对象, 并在程序入口启动内购类, 第一时间监听内购队列. 这样做的话, 即使用户在成功购买商品后由于各种原因没告知服务器就关闭了应用, 在下次打开应用时也能及时把交易补回, 这样就不会造成漏单问题了.
```objectivec
// 监听内购队列
[[SKPaymentQueue defaultQueue] addTransactionObserver:_inPurchaseManager];
```
但事与愿违, 在调试中, 我们发现如果在有多个成功交易未 finish 掉的情况下把应用关闭后再打开, 往往会把其中某些任务漏掉, 即回调方法少回调了, 这让我们非常郁闷. 既然官方的API不好使, 我们只能把这个重任交给后台的验证流程了, 具体的做法下面会讲到.

##2. 验证问题
在确认用户成功支付后, 我们需要把验证密钥发送给服务器, 密钥的本身说白了其实就是一个文件, 我们需要把它转成 ns64 字符串再交给服务器, 服务器拿到我们的密钥后就可以去苹果的后台进行验证了. 可能大家会很好奇, 后台究竟是怎样进行验证的呢, 带着这个疑问, 我们不妨来模拟一下.

我们先把本地的密钥文件转成 ns64 字符串.
```objectivec
// 获取验证文件url
NSURL *pathUrl = [[NSBundle mainBundle] appStoreReceiptURL];
// 文件不存在 return
if (![[NSFileManager defaultManager] fileExistsAtPath:pathUrl.path]) return;        
// 把文件转成数据流
NSData *receiptData = [NSData dataWithContentsOfURL:pathUrl];
// 把数据流转成 ns64 字符串
NSString *baseString = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
```
没错, 这个 baseString 就是我们所说的密钥. 什么, 你想看看它长什么样? 相信我, 你不会想看的, 它就是一个大小约为7k的一大串字符. 另外, 苹果的验证接口有2个, 分别是调试接口和发布接口.
```
调试: https://sandbox.itunes.apple.com/verifyReceipt
发布: https://buy.itunes.apple.com/verifyReceipt
```
接下来我们就来模仿服务器的验证流程. 
```objectivec
// 设置请求参数(key是苹果规定的)
NSDictionary *param = @{@"receipt-data":baseString};
// 获取网络管理者
AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
// 设置请求格式为json
manager.requestSerializer = [AFJSONRequestSerializer serializer];
// 发出请求
[manager POST:@"https://sandbox.itunes.apple.com/verifyReceipt" parameters:param progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
      
    NSLog(@"responseObject = %@", responseObject);
        
} failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
    
    NSLog(@"error = %@", error);
}];
```
这里我们访问网络用的是 `AFNetworking` 框架, 需要注意的是这里必须要设置请求格式告诉苹果后台这是 json 格式, 不然苹果会不认识这些数据. 并且由于我们用的是沙盒测试账号, 所以访问的也是苹果的调试接口.

程序跑起来后, 很有可能会打印出错误日志, 提示`Request failed: unacceptable content-type: text/plain"`等一大串信息, 这是由于 `AFNetworking` 解析格式缺失的问题, 只要进入到 `AFURLResponseSerialization.m` 的源文件里, 在所属类 `AFJSONResponseSerializer` 中的 `init` 方法内添加一个字段即可.
```objectivec
- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    // 原来的样子
    // self.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", nil];
    // 添加后的样子
    self.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/plain", nil];

    return self;
}
```
现在再把程序跑起来就会看到如下的打印内容了.
```
responseObject = {
    environment = Sandbox;
    receipt =     {
        "adam_id" = 0;
        "app_item_id" = 0;
        "application_version" = "1.0.3.2";
        "bundle_id" = "**********";
        "download_id" = 0;
        "in_app" =         (
                        {
                "is_trial_period" = false;
                "original_purchase_date" = "2017-02-08 02:26:13 Etc/GMT";
                "original_purchase_date_ms" = 1486520773000;
                "original_purchase_date_pst" = "2017-02-07 18:26:13 America/Los_Angeles";
                "original_transaction_id" = 1000000271607744;
                "product_id" = "**********_06";
                "purchase_date" = "2017-02-08 02:26:13 Etc/GMT";
                "purchase_date_ms" = 1486520773000;
                "purchase_date_pst" = "2017-02-07 18:26:13 America/Los_Angeles";
                quantity = 1;
                "transaction_id" = 1000000271607744;
            },
                        {
                "is_trial_period" = false;
                "original_purchase_date" = "2017-02-25 05:59:35 Etc/GMT";
                "original_purchase_date_ms" = 1488002375000;
                "original_purchase_date_pst" = "2017-02-24 21:59:35 America/Los_Angeles";
                "original_transaction_id" = 1000000276891381;
                "product_id" = "**********_01";
                "purchase_date" = "2017-02-25 05:59:35 Etc/GMT";
                "purchase_date_ms" = 1488002375000;
                "purchase_date_pst" = "2017-02-24 21:59:35 America/Los_Angeles";
                quantity = 1;
                "transaction_id" = 1000000276891381;
            },
                        {
                "is_trial_period" = false;
                "original_purchase_date" = "2017-03-10 05:44:43 Etc/GMT";
                "original_purchase_date_ms" = 1489124683000;
                "original_purchase_date_pst" = "2017-03-09 21:44:43 America/Los_Angeles";
                "original_transaction_id" = 1000000280765165;
                "product_id" = "**********_01";
                "purchase_date" = "2017-03-10 05:44:43 Etc/GMT";
                "purchase_date_ms" = 1489124683000;
                "purchase_date_pst" = "2017-03-09 21:44:43 America/Los_Angeles";
                quantity = 1;
                "transaction_id" = 1000000280765165;
            }
        );
        "original_application_version" = "1.0";
        "original_purchase_date" = "2013-08-01 07:00:00 Etc/GMT";
        "original_purchase_date_ms" = 1375340400000;
        "original_purchase_date_pst" = "2013-08-01 00:00:00 America/Los_Angeles";
        "receipt_creation_date" = "2017-03-10 05:44:44 Etc/GMT";
        "receipt_creation_date_ms" = 1489124684000;
        "receipt_creation_date_pst" = "2017-03-09 21:44:44 America/Los_Angeles";
        "receipt_type" = ProductionSandbox;
        "request_date" = "2017-03-10 08:50:00 Etc/GMT";
        "request_date_ms" = 1489135800761;
        "request_date_pst" = "2017-03-10 00:50:00 America/Los_Angeles";
        "version_external_identifier" = 0;
    };
    status = 0;
}
```
安全起见, 这里我把一些不方便展示的内容用 * 代替了. 一开始看到这些可能会有点晕, 毕竟信息量有点大, 但其实有很多东西一般是用不上的. 这里面我们最关心的是 in_app 里的数组, 因为根据苹果的官方文档所示, 这些就是付款成功而未被 finish 掉的交易 (如下图所示, 此处苹果并没有说消耗性的商品会出现在列表里, 不过本人例子中的商品全都属于消耗性的, 有点不惑) , 而一般这个数组里只会存在一个元素, 这里会出现3个是因为这3个单子已经被苹果漏掉了, 是的, 这就是上面所提到的漏单情况, 回调方法是不会再走了, 恶心吧...
![1.png](https://upload-images.jianshu.io/upload_images/2404215-c5523cb347c61322.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

但生活还是得继续, 这里我们可以看到每个交易里都有一些很详细的信息, 一般我们只对 `original_transaction_id (交易ID)` 和 `product_id (商品ID)` 感兴趣, 服务器也是凭此作为用户购买成功的依据, 那么问题来了, 这里好像并没有用户的ID, 是的, 服务器是不知道商品是谁买的, 所以我们要把用户的ID和交易ID也一起发给服务器, 让服务器与验证返回的数据进行匹对, 从而把买家和商品对应起来. 
```objectivec
// 设置发送给服务器的参数
NSMutableDictionary *param = [NSMutableDictionary dictionary];
param[@"receipt"] = baseString;
param[@"userID"] = self.userID;
param[@"transactionID"] = transactions.transactionIdentifier;
```
来到这里, 刚才遗留的漏单问题是时候要拿出来解决了, 刚才也说到了, 回调方法有可能少走, 甚至还有可能在客户端启动后完全不走 (这个只是以防万一) , 我个人建议的做法是, 首先在服务端建立2个表, 一个黑一个白, 黑表是记录过往真正购买成功的历史信息, 白表是记录付款成功而未认领的交易信息. 在客户端启动后的10秒内 (时间可以自己定) 回调方法如果都没有走, 我们就主动把密钥上传给服务器, 当然最好把用户的一些信息, 包括账号ID, 手机型号, 系统版本等信息一并带上, 服务器拿到密钥后去苹果后台验证, 把得到的付款成功的交易信息全部写进白表里 (检测去重) . 以后如果有新交易产生, 客户端会把密钥和交易号等信息传给服务器, 服务器同样到苹果后台验证后写进白表, 接着在表里看看是否有客户端所给的交易号信息, 如果有再去黑表里检测是否存在, 黑表不存在则判断为成功购买并结算商品, 这时要在白表中删除对应数据和在黑表中添加新数据, 之后回馈给客户端, 客户端把交易 finish 掉这个购买流程就算是结束了. 这时候白表里记录着的很有可能就是一些被漏掉的单子, 为什么不是一定而是很有可能? 因为会存在已经记录在黑表中但未被客户端 finish 掉的单子, 此时再到黑表中滤一遍就知道是否是真正的漏单了, 这时候只能通过人工的方式去解决了, 比如可以主动跟这位用户沟通询问情况, 或者是在有用户反应漏单时, 可以在表中检测相关信息判断是否属实等等. 另外服务器可以定时检测两个表中的数据进行去重操作, 当然也可以在每次添加进白表前先在黑表中过滤, 不过这样比较耗性能. 目前想到的解决办法就是这样的, 如果有更好的想法希望大家可以给点思路.

好了, 调整一下心情咱们继续. 聪明的同学可能察觉到了, 上面说到苹果有2个验证的接口, 那后台应该访问哪个呢? 是这样的, 无论应用上线与否, 只要是用沙盒测试账号进行内购的, 就应该访问调试的接口, 相反, 如果是用普通账号进行内购的, 则要访问发布的接口, 当然了, 未上线的应用是不允许用普通账号进行内购的. 那么问题来了, 我们怎么知道用户是通过普通帐号还是沙盒测试账号来进行内购的呢? 别急, 苹果提供了相关的状态码来帮助我们解决这个问题.
```
21000    App Store 不能读取你提供的JSON对象
21002    receipt-data 域的数据有问题
21003    receipt 无法通过验证
21004    提供的 shared secret 不匹配你账号中的 shared secret
21005    receipt 服务器当前不可用
21006    receipt 合法, 但是订阅已过期. 服务器接收到这个状态码时, receipt 数据仍然会解码并一起发送
21007    receipt 是 Sandbox receipt, 但却发送至生产系统的验证服务
21008    receipt 是生产 receipt, 但却发送至 Sandbox 环境的验证服务
```
没错, 细心的朋友应该留意到了, 在刚刚那一大串的验证返回数据中有一个名为 status 的 key, 正常时值为0. 所以我们的做法是, 全部统一先访问发布接口, 在返回的数据中检测 status 的值, 如果为 21007 , 说明是通过沙盒测试账号进行内购的, 则再访问调试接口. 事实上苹果的官方推荐做法也是这样的.
![2.png](https://upload-images.jianshu.io/upload_images/2404215-b808b3d3cfc7a9c9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

##3. 误充问题
关于这个问题还是挺有趣的, 因为存在这样的一种情况: 用户A登录后买了一样商品, 但与服务器交互失败了, 导致没有把交易信息告知服务器, 接着他退出了当前帐号, 这时候用户B来了, 一登录服务器, 我们就会用当前用户ID把上次没有走完的内购逻辑继续走下去, 接下来的事情相信大家都能想像到了, 用户B会发现他获得了一件商品, 是的, 用户A买的东西被充到了用户B的手上. 

要解决这个问题必须要把交易和用户ID绑定起来, 要怎么做呢? 其实很简单, 我们只要在查询商品结果回调方法里, 在添加交易队列之前把用户ID设进去即可.
```objectivec
// 查询商品结果回调方法
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {

    // 遍历每一件商品
    for (SKProduct *product in response.products) {

        // 生成可变订单
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        // 设置用户ID
        payment.applicationUsername = self.userID;
        // 添加进交易队列
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}
```
然后给服务器发送的参数就不再像之前那样写了.
```objectivec
// 设置发送给服务器的参数
NSMutableDictionary *param = [NSMutableDictionary dictionary];
param[@"receipt"] = baseString;
// 之前
// param[@"userID"] = self.userID;
// 现在
param[@"userID"] = transactions.payment.applicationUsername;
param[@"transactionID"] = transactions.transactionIdentifier;
```
这样就不会有误充的问题了.

最后附上小弟写的内购工具类的github地址
https://github.com/Veeco/WGInPurchaseController

### 小弟第一次做内购, 如再发现一些坑或者有一些更好的处理方法时会继续补充. 另外大家如果有更好的观点或意见也欢迎多多指教, 谢谢!
