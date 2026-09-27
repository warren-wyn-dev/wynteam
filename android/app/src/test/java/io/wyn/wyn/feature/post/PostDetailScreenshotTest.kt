package io.wyn.wyn.feature.post

import android.os.Looper
import androidx.compose.ui.test.hasScrollToIndexAction
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.test.core.app.ApplicationProvider
import coil3.ColorImage
import coil3.ImageLoader
import coil3.SingletonImageLoader
import coil3.annotation.ExperimentalCoilApi
import coil3.test.FakeImageLoaderEngine
import com.github.takahirom.roborazzi.captureRoboImage
import io.wyn.wyn.core.data.Comment
import io.wyn.wyn.core.design.ThemeChoice
import io.wyn.wyn.core.design.WynosTheme
import io.wyn.wyn.testing.FakeFeedRepository
import io.wyn.wyn.testing.FakePostRepository
import io.wyn.wyn.testing.HomeFixture
import org.junit.Before
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
class PostDetailScreenshotTest {
    @get:Rule val compose = createComposeRule()

    @OptIn(ExperimentalCoilApi::class)
    @Before fun images() {
        val engine = FakeImageLoaderEngine.Builder().default(ColorImage(0xFFE8E6E0.toInt())).build()
        SingletonImageLoader.setUnsafe(ImageLoader.Builder(ApplicationProvider.getApplicationContext()).components { add(engine) }.build())
    }

    private fun ago(minutes: Long) = Instant.now().minusSeconds(minutes * 60).toString()

    private fun render(dropId: String, theme: ThemeChoice, name: String) {
        val posts = FakePostRepository(
            comments = mutableListOf(
                Comment("c1", dropId, "warren", "ชิปใหม่น่าสนใจมาก รอดูผลทดสอบจริง", ago(50), authorUsername = "warren", authorDisplayName = "WARREN", likeCount = 3),
                Comment("c2", dropId, HomeFixture.VIEWER, "เหมือนกันครับ", ago(40), parentId = "c1", authorUsername = "fixture", authorDisplayName = "Fixture", likeCount = 1, likedByMe = true),
                Comment("c3", dropId, "mint", "ราคาน่าจะแรงนะ 😅", ago(20), authorUsername = "mint", authorDisplayName = "mint"),
            ),
        )
        val vm = PostDetailViewModel(posts, FakeFeedRepository(), HomeFixture.VIEWER, dropId)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        compose.setContent { WynosTheme(theme) { PostDetailScreen(vm, onBack = {}) } }
        compose.waitForIdle()
        compose.onRoot().captureRoboImage("build/screenshots/$name.png")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun photoPostThai() {
        render("drop-4", ThemeChoice.Light, "detail-th-light")
        compose.onNodeWithText("ดูกิจกรรม").assertExists()
        compose.onAllNodes(hasScrollToIndexAction())[0].performScrollToIndex(2)
        compose.onNodeWithText("เหมือนกันครับ").assertExists()
        compose.onRoot().captureRoboImage("build/screenshots/detail-comments-th-light.png")
    }

    @Test @Config(qualifiers = "en-w411dp-h914dp-night-xxhdpi")
    fun textPostEnglishDark() {
        render("drop-3", ThemeChoice.Dark, "detail-en-dark")
        compose.onNodeWithText("View activity").assertExists()
    }
}
