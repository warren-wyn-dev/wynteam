package io.wyn.wyn.feature.settings

import android.os.Looper
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import io.wyn.wyn.core.design.ThemeChoice
import io.wyn.wyn.core.design.WynosTheme
import io.wyn.wyn.feature.chat.ConversationScreen
import io.wyn.wyn.feature.chat.ConversationViewModel
import io.wyn.wyn.testing.ChatFixture
import io.wyn.wyn.testing.FakeChatRepository
import io.wyn.wyn.testing.FakeFeedRepository
import io.wyn.wyn.testing.FakeProfileRepository
import io.wyn.wyn.testing.FakeSettingsRepository
import io.wyn.wyn.testing.ProfileFixture
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Duration

/** Settings, to compare with the web. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SettingsScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private fun settle() = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
    private val actions = SettingsActions({}, {}, {}, {}, {})

    private fun settings(section: SettingsSection, name: String, theme: ThemeChoice = ThemeChoice.Light) {
        val vm = SettingsViewModel(FakeSettingsRepository(), InMemoryAppearance(), ChatFixture.ME)
        settle()
        vm.open(section)
        compose.setContent { WynosTheme(theme) { SettingsScreen(vm, actions, "Wynos Android v1.0.0 Beta 1") } }
        compose.waitForIdle(); settle()
        compose.onRoot().captureRoboImage("build/screenshots/$name.png")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun rootThai() {
        settings(SettingsSection.Root, "settings-root-th")
        compose.onNodeWithText("ออกจากระบบ").assertExists()
    }

    @Test @Config(qualifiers = "en-w411dp-h914dp-night-xxhdpi")
    fun rootEnglishDark() = settings(SettingsSection.Root, "settings-root-en-dark", ThemeChoice.Dark)

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun privacyThai() {
        settings(SettingsSection.Privacy, "settings-privacy-th")
        compose.onNodeWithText("คนที่ฉันติดตาม").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun accountThai() {
        settings(SettingsSection.Account, "settings-account-th")
        compose.onNodeWithText("ปลดบล็อก").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun passwordThai() {
        settings(SettingsSection.Password, "settings-password-th")
        compose.onNodeWithText("บันทึกรหัสผ่านใหม่").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun themeThai() = settings(SettingsSection.Theme, "settings-theme-th")

    // Wynii was removed from Android: the conversation header shows no pill or ⋯ menu.
    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun conversationHasNoWyniiThai() {
        val chat = FakeChatRepository()
        val profiles = FakeProfileRepository().apply {
            summaries[ChatFixture.OTHER] = ProfileFixture.other.copy(profile = ProfileFixture.other.profile.copy(id = ChatFixture.OTHER, username = "mind_coffee", displayName = "มายด์"))
        }
        val vm = ConversationViewModel(chat, profiles, FakeFeedRepository(), ChatFixture.ME, ChatFixture.CONVERSATION, ChatFixture.OTHER)
        settle()
        compose.setContent { WynosTheme(ThemeChoice.Light) { ConversationScreen(vm, chat, onBack = {}, onOpenProfile = {}) } }
        compose.waitForIdle(); settle()
        compose.onRoot().captureRoboImage("build/screenshots/chat-header-th.png")
        compose.onNodeWithText("@mind_coffee").assertExists()
        compose.onAllNodesWithText("Wynii", substring = true).assertCountEquals(0)
    }
}
