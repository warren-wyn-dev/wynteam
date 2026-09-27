package io.wyn.wyn.feature.search

import android.os.Looper
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import com.github.takahirom.roborazzi.captureRoboImage
import io.wyn.wyn.core.data.EngagementSync
import io.wyn.wyn.core.design.ThemeChoice
import io.wyn.wyn.core.design.WynosTheme
import io.wyn.wyn.feature.home.HomeNavigation
import io.wyn.wyn.feature.shell.DrawerActions
import io.wyn.wyn.feature.shell.HomeDrawer
import io.wyn.wyn.testing.FakeDiscoveryRepository
import io.wyn.wyn.testing.FakeFeedRepository
import io.wyn.wyn.testing.HomeFixture
import io.wyn.wyn.testing.ProfileFixture
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Duration

/** Search, trending, saved posts and the Home menu, to compare with the web. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SearchScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private fun settle() = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
    private val repo = FakeDiscoveryRepository()
    private val feed = FakeFeedRepository()
    private val nav = SearchNavigation(HomeNavigation(), onBack = {}, onOpenProfile = {}, onOpenClub = {}, onTrending = {})

    private fun capture(name: String) {
        compose.waitForIdle()
        settle()
        compose.onRoot().captureRoboImage("build/screenshots/$name.png")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun discoveryThai() {
        val vm = SearchViewModel(repo, feed, HomeFixture.VIEWER)
        val posts = SearchPostsViewModel(repo, feed, HomeFixture.VIEWER, EngagementSync(), null)
        settle()
        compose.setContent { WynosTheme(ThemeChoice.Light) { SearchScreen(vm, posts, nav, null, null) } }
        capture("search-discovery-th")
        compose.onNodeWithText("แนะนำให้ติดตาม").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun resultsThai() {
        val vm = SearchViewModel(repo, feed, HomeFixture.VIEWER)
        val posts = SearchPostsViewModel(repo, feed, HomeFixture.VIEWER, EngagementSync(), null)
        vm.updateDraft("WYNOS")
        vm.submitNow()
        settle()
        compose.setContent { WynosTheme(ThemeChoice.Light) { SearchScreen(vm, posts, nav, null, null) } }
        capture("search-all-th")
        compose.onNodeWithText("ทั้งหมด").assertExists()
    }

    @Test @Config(qualifiers = "en-w411dp-h914dp-night-xxhdpi")
    fun discoveryEnglishDark() {
        val vm = SearchViewModel(repo, feed, HomeFixture.VIEWER)
        val posts = SearchPostsViewModel(repo, feed, HomeFixture.VIEWER, EngagementSync(), null)
        settle()
        compose.setContent { WynosTheme(ThemeChoice.Dark) { SearchScreen(vm, posts, nav, null, null) } }
        capture("search-discovery-en-dark")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun trendingThai() {
        val vm = TrendingViewModel(repo)
        settle()
        compose.setContent { WynosTheme(ThemeChoice.Light) { TrendingScreen(vm, onBack = {}) } }
        capture("trending-th")
        compose.onNodeWithText("#wynos").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun bookmarksThai() {
        val vm = BookmarksViewModel(repo, feed, HomeFixture.VIEWER, EngagementSync(), null)
        settle()
        compose.setContent { WynosTheme(ThemeChoice.Light) { BookmarksScreen(vm, HomeNavigation(), onBack = {}, null, null) } }
        capture("bookmarks-th")
        compose.onNodeWithText("บันทึกไว้").assertExists()
    }

    private val actions = DrawerActions({}, {}, {}, {}, {}, {})

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun drawerThai() {
        compose.setContent { WynosTheme(ThemeChoice.Light) { HomeDrawer(true, ProfileFixture.own, actions, onClose = {}) } }
        capture("drawer-th")
        compose.onNodeWithText("Club ของฉัน").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun drawerFeedbackThai() {
        compose.setContent { WynosTheme(ThemeChoice.Light) { HomeDrawer(true, ProfileFixture.own, actions, onClose = {}) } }
        compose.waitForIdle(); settle()
        compose.onNodeWithText("ข้อเสนอแนะ").performClick()
        capture("drawer-feedback-th")
        compose.onNodeWithText("แบ่งปันความคิดเห็นของคุณ").assertExists()
    }

    @Test @Config(qualifiers = "en-w411dp-h914dp-night-xxhdpi")
    fun drawerHelpEnglishDark() {
        compose.setContent { WynosTheme(ThemeChoice.Dark) { HomeDrawer(true, ProfileFixture.own, actions, onClose = {}) } }
        compose.waitForIdle(); settle()
        compose.onNodeWithText("Help").performClick()
        capture("drawer-help-en-dark")
    }
}
