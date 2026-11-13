import { isAvailable, openEmojiPicker } from '../index';

// Web and Expo Go: no native module.
jest.mock('../NativeRNEmojiPicker', () => ({
  __esModule: true,
  default: null,
}));

describe('without the native module', () => {
  it('is not available', () => {
    expect(isAvailable).toBe(false);
  });

  it('rejects', async () => {
    await expect(openEmojiPicker(null)).rejects.toThrow(
      'native module missing'
    );
  });
});
