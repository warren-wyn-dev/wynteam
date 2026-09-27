package io.wyn.wyn.feature.chat

import android.os.Looper
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import io.wyn.wyn.core.design.ThemeChoice
import io.wyn.wyn.core.design.WynosTheme
import io.wyn.wyn.testing.ChatFixture
import io.wyn.wyn.testing.FakeChatRepository
import io.wyn.wyn.testing.FakeFeedRepository
import io.wyn.wyn.testing.FakeProfileRepository
import io.wyn.wyn.testing.ProfileFixture
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Duration

/** Chat, to compare against the web's chat inbox and conversation (Web Beta 1 layout). */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ChatScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private fun settle() = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
    private val profiles = FakeProfileRepository().apply {
        summaries[ChatFixture.OTHER] = ProfileFixture.other.copy(profile = ProfileFixture.other.profile.copy(id = ChatFixture.OTHER, username = "mind_coffee", displayName = "มายด์"))
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun inboxThai() {
        val vm = ChatInboxViewModel(FakeChatRepository(), ChatFixture.ME)
        settle()
        compose.setContent { WynosTheme(ThemeChoice.Light) { ChatInboxScreen(vm, onOpen = {}) } }
        compose.waitForIdle()
        compose.onNodeWithText("ลบข้อความแล้ว").assertExists()
        compose.onRoot().captureRoboImage("build/screenshots/chat-inbox-th.png")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun conversationThai() {
        val chat = FakeChatRepository()
        val vm = ConversationViewModel(chat, profiles, FakeFeedRepository(), ChatFixture.ME, ChatFixture.CONVERSATION, ChatFixture.OTHER)
        settle()
        compose.setContent { WynosTheme(ThemeChoice.Light) { ConversationScreen(vm, chat, onBack = {}, onOpenProfile = {}) } }
        compose.waitForIdle()
        compose.onNodeWithText("รสชาติดีเกินคาด").assertExists()
        compose.onRoot().captureRoboImage("build/screenshots/chat-conversation-th.png")
    }

    @Test @Config(qualifiers = "en-w411dp-h914dp-night-xxhdpi")
    fun conversationEnglishDark() {
        val chat = FakeChatRepository()
        val vm = ConversationViewModel(chat, profiles, FakeFeedRepository(), ChatFixture.ME, ChatFixture.CONVERSATION, ChatFixture.OTHER)
        settle()
        compose.setContent { WynosTheme(ThemeChoice.Dark) { ConversationScreen(vm, chat, onBack = {}, onOpenProfile = {}) } }
        compose.waitForIdle()
        compose.onRoot().captureRoboImage("build/screenshots/chat-conversation-en-dark.png")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun newConversationThai() {
        val chat = FakeChatRepository().apply { others.clear() }
        val vm = ConversationViewModel(chat, profiles, FakeFeedRepository(), ChatFixture.ME, null, ChatFixture.OTHER)
        settle()
        compose.setContent { WynosTheme(ThemeChoice.Light) { ConversationScreen(vm, chat, onBack = {}, onOpenProfile = {}) } }
        compose.waitForIdle()
        compose.onNodeWithText("ดูโปรไฟล์").assertExists()
        compose.onRoot().captureRoboImage("build/screenshots/chat-new-th.png")
    }
}
