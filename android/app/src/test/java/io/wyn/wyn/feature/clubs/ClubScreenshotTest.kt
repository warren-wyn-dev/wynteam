package io.wyn.wyn.feature.clubs

import android.os.Looper
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import io.wyn.wyn.core.data.ClubMembership
import io.wyn.wyn.core.data.EngagementSync
import io.wyn.wyn.core.design.ThemeChoice
import io.wyn.wyn.core.design.WynosTheme
import io.wyn.wyn.feature.home.FeedMode
import io.wyn.wyn.feature.home.HomeNavigation
import io.wyn.wyn.feature.home.HomeScreen
import io.wyn.wyn.feature.home.HomeViewModel
import io.wyn.wyn.testing.ClubFixture
import io.wyn.wyn.testing.FakeClubRepository
import io.wyn.wyn.testing.FakeFeedRepository
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Duration

/** Clubs, to compare against the web's Explore, Club page, chat, about and create screens. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ClubScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private fun settle() = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
    private val repo = FakeClubRepository()

    private fun club(): ClubViewModel = ClubViewModel(repo, ClubFixture.ME, ClubFixture.CLUB, EngagementSync()).also { settle() }

    private fun show(name: String, theme: ThemeChoice = ThemeChoice.Light, content: @androidx.compose.runtime.Composable () -> Unit) {
        compose.setContent { WynosTheme(theme) { content() } }
        compose.waitForIdle()
        settle()
        compose.onRoot().captureRoboImage("build/screenshots/$name.png")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun exploreThai() {
        repo.memberships.clear()
        repo.memberships[ClubFixture.PRIVATE_CLUB] = ClubMembership("member", "pending")
        val vm = ExploreClubsViewModel(repo, ClubFixture.ME)
        settle()
        show("clubs-explore-th") { ExploreClubsScreen(vm, onOpen = {}, onCreate = {}) }
        compose.onNodeWithText("กำลังนิยม").assertExists()
    }

    @Test @Config(qualifiers = "en-w411dp-h914dp-night-xxhdpi")
    fun exploreEnglishDark() {
        repo.memberships.clear()
        val vm = ExploreClubsViewModel(repo, ClubFixture.ME)
        settle()
        show("clubs-explore-en-dark", ThemeChoice.Dark) { ExploreClubsScreen(vm, onOpen = {}, onCreate = {}) }
        compose.onNodeWithText("Popular").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun clubPostsThai() {
        val vm = club()
        show("club-posts-th") { ClubScreen(vm, onBack = {}, onOpenProfile = {}, onOpenPost = {}) }
        compose.onNodeWithText("ปักหมุด").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun clubJoinThai() {
        repo.memberships.clear()
        val vm = club()
        show("club-join-th") { ClubScreen(vm, onBack = {}, onOpenProfile = {}, onOpenPost = {}) }
        compose.onNodeWithText("เข้าร่วม").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun clubChatThai() {
        val vm = club()
        vm.select(ClubTab.Chat)
        vm.chat.reload()
        settle()
        show("club-chat-th") { ClubScreen(vm, onBack = {}, onOpenProfile = {}, onOpenPost = {}) }
        compose.onNodeWithText("#ทั่วไป").assertExists()
    }

    @Test @Config(qualifiers = "en-w411dp-h914dp-night-xxhdpi")
    fun clubChatEnglishDark() {
        val vm = club()
        vm.select(ClubTab.Chat)
        vm.chat.reload()
        settle()
        show("club-chat-en-dark", ThemeChoice.Dark) { ClubScreen(vm, onBack = {}, onOpenProfile = {}, onOpenPost = {}) }
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun clubAboutThai() {
        repo.memberships[ClubFixture.CLUB] = ClubMembership("owner", "approved")
        val vm = club()
        vm.select(ClubTab.About)
        show("club-about-th") { ClubScreen(vm, onBack = {}, onOpenProfile = {}, onOpenPost = {}) }
        compose.onNodeWithText("Insights").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun clubMenuThai() {
        val vm = club()
        vm.openMenu(true)
        show("club-menu-th") { ClubScreen(vm, onBack = {}, onOpenProfile = {}, onOpenPost = {}) }
        compose.onNodeWithText("ออกจาก Club").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun createThai() {
        val vm = CreateClubViewModel(repo, ClubFixture.ME)
        vm.updateName("คนรักกาแฟ")
        show("club-create-th") { CreateClubScreen(vm, onBack = {}, onCreated = {}) }
        compose.onNodeWithText("ต้องได้รับอนุมัติก่อนเข้าร่วม").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun myClubsThai() {
        val vm = MyClubsViewModel(repo, ClubFixture.ME)
        settle()
        show("clubs-mine-th") { MyClubsScreen(vm, onBack = {}, onOpen = {}) }
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun inviteThai() {
        val vm = ClubInviteViewModel(repo, "CODE")
        settle()
        show("club-invite-th") { ClubInviteScreen(vm, onBack = {}, onOpenClub = {}) }
        compose.onNodeWithText("เข้าร่วม Club").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun homeClubsTabThai() {
        val clubs = ClubFeedViewModel(repo, ClubFixture.ME, EngagementSync())
        val home = HomeViewModel(FakeFeedRepository(), ClubFixture.ME)
        home.select(FeedMode.Clubs)
        settle()
        show("home-clubs-th") { HomeScreen(home, HomeNavigation(), clubs = clubs) }
        compose.onNodeWithText("ร้านใหม่แถวอารีย์ เมล็ดคั่วอ่อนหอมมาก ใครไปแล้วบ้าง?").assertExists()
    }
}
