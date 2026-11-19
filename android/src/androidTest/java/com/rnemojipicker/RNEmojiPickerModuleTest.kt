package com.rnemojipicker

import android.content.res.Configuration
import android.graphics.Color
import android.widget.ImageView
import androidx.emoji2.emojipicker.EmojiPickerView
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.Espresso.pressBack
import androidx.test.espresso.NoMatchingRootException
import androidx.test.espresso.NoMatchingViewException
import androidx.test.espresso.ViewAssertion
import androidx.test.espresso.ViewInteraction
import androidx.test.espresso.action.CoordinatesProvider
import androidx.test.espresso.action.GeneralClickAction
import androidx.test.espresso.action.Press
import androidx.test.espresso.action.Tap
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.RootMatchers.isDialog
import androidx.test.espresso.matcher.ViewMatchers.isAssignableFrom
import androidx.test.espresso.matcher.ViewMatchers.isDisplayed
import androidx.test.espresso.matcher.ViewMatchers.isSelected
import androidx.test.espresso.matcher.ViewMatchers.withClassName
import androidx.test.espresso.matcher.ViewMatchers.withId
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.facebook.react.bridge.BridgeReactContext
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.WritableMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.hamcrest.BaseMatcher
import org.hamcrest.Description
import org.hamcrest.Matcher
import org.hamcrest.Matchers.allOf
import org.hamcrest.Matchers.`is`
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The module against the real bottom sheet and EmojiPickerView: a test activity stands
 * in for the React Native host, and Espresso taps what a user would.
 */
@RunWith(AndroidJUnit4::class)
class RNEmojiPickerModuleTest {
  private lateinit var scenario: ActivityScenario<TestActivity>
  private lateinit var reactContext: BridgeReactContext
  private lateinit var module: RNEmojiPickerModule

  @Before
  fun setUp() {
    scenario = ActivityScenario.launch(TestActivity::class.java)
    scenario.onActivity { activity ->
      reactContext = BridgeReactContext(activity.applicationContext)
      module = RNEmojiPickerModule(reactContext)
      reactContext.onHostResume(activity)
    }
  }

  @After
  fun tearDown() {
    scenario.onActivity { module.invalidate() }
    idle()
    scenario.close()
  }

  @Test
  fun pickingAnEmojiResolvesWithIt() {
    val promise = TestPromise()
    module.open(options(), promise)
    // The emoji list loads in the background.
    eventually { firstEmoji().check(matches(isDisplayed())) }
    var shown: CharSequence? = null
    firstEmoji().check { view, noView ->
      if (view == null) throw noView
      // EmojiView is internal; its description is the emoji, then " emoji".
      shown = view.contentDescription
    }
    assertNotNull(shown)
    firstEmoji().perform(click())
    assertEquals(shown.toString().substringBefore(' '), promise.await())
    assertNoSheet()
  }

  @Test
  fun backResolvesNull() {
    val promise = TestPromise()
    module.open(options(), promise)
    picker().check(matches(isDisplayed()))
    pressBack()
    assertNull(promise.await())
  }

  @Test
  fun tapOutsideResolvesNull() {
    val promise = TestPromise()
    module.open(options(), promise)
    picker().check(matches(isDisplayed()))
    awaitSheetSettled()
    // The sheet covers the bottom 60%, the status bar the very top.
    val aboveTheSheet = CoordinatesProvider { view ->
      val origin = IntArray(2).also(view::getLocationOnScreen)
      floatArrayOf(origin[0] + view.width / 2f, origin[1] + view.height * 0.15f)
    }
    onView(withId(com.google.android.material.R.id.touch_outside))
      .inRoot(isDialog())
      .perform(GeneralClickAction(Tap.SINGLE, aboveTheSheet, Press.FINGER))
    assertNull(promise.await())
  }

  @Test
  fun hostDestroyDismissesTheSheet() {
    val promise = TestPromise()
    module.open(options(), promise)
    picker().check(matches(isDisplayed()))
    scenario.onActivity { reactContext.onHostDestroy() }
    assertNull(promise.await())
    assertNoSheet()
  }

  @Test
  fun rejectsWithoutAnActivity() {
    val promise = TestPromise()
    val detached = RNEmojiPickerModule(BridgeReactContext(ApplicationProvider.getApplicationContext()))
    detached.open(options(), promise)
    promise.await()
    assertEquals("E_NO_ACTIVITY", promise.rejectCode)
  }

  @Test
  fun userInterfaceStyleForcesLightOrDark() {
    var activityMode = 0
    scenario.onActivity { activityMode = it.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK }
    for ((style, night) in listOf(
      "dark" to Configuration.UI_MODE_NIGHT_YES,
      "light" to Configuration.UI_MODE_NIGHT_NO,
    )) {
      val promise = TestPromise()
      module.open(options(style = style), promise)
      picker().check { view, noView ->
        if (view == null) throw noView
        val mode = view.context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        assertEquals(style, night, mode)
      }
      pressBack()
      promise.await()
      // Only the sheet: the activity keeps its own mode.
      scenario.onActivity {
        assertEquals(activityMode, it.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK)
      }
    }
  }

