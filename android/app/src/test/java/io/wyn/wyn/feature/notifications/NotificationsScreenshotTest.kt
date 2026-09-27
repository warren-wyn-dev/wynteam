package io.wyn.wyn.feature.notifications

import android.os.Looper
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import io.wyn.wyn.core.design.ThemeChoice
import io.wyn.wyn.core.design.WynosTheme
import io.wyn.wyn.core.push.InMemoryPushMemory
import io.wyn.wyn.core.push.PushController
import io.wyn.wyn.testing.FakeDeviceToken
import io.wyn.wyn.testing.FakeNotificationRepository
import io.wyn.wyn.testing.FakePushTokens
import io.wyn.wyn.testing.HomeFixture
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Duration

/** Notifications, to compare against the web's notifications-clean styles. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class NotificationsScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private fun settle() = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
    private fun push() = PushController(FakePushTokens(), FakeDeviceToken(), InMemoryPushMemory()) { true }

    private fun list(theme: ThemeChoice, name: String) {
        val vm = NotificationsViewModel(FakeNotificationRepository(), HomeFixture.VIEWER)
        settle()
        compose.setContent { WynosTheme(theme) { NotificationsScreen(vm, onBack = {}, onOpen = {}) } }
        compose.waitForIdle()
        compose.onRoot().captureRoboImage("build/screenshots/$name.png")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun notificationsThai() {
        list(ThemeChoice.Light, "notifications-th")
        compose.onNodeWithText("และอีก 2 คน", substring = true).assertExists()
        compose.onNodeWithText("เมื่อวานนี้").assertExists()
    }

    @Test @Config(qualifiers = "en-w411dp-h914dp-night-xxhdpi")
    fun notificationsEnglishDark() {
        list(ThemeChoice.Dark, "notifications-en-dark")
        compose.onNodeWithText("liked your post", substring = true).assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun emptyThai() {
        val vm = NotificationsViewModel(FakeNotificationRepository(emptyList()), HomeFixture.VIEWER)
        settle()
        compose.setContent { WynosTheme(ThemeChoice.Light) { NotificationsScreen(vm, onBack = {}, onOpen = {}) } }
        compose.onNodeWithText("ยังไม่มีการแจ้งเตือน").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun settingsThai() {
        val controller = push()
        val vm = NotificationSettingsViewModel(FakeNotificationRepository(), controller, HomeFixture.VIEWER)
        settle()
        compose.setContent { WynosTheme(ThemeChoice.Light) { NotificationSettingsScreen(vm, controller, onBack = {}) } }
        compose.waitForIdle()
        settle()
        compose.onNodeWithText("การแจ้งเตือนแบบพุช").assertExists()
        compose.onRoot().captureRoboImage("build/screenshots/notification-settings-th.png")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun pushPromptThai() {
        compose.setContent {
            WynosTheme(ThemeChoice.Light) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.BottomCenter) { PushPromptCard(push(), HomeFixture.VIEWER) {} }
            }
        }
        compose.onNodeWithText("อนุญาต").assertExists()
        compose.onRoot().captureRoboImage("build/screenshots/push-prompt-th.png")
    }
}
