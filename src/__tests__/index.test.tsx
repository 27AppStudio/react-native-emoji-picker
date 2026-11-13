import { Platform, processColor } from 'react-native';

import NativeRNEmojiPicker from '../NativeRNEmojiPicker';
import { isAvailable, openEmojiPicker } from '../index';

jest.mock('../NativeRNEmojiPicker', () => ({
  __esModule: true,
  default: { open: jest.fn() },
}));

const nativeOpen = NativeRNEmojiPicker!.open as jest.Mock;

const anchorAt = (x: number, y: number, width: number, height: number) => ({
  measureInWindow: (callback: (...rect: number[]) => void) =>
    callback(x, y, width, height),
});

describe('react-native-emoji-picker', () => {
  beforeEach(() => {
    nativeOpen.mockReset();
    Platform.OS = 'ios';
  });

  it('is available when the native module is', () => {
    expect(isAvailable).toBe(true);
  });

  it('opens at the anchor, in window coordinates, with the options', async () => {
    nativeOpen.mockResolvedValue('🍕');

    const picked = await openEmojiPicker(
      { current: anchorAt(10, 20, 56, 56) },
      { tintColor: 'red', userInterfaceStyle: 'dark', locale: 'fr' }
    );

    expect(picked).toBe('🍕');
    expect(nativeOpen).toHaveBeenCalledWith({
      anchor: { x: 10, y: 20, width: 56, height: 56 },
      tintColor: processColor('red'),
      userInterfaceStyle: 'dark',
      locale: 'fr',
    });
  });

  it('takes the view itself as well as a ref', async () => {
    nativeOpen.mockResolvedValue(null);

    await openEmojiPicker(anchorAt(1, 2, 3, 4));

    expect(nativeOpen.mock.calls[0][0]).toMatchObject({
      anchor: { x: 1, y: 2, width: 3, height: 4 },
      tintColor: undefined,
      userInterfaceStyle: 'unspecified',
    });
  });

  it('resolves null when dismissed', async () => {
    nativeOpen.mockResolvedValue(null);

    await expect(openEmojiPicker(null)).resolves.toBeNull();
    expect(nativeOpen.mock.calls[0][0].anchor).toEqual({
      x: 0,
      y: 0,
      width: 0,
      height: 0,
    });
  });

  it('does not measure on Android, where the picker is a bottom sheet', async () => {
    Platform.OS = 'android';
    nativeOpen.mockResolvedValue('😀');
    const measureInWindow = jest.fn();

    await openEmojiPicker({ measureInWindow });

    expect(measureInWindow).not.toHaveBeenCalled();
  });

  it('resolves null for a second call while the picker is open', async () => {
    let close: (emoji: string | null) => void = () => {};
    nativeOpen.mockReturnValue(
      new Promise((resolve) => {
        close = resolve;
      })
    );

    const first = openEmojiPicker(anchorAt(0, 0, 1, 1));
    await expect(openEmojiPicker(anchorAt(0, 0, 1, 1))).resolves.toBeNull();
    close('😀');

    await expect(first).resolves.toBe('😀');
    expect(nativeOpen).toHaveBeenCalledTimes(1);
  });

  it('opens again once the previous picker failed', async () => {
    nativeOpen.mockRejectedValueOnce(new Error('no presenter'));
    nativeOpen.mockResolvedValueOnce('😀');

    await expect(openEmojiPicker(null)).rejects.toThrow('no presenter');
    await expect(openEmojiPicker(null)).resolves.toBe('😀');
  });
});
