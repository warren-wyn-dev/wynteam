package io.wyn.wyn.feature.profile

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.net.Uri
import android.os.Looper
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.test.core.app.ApplicationProvider
import coil3.ColorImage
import coil3.ImageLoader
import coil3.SingletonImageLoader
import coil3.annotation.ExperimentalCoilApi
import coil3.test.FakeImageLoaderEngine
import com.github.takahirom.roborazzi.captureRoboImage
import io.wyn.wyn.core.data.FollowKind
import io.wyn.wyn.core.data.ProfileTab
import io.wyn.wyn.core.design.ThemeChoice
import io.wyn.wyn.core.design.WynosTheme
import io.wyn.wyn.feature.shell.MainShell
import io.wyn.wyn.testing.FakeFeedRepository
import io.wyn.wyn.testing.FakeProfileRepository
import io.wyn.wyn.testing.FakeQuoteRepository
import io.wyn.wyn.testing.HomeFixture
import io.wyn.wyn.testing.ProfileFixture
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

/** Profile screens, to compare against the web's profile-web-beta1 styles. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ProfileScreenshotTest {
    @get:Rule val compose = createComposeRule()

    @OptIn(ExperimentalCoilApi::class)
    @Before fun images() {
        val engine = FakeImageLoaderEngine.Builder().default(ColorImage(0xFFE8E6E0.toInt())).build()
        SingletonImageLoader.setUnsafe(ImageLoader.Builder(ApplicationProvider.getApplicationContext()).components { add(engine) }.build())
    }

    private fun settle() = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
    private fun shot(name: String) = compose.onRoot().captureRoboImage("build/screenshots/$name.png")

    private fun profile(id: String, repo: FakeProfileRepository = FakeProfileRepository()): ProfileViewModel {
        val vm = ProfileViewModel(repo, FakeFeedRepository(), HomeFixture.VIEWER, id, quotes = FakeQuoteRepository())
        settle()
        return vm
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun ownProfileThai() {
        val vm = profile(HomeFixture.VIEWER)
        compose.setContent {
            WynosTheme(ThemeChoice.Light) { MainShell(home = {}, profile = { ProfileScreen(vm, ProfileNavigation()) }, onCompose = {}, initialTab = io.wyn.wyn.feature.shell.MainTab.Profile) }
        }
        compose.waitForIdle()
        compose.onNodeWithText("@warren").assertExists()
        compose.onNodeWithText("1,024", substring = true).assertExists()
        shot("profile-own-th")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun otherProfileThai() {
        val repo = FakeProfileRepository(tabs = emptyMap())
        repo.summaries[ProfileFixture.OTHER] = ProfileFixture.own.summaryFor(ProfileFixture.OTHER)
        val vm = profile(ProfileFixture.OTHER, repo)
        compose.setContent { WynosTheme(ThemeChoice.Light) { ProfileScreen(vm, ProfileNavigation(onBack = {})) } }
        compose.waitForIdle()
        compose.onNodeWithText("ส่งข้อความ").assertExists()
        shot("profile-other-th")
    }

    @Test @Config(qualifiers = "en-w411dp-h914dp-night-xxhdpi")
    fun otherProfileEnglishDark() {
        val vm = profile(ProfileFixture.OTHER)
        compose.setContent { WynosTheme(ThemeChoice.Dark) { ProfileScreen(vm, ProfileNavigation(onBack = {})) } }
        compose.waitForIdle()
        shot("profile-other-en-dark")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun privateLikesThai() {
        val repo = FakeProfileRepository()
        repo.likesAllowed = false
        val vm = profile(ProfileFixture.OTHER, repo)
        vm.select(ProfileTab.Likes)
        settle()
        compose.setContent { WynosTheme(ThemeChoice.Light) { ProfileScreen(vm, ProfileNavigation(onBack = {})) } }
        compose.waitForIdle()
        compose.onNodeWithText("เจ้าของบัญชีจำกัดผู้ที่เห็นรายการที่ถูกใจ").assertExists()
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun editProfileThai() {
        val vm = EditProfileViewModel(FakeProfileRepository(), HomeFixture.VIEWER, ProfileFixture.own.profile)
        compose.setContent { WynosTheme(ThemeChoice.Light) { EditProfileScreen(vm, onClose = {}) } }
        compose.waitForIdle()
        shot("profile-edit-th")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun followListThai() {
        val vm = FollowListViewModel(FakeProfileRepository(), FakeFeedRepository(), HomeFixture.VIEWER, ProfileFixture.OTHER, FollowKind.Followers)
        settle()
        compose.setContent { WynosTheme(ThemeChoice.Light) { FollowListScreen(vm, onBack = {}, onOpenProfile = {}) } }
        compose.waitForIdle()
        compose.onNodeWithText("ขอติดตามแล้ว").assertExists()
        shot("profile-follows-th")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun cropperThai() {
        val bitmap = Bitmap.createBitmap(800, 600, Bitmap.Config.ARGB_8888).apply { Canvas(this).drawColor(0xFF3FA9F5.toInt()) }
        compose.setContent { WynosTheme(ThemeChoice.Light) { PhotoCropper(Uri.EMPTY, onCancel = {}, onConfirm = {}, preloaded = bitmap) } }
        compose.waitForIdle()
        compose.onNodeWithText("ใช้รูปนี้").assertExists()
        shot("profile-crop-th")
    }

    @Test fun cropOutputIsA512SquareJpeg() {
        val source = Bitmap.createBitmap(900, 300, Bitmap.Config.ARGB_8888).apply { Canvas(this).drawColor(0xFFFF0000.toInt()) }
        val bytes = CropMath.render(source, 2f, Offset(0.3f, 0f))
        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        assertEquals(512, decoded.width)
        assertEquals(512, decoded.height)
        assertEquals(0xFF, bytes[0].toInt() and 0xFF)
        assertEquals(0xD8, bytes[1].toInt() and 0xFF)
        // At zoom 2 a 3:1 photo is 6 viewports wide and 2 tall: it can move (6 - 1) / 2 sideways and (2 - 1) / 2 up or down.
        assertEquals(Offset(2.5f, 0.5f), CropMath.clampOffset(Offset(9f, 9f), 2f, 900, 300))
    }
}

private fun io.wyn.wyn.core.data.ProfileSummary.summaryFor(id: String) = copy(profile = profile.copy(id = id))
