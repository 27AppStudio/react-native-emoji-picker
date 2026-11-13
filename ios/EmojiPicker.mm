#import "EmojiPicker.h"

@implementation EmojiPicker
- (NSNumber *)multiply:(double)a b:(double)b {
  NSNumber *result = @(a * b);

  return result;
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeEmojiPickerSpecJSI>(params);
}

+ (NSString *)moduleName
{
  return @"EmojiPicker";
}

@end
