import { Platform, processColor, type ColorValue } from 'react-native';

import NativeRNEmojiPicker from './NativeRNEmojiPicker';

export type EmojiPickerOptions = {
  /**
   * The selected category. iOS: also the search cursor and the keyboard's Done.
   * Without it, iOS uses the system tint and Android the theme's `colorAccent`.
   */
  tintColor?: ColorValue;
  /** Forces a light or dark picker, e.g. to follow an in-app appearance setting. */
  userInterfaceStyle?: 'unspecified' | 'light' | 'dark';
  /**
   * iOS: the language of the search keywords and section titles (`fr`, `pt-BR`…).
   * Defaults to the app's language. Android's picker follows the system.
   */
  locale?: string;
};

/** Anything with `measureInWindow`: a host component's ref, like a `View`'s. */
type Measurable = {
  measureInWindow(
    callback: (x: number, y: number, width: number, height: number) => void
  ): void;
};

export type EmojiPickerAnchor =
  Measurable | { current: Measurable | null } | null | undefined;

type Rect = { x: number; y: number; width: number; height: number };

const NO_ANCHOR: Rect = { x: 0, y: 0, width: 0, height: 0 };

/** `false` where the native module is missing (web, Expo Go). */
export const isAvailable = NativeRNEmojiPicker != null;

let isOpen = false;

function measure(anchor: EmojiPickerAnchor): Promise<Rect> {
  const view = anchor && 'current' in anchor ? anchor.current : anchor;
  // Android shows a bottom sheet: nothing to point at.
  if (!view || Platform.OS !== 'ios') {
    return Promise.resolve(NO_ANCHOR);
  }
  return new Promise((resolve) => {
    view.measureInWindow((x, y, width, height) =>
      resolve({ x, y, width, height })
    );
  });
}

/**
 * Opens the emoji picker and resolves with the emoji picked, or `null` when it was
 * dismissed. iOS: a popover pointing at `anchor` (a view or a ref to one).
 * Android: a Material 3 bottom sheet. A call while the picker is open resolves `null`.
 */
export async function openEmojiPicker(
  anchor: EmojiPickerAnchor,
  {
    tintColor,
    userInterfaceStyle = 'unspecified',
    locale,
  }: EmojiPickerOptions = {}
): Promise<string | null> {
  const native = NativeRNEmojiPicker;
  if (!native) {
    throw new Error('react-native-emoji-picker: native module missing');
  }
  if (isOpen) {
    return null;
  }
  isOpen = true;
  try {
    return await native.open({
      anchor: await measure(anchor),
      tintColor:
        tintColor == null ? undefined : (processColor(tintColor) as number),
      userInterfaceStyle,
      locale,
    });
  } finally {
    isOpen = false;
  }
}
