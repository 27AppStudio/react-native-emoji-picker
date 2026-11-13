// Detox drives the example on an iOS simulator: pick it with E2E_IOS_DEVICE (a
// simulator name or UDID).
const iosDevice = process.env.E2E_IOS_DEVICE ?? 'iPhone 17 Pro';
const byUdid = /^[0-9A-F-]{36}$/i.test(iosDevice);

/** @type {Detox.DetoxConfig} */
module.exports = {
  testRunner: {
    args: { $0: 'jest', config: 'e2e/jest.config.js' },
    jest: { setupTimeout: 180_000 },
  },
  apps: {
    'ios.debug': {
      type: 'ios.app',
      binaryPath:
        'ios/build/Build/Products/Debug-iphonesimulator/EmojiPickerExample.app',
      build:
        'xcodebuild -workspace ios/EmojiPickerExample.xcworkspace -scheme EmojiPickerExample -configuration Debug -sdk iphonesimulator -derivedDataPath ios/build',
    },
  },
  devices: {
    simulator: {
      type: 'ios.simulator',
      device: byUdid ? { id: iosDevice } : { type: iosDevice },
    },
  },
  configurations: {
    'ios.sim.debug': { device: 'simulator', app: 'ios.debug' },
  },
};
