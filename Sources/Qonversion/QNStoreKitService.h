#import <StoreKit/StoreKit.h>


@protocol QNStoreKitServiceDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface QNStoreKitService : NSObject

@property (nonatomic, weak, nullable) id <QNStoreKitServiceDelegate> delegate;

- (instancetype)initWithDelegate:(id <QNStoreKitServiceDelegate>)delegate;

- (void)loadProducts:(NSSet <NSString *> *)products;
- (nullable SKProduct *)purchase:(NSString *)productID;
- (void)restore;
- (nullable SKProduct *)productAt:(NSString *)productID;

@end

@protocol QNStoreKitServiceDelegate <NSObject>

@optional
- (void)handleFailedTransaction:(SKPaymentTransaction *)transaction forProduct:(SKProduct *)product;
- (void)handlePurchasedTransaction:(SKPaymentTransaction *)transaction forProduct:(SKProduct *)product;
- (void)handleRestoreCompletedTransactionsFinished;
- (void)handleRestoreCompletedTransactionsFailed:(NSError *)error;
- (void)handleProducts:(NSArray<SKProduct *> *)products;
@end

NS_ASSUME_NONNULL_END