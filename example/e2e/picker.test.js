/* global describe, it, beforeAll */
/* global device, element, by, expect, waitFor */

// The example bundle comes from Metro: METRO_PORT when it isn't on 8081 (iOS reads
// RCT_jsLocation from the launch arguments).
const port = process.env.METRO_PORT;
const launchArgs =
  port && device.getPlatform() === 'ios'
    ? { RCT_jsLocation: `localhost:${port}` }
    : {};
const shoot = (name) =>
  process.env.E2E_SCREENSHOTS ? device.takeScreenshot(name) : undefined;

describe('emoji picker', () => {
  beforeAll(async () => {
    await device.launchApp({ newInstance: true, launchArgs });
  });

  it('returns the emoji tapped', async () => {
    await element(by.id('open-top')).tap();
    await waitFor(element(by.id('😀')))
      .toBeVisible()
      .withTimeout(5000);
    await shoot('top');
    await element(by.id('😀')).tap();
    await expect(element(by.id('log'))).toHaveText('Picked 😀');
  });

  it('lists the last pick under recents', async () => {
    await element(by.id('open-bottom')).tap();
    await waitFor(element(by.id('😀')).atIndex(0))
      .toBeVisible()
      .withTimeout(5000);
    await shoot('bottom-recents');
    await element(by.id('emoji-picker-search')).typeText('pizza');
    await shoot('typed');
    // In the popover above the keyboard, Detox's visibility check never passes.
    await waitFor(element(by.id('🍕')).atIndex(0))
      .toExist()
      .withTimeout(5000);
    await shoot('search');
    await element(by.id('🍕')).atIndex(0).tap();
    await expect(element(by.id('log'))).toHaveText('Picked 🍕');
  });

  it('offers skin tones on long press', async () => {
    await element(by.id('open-top')).tap();
    await element(by.id('emoji-picker-search')).typeText('waving');
    await waitFor(element(by.id('👋')).atIndex(0))
      .toExist()
      .withTimeout(5000);
    await element(by.id('👋')).atIndex(0).longPress();
    await shoot('pressed');
    await waitFor(element(by.id('👋🏽')))
      .toExist()
      .withTimeout(5000);
    await shoot('tones');
    await element(by.id('👋🏽')).tap();
    await expect(element(by.id('log'))).toHaveText('Picked 👋🏽');
  });
});
