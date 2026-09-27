package io.wyn.wyn.feature.compose

import android.os.Looper
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import io.wyn.wyn.core.data.Draft
import io.wyn.wyn.core.design.ThemeChoice
import io.wyn.wyn.core.design.WynosTheme
import io.wyn.wyn.testing.FakeComposerRepository
import io.wyn.wyn.testing.FakeFeedRepository
import io.wyn.wyn.testing.HomeFixture
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Duration
import java.time.Instant

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ComposerScreenshotTest {
    @get:Rule val compose = createComposeRule()
    private val repo = FakeComposerRepository()

    private fun settle() = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))

    private fun composer(theme: ThemeChoice, name: String, setup: (ComposerViewModel) -> Unit = {}) {
        val vm = ComposerViewModel(repo, FakeFeedRepository(), HomeFixture.VIEWER)
        settle(); setup(vm); settle()
        compose.setContent { WynosTheme(theme) { ComposerScreen(vm) } }
        compose.waitForIdle()
        compose.onRoot().captureRoboImage("build/screenshots/$name.png")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun emptyThai() {
        composer(ThemeChoice.Light, "composer-th-light")
        compose.onNodeWithText("มีอะไรเกิดขึ้นบ้าง").assertExists()
        compose.onNodeWithText("เพิ่มโพล").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun pollThai() {
        composer(ThemeChoice.Light, "composer-poll-th-light") {
            it.toggleMode(); it.updateCaption("วันนี้ดื่มอะไรดี"); it.updatePollOption(0, "ชาเย็น"); it.updatePollOption(1, "กาแฟ")
        }
        compose.onNodeWithText("เพิ่มตัวเลือก").assertExists()
    }

    @Test @Config(qualifiers = "en-w411dp-h914dp-night-xxhdpi")
    fun textEnglishDark() {
        composer(ThemeChoice.Dark, "composer-en-dark") { it.updateCaption("Coffee first, then work ☕") }
        compose.onNodeWithText("Post").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun draftsThai() {
        val now = Instant.now()
        repo.drafts["a"] = Draft("a", null, "ร่างโพสต์เรื่องกาแฟ", null, null, now.minusSeconds(300).toString())
        repo.drafts["b"] = Draft("b", null, "ดื่มอะไรดี", listOf("ชา", "กาแฟ"), 1, now.minusSeconds(7200).toString())
        val vm = DraftsViewModel(repo, HomeFixture.VIEWER)
        settle()
        compose.setContent { WynosTheme(ThemeChoice.Light) { DraftsScreen(vm, onBack = {}, onOpen = {}) } }
        compose.waitForIdle()
        compose.onNodeWithText("โพล: ดื่มอะไรดี").assertExists()
        compose.onRoot().captureRoboImage("build/screenshots/drafts-th-light.png")
    }
}
