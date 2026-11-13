package com.rnemojipicker

import android.content.Context
import android.content.res.Configuration
import android.content.res.ColorStateList
import android.view.ContextThemeWrapper
import android.view.View
import android.widget.ImageView
import com.google.android.material.color.MaterialColors
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.emoji2.emojipicker.EmojiPickerView
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.UiThreadUtil
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.android.material.bottomsheet.BottomSheetDragHandleView

/**
 * Google's EmojiPickerView (androidx.emoji2) in a Material 3 bottom sheet. It brings
 * its own categories, skin tones, recents and emoji compatibility. The sheet's colors
 * come from Theme.RNEmojiPicker (apps can redefine it). Resolves with the emoji picked,
 * or null when the sheet is dismissed (drag down, back, outside tap).
 */
class RNEmojiPickerModule(reactContext: ReactApplicationContext) :
  NativeRNEmojiPickerSpec(reactContext), LifecycleEventListener {

  private var dialog: BottomSheetDialog? = null

  init {
    reactContext.addLifecycleEventListener(this)
  }

  override fun open(options: ReadableMap, promise: Promise) {
    val activity = reactApplicationContext.currentActivity
    if (activity == null) {
      promise.reject("E_NO_ACTIVITY", "react-native-emoji-picker: no activity to show the picker in")
      return
    }
    val style = options.getString("userInterfaceStyle")
    val tint = if (options.hasKey("tintColor") && !options.isNull("tintColor")) {
      options.getDouble("tintColor").toInt()
    } else {
      null
    }

    UiThreadUtil.runOnUiThread {
      var result: String? = null
      // The theme goes to the dialog itself: over a wrapped context, BottomSheetDialog
      // falls back to its default light theme (white sheet in dark mode).
      val sheet = BottomSheetDialog(withNightMode(activity, style), R.style.Theme_RNEmojiPicker)
      val context = sheet.context

      val picker = EmojiPickerView(context).apply {
        setOnEmojiPickedListener { item ->
          result = item.emoji
          sheet.dismiss()
        }
      }
      val density = context.resources.displayMetrics.density
      val content = FrameLayout(context).apply {
        val side = (8 * density).toInt()
        // Edge to edge: keep the last row above the navigation bar.
        val bottom = ViewCompat.getRootWindowInsets(activity.window.decorView)
          ?.getInsets(WindowInsetsCompat.Type.navigationBars())?.bottom ?: 0
        setPadding(side, 0, side, bottom)
        addView(
          BottomSheetDragHandleView(context),
          FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        )
        // Below the handle: the handle is 48dp of touch target.
        addView(
          picker,
          FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT).apply {
            topMargin = (48 * density).toInt()
          }
        )
      }
      if (tint != null) {
        tintCategories(picker, tint)
      }
      val height = (activity.resources.displayMetrics.heightPixels * 0.6).toInt()
      sheet.setContentView(content, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, height))
      sheet.behavior.apply {
        state = BottomSheetBehavior.STATE_EXPANDED
        skipCollapsed = true
      }
      sheet.setOnDismissListener {
        dialog = null
        promise.resolve(result)
      }
      dialog = sheet
      sheet.show()
    }
  }

  /**
   * The selected category's icon and underline in `tint`. EmojiPickerView takes them
   * from the theme's colorAccent, which can't change at runtime, so its header views
   * are recolored as they're laid out. Looked up by name: if a later emoji2 renames
   * them, the picker keeps the theme's color.
   */
  private fun tintCategories(picker: EmojiPickerView, tint: Int) {
    val resources = picker.resources
    val packageName = picker.context.packageName
    val iconId = resources.getIdentifier("emoji_picker_header_icon", "id", packageName)
    val underlineId = resources.getIdentifier("emoji_picker_header_underline", "id", packageName)
    if (iconId == 0 && underlineId == 0) return

    val normal = MaterialColors.getColor(picker, android.R.attr.colorControlNormal, tint)
    // Same states as the library's icon_tint_selector, with the tint for colorAccent.
    val colors = ColorStateList(
      arrayOf(intArrayOf(android.R.attr.state_selected), intArrayOf()),
      intArrayOf(tint, normal)
    )
    fun apply(view: View) {
      when (view.id) {
        iconId -> (view as? ImageView)?.takeIf { it.imageTintList !== colors }?.imageTintList = colors
        underlineId -> view.takeIf { it.backgroundTintList !== colors }?.backgroundTintList = colors
      }
      if (view is ViewGroup) {
        for (index in 0 until view.childCount) apply(view.getChildAt(index))
      }
    }
    picker.viewTreeObserver.addOnGlobalLayoutListener { apply(picker) }
  }

  /** The activity's context, or one forced light or dark. */
  private fun withNightMode(context: Context, style: String?): Context {
    val mode = when (style) {
      "light" -> Configuration.UI_MODE_NIGHT_NO
      "dark" -> Configuration.UI_MODE_NIGHT_YES
      else -> return context
    }
    val configuration = Configuration(context.resources.configuration)
    configuration.uiMode = (configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or mode
    return ContextThemeWrapper(context, 0).apply { applyOverrideConfiguration(configuration) }
  }

  override fun onHostResume() = Unit

  override fun onHostPause() = Unit

  override fun onHostDestroy() {
    if (dialog != null) {
      UiThreadUtil.runOnUiThread { dialog?.dismiss() }
    }
  }

  override fun invalidate() {
    onHostDestroy()
    super.invalidate()
  }

  companion object {
    const val NAME = NativeRNEmojiPickerSpec.NAME
  }
}
