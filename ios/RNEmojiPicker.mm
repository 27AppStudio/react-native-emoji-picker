#import "RNEmojiPicker.h"

#import <React/RCTConvert.h>
#import <React/RCTUtils.h>
#import <UIKit/UIKit.h>

#if __has_include(<RNEmojiPicker/RNEmojiPicker-Swift.h>)
#import <RNEmojiPicker/RNEmojiPicker-Swift.h>
#else
#import "RNEmojiPicker-Swift.h"
#endif

@implementation RNEmojiPicker

+ (NSString *)moduleName
{
  return @"RNEmojiPicker";
}

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

static UIUserInterfaceStyle InterfaceStyle(NSString *style)
{
  if ([style isEqualToString:@"light"]) {
    return UIUserInterfaceStyleLight;
  }
  if ([style isEqualToString:@"dark"]) {
    return UIUserInterfaceStyleDark;
  }
  return UIUserInterfaceStyleUnspecified;
}

- (void)open:(JS::NativeRNEmojiPicker::OpenOptions &)options
     resolve:(RCTPromiseResolveBlock)resolve
      reject:(RCTPromiseRejectBlock)reject
{
  UIViewController *presenter = RCTPresentedViewController();
  if (presenter == nil || presenter.view.window == nil) {
    reject(@"E_NO_PRESENTER", @"react-native-emoji-picker: no view controller to present from", nil);
    return;
  }

  auto anchor = options.anchor();
  CGRect rect = CGRectMake(anchor.x(), anchor.y(), anchor.width(), anchor.height());
  std::optional<double> tint = options.tintColor();
  UIColor *tintColor = tint.has_value() ? [RCTConvert UIColor:@(tint.value())] : nil;

  [RNEmojiPickerController presentFrom:presenter
                                anchor:rect
                             tintColor:tintColor
                        interfaceStyle:InterfaceStyle(options.userInterfaceStyle())
                                locale:options.locale()
                              onFinish:^(NSString *_Nullable emoji) {
                                resolve(emoji ?: (id)[NSNull null]);
                              }];
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeRNEmojiPickerSpecJSI>(params);
}

@end
