//
//  QNAutomationsViewController.m
//  Qonversion
//
//  Created by Surik Sarkisyan on 23.09.2020.
//  Copyright © 2020 Qonversion Inc. All rights reserved.
//

#import "QNAutomationsViewController.h"
#import "QNAutomationsService.h"
#import "QNAutomationsFlowAssembly.h"
#import "QNActionsHandler.h"
#import "QONAction.h"
#import "QNAutomationScreen.h"
#import "QNAutomationConstants.h"

#import "Qonversion.h"
#import <WebKit/WebKit.h>
#import <SafariServices/SafariServices.h>

@interface QNAutomationsViewController () <WKNavigationDelegate>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@end

@implementation QNAutomationsViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.webView = [WKWebView new];
  self.webView.navigationDelegate = self;
  [self.view addSubview:self.webView];
  
  self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
  self.activityIndicator.color = [UIColor lightGrayColor];
  self.activityIndicator.hidesWhenStopped = YES;
  [self.view addSubview:self.activityIndicator];
  
  [self.webView loadHTMLString:self.htmlString baseURL:nil];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
    
  self.webView.frame = self.view.frame;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
  
  BOOL isActionShouldBeHandeled = [self.actionsHandler isActionShouldBeHandled:navigationAction];
  if (!isActionShouldBeHandeled) {
    decisionHandler(WKNavigationActionPolicyAllow);
    return;
  }
  
  decisionHandler(WKNavigationActionPolicyCancel);
  
  [self handleAction:navigationAction];
}

- (void)showErrorAlertWithTitle:(NSString *)title message:(NSString *)message {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
  
  UIAlertAction *action = [UIAlertAction actionWithTitle:kAutomationErrorOkActionTitle style:UIAlertActionStyleCancel handler:nil];
  [alert addAction:action];
  
  [self.navigationController presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Private

#pragma mark Actions

- (void)handleAction:(WKNavigationAction *)navigationAction {
  QONAction *action = [self.actionsHandler prepareDataForAction:navigationAction];
  
  switch (action.type) {
    case QONActionTypeLink: {
      [self handleLinkAction:action];
      break;
    }
    case QONActionTypeDeeplink: {
      [self handleDeepLinkAction:action];
      break;
    }
    case QONActionTypeClose:
      [self handleCloseAction:action];
      break;
    case QONActionTypePurchase: {
      [self handlePurchaseAction:action];
      break;
    }
    case QONActionTypeRestorePurchases: {
      [self handleRestoreAction:action];
      break;
    }
    case QONActionTypeNavigation: {
      [self handleNavigationAction:action];
      break;
    }
    default:
      break;
  }
}

- (void)handleLinkAction:(QONAction *)action {
  NSString *urlString = action.value[kAutomationValueKey];
  if (urlString.length > 0) {
    NSURL *url = [NSURL URLWithString:urlString];
    SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:url];
    [self.navigationController presentViewController:safariViewController animated:true completion:nil];
  }
}

- (void)handleCloseAction:(QONAction *)action {
  [self dismissViewControllerAnimated:YES completion:nil];
  [self.delegate automationsViewController:self didFinishAction:action];
}

- (void)handleDeepLinkAction:(QONAction *)action {
  NSString *deeplinkString = action.value[kAutomationValueKey];
  if (deeplinkString.length > 0) {
    NSURL *url = [NSURL URLWithString:deeplinkString];
    [[UIApplication sharedApplication] openURL:url];
  }
}

- (void)handlePurchaseAction:(QONAction *)action {
  NSString *productID = action.value[kAutomationValueKey];
  if (productID.length > 0) {
    [self.activityIndicator startAnimating];
    __block __weak QNAutomationsViewController *weakSelf = self;
    [Qonversion purchase:productID completion:^(NSDictionary<NSString *,QNPermission *> * _Nonnull result, NSError * _Nullable error, BOOL cancelled) {
      [weakSelf.activityIndicator stopAnimating];
      
      if (cancelled) {
        return;
      }
      
      if (error) {
        [weakSelf showErrorAlertWithTitle:kAutomationErrorAlertTitle message:error.localizedDescription];
        return;
      }
      
      [weakSelf.delegate automationsViewController:weakSelf didFinishAction:action];
      [weakSelf dismissViewControllerAnimated:YES completion:nil];
    }];
  }
}

- (void)handleRestoreAction:(QONAction *)action {
  __block __weak QNAutomationsViewController *weakSelf = self;
  [self.activityIndicator startAnimating];
  [Qonversion restoreWithCompletion:^(NSDictionary<NSString *,QNPermission *> * _Nonnull result, NSError * _Nullable error) {
    [weakSelf.activityIndicator stopAnimating];
    if (error) {
      [weakSelf showErrorAlertWithTitle:kAutomationErrorAlertTitle message:error.localizedDescription];
      return;
    }
    
    [weakSelf.delegate automationsViewController:weakSelf didFinishAction:action];
    [weakSelf dismissViewControllerAnimated:YES completion:nil];
  }];
}

- (void)handleNavigationAction:(QONAction *)action {
  NSString *automationID = action.value[kAutomationValueKey];
  __block __weak QNAutomationsViewController *weakSelf = self;
  [self.activityIndicator startAnimating];
  [self.automationsService automationWithID:automationID completion:^(QNAutomationScreen *screen, NSError * _Nullable error) {
    [weakSelf.activityIndicator stopAnimating];
    if (screen.htmlString) {
      QNAutomationsViewController *viewController = [weakSelf.flowAssembly configureAutomationsViewControllerWithHtmlString:screen.htmlString delegate:weakSelf.delegate];
      [weakSelf.automationsService trackScreenShownWithID:automationID];
      [weakSelf.navigationController pushViewController:viewController animated:YES];
    } else if (error) {
      [weakSelf showErrorAlertWithTitle:kAutomationShowScreenErrorAlertTitle message:error.localizedDescription];
    }
  }];
}

@end
