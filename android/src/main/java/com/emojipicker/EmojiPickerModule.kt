package com.emojipicker

import com.facebook.react.bridge.ReactApplicationContext

class EmojiPickerModule(reactContext: ReactApplicationContext) :
  NativeEmojiPickerSpec(reactContext) {

  override fun multiply(a: Double, b: Double): Double {
    return a * b
  }

  companion object {
    const val NAME = NativeEmojiPickerSpec.NAME
  }
}