  @Test
  fun tintColorsTheSelectedCategory() {
    val tint = Color.parseColor("#E53935")
    module.open(options(tint = tint), TestPromise())
    eventually {
      onView(allOf(withId(androidx.emoji2.emojipicker.R.id.emoji_picker_header_icon), isSelected()))
        .inRoot(isDialog())
        .check(selectedTint(tint))
    }
  }


  // Helpers

  private fun picker() = onView(isAssignableFrom(EmojiPickerView::class.java)).inRoot(isDialog())

  private fun firstEmoji() =
    onView(first(allOf(withClassName(`is`("androidx.emoji2.emojipicker.EmojiView")), isDisplayed()))).inRoot(isDialog())

  private fun selectedTint(color: Int) = ViewAssertion { view, noView ->
    if (view == null) throw noView
    val tint = (view as ImageView).imageTintList
      ?.getColorForState(intArrayOf(android.R.attr.state_selected), 0)
    assertEquals(Integer.toHexString(color), tint?.let(Integer::toHexString))
  }

  private fun assertNoSheet() {
    idle()
    try {
      picker().check(matches(isDisplayed()))
      fail("the picker is still on screen")
    } catch (_: NoMatchingRootException) {
    } catch (_: NoMatchingViewException) {
    }
  }

  /**
   * Waits for the sheet to stop sliding in: Espresso's idle check doesn't cover the
   * slide, and a tap outside during it is lost.
   */
  private fun awaitSheetSettled() {
    var last = Int.MIN_VALUE
    eventually {
      onView(withId(com.google.android.material.R.id.design_bottom_sheet)).inRoot(isDialog()).check { view, noView ->
        if (view == null) throw noView
        val top = IntArray(2).also(view::getLocationOnScreen)[1]
        val previous = last
        last = top
        assertEquals("sheet still moving", previous, top)
      }
    }
  }

  /** Retries [check] until it passes or 5 s go by. */
  private fun eventually(check: () -> ViewInteraction) {
    val deadline = System.currentTimeMillis() + 5_000
    while (true) {
      try {
        check()
        return
      } catch (error: Throwable) {
        if (System.currentTimeMillis() > deadline) throw error
        Thread.sleep(100)
      }
    }
  }

  private fun idle() = InstrumentationRegistry.getInstrumentation().waitForIdleSync()

  private fun options(style: String = "unspecified", tint: Int? = null) = JavaOnlyMap().apply {
    putMap("anchor", JavaOnlyMap.of("x", 0.0, "y", 0.0, "width", 0.0, "height", 0.0))
    putString("userInterfaceStyle", style)
    tint?.let { putDouble("tintColor", it.toDouble()) }
  }

  /** The first view [matcher] accepts, in hierarchy order. */
  private fun <T> first(matcher: Matcher<T>): Matcher<T> = object : BaseMatcher<T>() {
    private var matched: Any? = null

    override fun matches(item: Any?): Boolean {
      if (matched == null && matcher.matches(item)) matched = item
      return matched === item
    }

    override fun describeTo(description: Description) {
      description.appendText("first ").appendDescriptionOf(matcher)
    }
  }

  /** Settled from the UI thread; the test thread waits for it. */
  private class TestPromise : Promise {
    private val latch = CountDownLatch(1)
    @Volatile private var value: Any? = null
    @Volatile var rejectCode: String? = null
      private set

    fun await(): Any? {
      assertTrue("promise not settled in time", latch.await(5, TimeUnit.SECONDS))
      return value
    }

    override fun resolve(value: Any?) {
      this.value = value
      latch.countDown()
    }

    private fun settleRejected(code: String?) {
      rejectCode = code ?: "unknown"
      latch.countDown()
    }

    override fun reject(code: String?, message: String?) = settleRejected(code)
    override fun reject(code: String?, throwable: Throwable?) = settleRejected(code)
    override fun reject(code: String?, message: String?, throwable: Throwable?) = settleRejected(code)
    override fun reject(throwable: Throwable) = settleRejected(null)
    override fun reject(throwable: Throwable, userInfo: WritableMap) = settleRejected(null)
    override fun reject(code: String?, userInfo: WritableMap) = settleRejected(code)
    override fun reject(code: String?, throwable: Throwable?, userInfo: WritableMap) = settleRejected(code)
    override fun reject(code: String?, message: String?, userInfo: WritableMap) = settleRejected(code)
    override fun reject(code: String?, message: String?, throwable: Throwable?, userInfo: WritableMap?) =
      settleRejected(code)
    override fun reject(message: String) = settleRejected(null)
  }
}
