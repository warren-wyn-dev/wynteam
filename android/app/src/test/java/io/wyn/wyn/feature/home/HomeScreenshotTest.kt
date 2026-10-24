package io.wyn.wyn.feature.home

import android.os.Looper
import androidx.compose.ui.test.hasScrollToNodeAction
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.onRoot
import androidx.test.core.app.ApplicationProvider
import coil3.ColorImage
import coil3.ImageLoader
import coil3.SingletonImageLoader
import coil3.annotation.ExperimentalCoilApi
import coil3.test.FakeImageLoaderEngine
import com.github.takahirom.roborazzi.captureRoboImage
import io.wyn.wyn.core.data.HomeIdentity
import io.wyn.wyn.core.design.ThemeChoice
import io.wyn.wyn.core.design.WynosTheme
import io.wyn.wyn.feature.shell.MainShell
import io.wyn.wyn.testing.FakeFeedRepository
import io.wyn.wyn.testing.HomeFixture
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Duration

/** Home with the web fixture's posts, to compare against web/app/dev/home-fixture. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class HomeScreenshotTest {
    @get:Rule val compose = createComposeRule()

    @OptIn(ExperimentalCoilApi::class)
    @Before fun images() {
        // The web fixture's grey "Fixture Photo".
        val engine = FakeImageLoaderEngine.Builder().default(ColorImage(0xFFE8E6E0.toInt())).build()
        SingletonImageLoader.setUnsafe(
            ImageLoader.Builder(ApplicationProvider.getApplicationContext()).components { add(engine) }.build(),
        )
    }

    private fun render(theme: ThemeChoice, name: String, scrollTo: String? = null /* LazyColumn item index */) {
        val vm = HomeViewModel(FakeFeedRepository(), HomeFixture.VIEWER)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        compose.setContent {
            WynosTheme(theme) {
                MainShell(home = { HomeScreen(vm, HomeNavigation(), notificationCount = 3) }, profile = {}, onCompose = {}, chatUnread = 2)
            }
        }
        compose.waitForIdle()
        if (scrollTo != null) compose.onNode(hasScrollToNodeAction()).performScrollToIndex(scrollTo.toInt())
        compose.onRoot().captureRoboImage("build/screenshots/$name.png")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun homeThaiLight() {
        render(ThemeChoice.Light, "home-th-light")
        compose.onNodeWithText("สำหรับคุณ").assertExists()
        compose.onNodeWithText("รีโพสต์โดย WYNOS · 4 ก.ย.").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun homeThaiLightPhoto() {
        render(ThemeChoice.Light, "home-photo-th-light", scrollTo = "4")
    }

    @Test @Config(qualifiers = "th-w393dp-h851dp-xxhdpi")
    fun homeThaiPixel5CompactTabs() {
        render(ThemeChoice.Light, "home-th-pixel5")
        compose.onNodeWithText("กำลังติดตาม").assertIsDisplayed()
        compose.onNodeWithText("คลับของฉัน").assertIsDisplayed()
    }

    @Test @Config(qualifiers = "th-w340dp-h760dp-xxhdpi")
    fun narrowWebParityRendersVerifiedRosetteAndReadableDock() {
        val repo = FakeFeedRepository(ranked = listOf(HomeFixture.rows[2].copy(authorIsVerified = true)))
        val vm = HomeViewModel(repo, HomeFixture.VIEWER)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        compose.setContent {
            WynosTheme(ThemeChoice.Light) {
                MainShell(home = { HomeScreen(vm, HomeNavigation()) }, profile = {}, onCompose = {})
            }
        }
        compose.waitForIdle()
        compose.onNodeWithContentDescription("ยืนยันแล้ว").assertIsDisplayed()
        compose.onNodeWithText("หน้าหลัก").assertIsDisplayed()
        compose.onNodeWithText("คลับ").assertIsDisplayed()
        compose.onNodeWithText("โปรไฟล์").assertIsDisplayed()
        compose.onRoot().captureRoboImage("build/screenshots/home-web-parity-narrow-th.png")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun regularWebParityRendersVerifiedRosette() {
        val repo = FakeFeedRepository(ranked = listOf(HomeFixture.rows[2].copy(authorIsVerified = true)))
        val vm = HomeViewModel(repo, HomeFixture.VIEWER)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        compose.setContent {
            WynosTheme(ThemeChoice.Light) {
                MainShell(home = { HomeScreen(vm, HomeNavigation()) }, profile = {}, onCompose = {})
            }
        }
        compose.waitForIdle()
        compose.onNodeWithContentDescription("ยืนยันแล้ว").assertIsDisplayed()
        compose.onRoot().captureRoboImage("build/screenshots/home-web-parity-verified-th.png")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun firstPostPromptOpensTheExistingComposerRoute() {
        val repo = FakeFeedRepository(
            homeIdentity = HomeIdentity("newuser", "New User", null, hasPublishedPost = false),
        )
        val vm = HomeViewModel(repo, HomeFixture.VIEWER)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        var clickedKey: String? = null
        compose.setContent {
            WynosTheme(ThemeChoice.Light) {
                MainShell(
                    home = {
                        HomeScreen(
                            vm, HomeNavigation(onComposePrompt = { clickedKey = it }),
                        )
                    },
                    profile = {},
                    onCompose = {},
                )
            }
        }
        compose.waitForIdle()
        compose.onNodeWithText("เริ่มโพสต์แรกของคุณ ✨").assertIsDisplayed()
        compose.onNodeWithText("สร้างโพสต์แรก").performClick()
        assertEquals("first-intro", clickedKey)
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun returningAuthorSeesRotatingDailyPrompt() {
        val repo = FakeFeedRepository(
            homeIdentity = HomeIdentity("returning", "Returning", null, hasPublishedPost = true),
        )
        val vm = HomeViewModel(repo, HomeFixture.VIEWER)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        compose.setContent {
            WynosTheme(ThemeChoice.Light) {
                MainShell(home = { HomeScreen(vm, HomeNavigation()) }, profile = {}, onCompose = {})
            }
        }
        compose.waitForIdle()
        compose.onNodeWithText("หัวข้อวันนี้").assertIsDisplayed()
    }

    @Test @Config(qualifiers = "en-w411dp-h914dp-night-xxhdpi")
    fun homeEnglishDark() {
        render(ThemeChoice.Dark, "home-en-dark")
        compose.onNodeWithText("For You").assertExists()
    }
}
