package io.wyn.wyn.feature.quote

import android.os.Looper
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
import io.wyn.wyn.core.design.ThemeChoice
import io.wyn.wyn.core.design.WynosTheme
import io.wyn.wyn.testing.FakeQuoteRepository
import io.wyn.wyn.testing.HomeFixture
import io.wyn.wyn.testing.QuoteFixture
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Duration

/** The Quote page, to compare against web/app/dev/quote-fixture. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class QuoteScreenshotTest {
    @get:Rule val compose = createComposeRule()

    @OptIn(ExperimentalCoilApi::class)
    @Before fun images() {
        val engine = FakeImageLoaderEngine.Builder().default(ColorImage(0xFFE8E6E0.toInt())).build()
        SingletonImageLoader.setUnsafe(
            ImageLoader.Builder(ApplicationProvider.getApplicationContext()).components { add(engine) }.build(),
        )
    }

    private fun settle() = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))

    private fun render(theme: ThemeChoice, name: String, composing: Boolean = false) {
        val vm = QuoteDetailViewModel(FakeQuoteRepository(), HomeFixture.VIEWER, QuoteFixture.QUOTE_ID)
        settle()
        if (composing) vm.quote.startQuote(QuoteFixture.quote)
        compose.setContent {
            WynosTheme(theme) { QuoteDetailScreen(vm, onBack = {}, onOpenDrop = {}, myAvatar = null, myName = "Fixture") }
        }
        compose.waitForIdle()
        compose.onRoot().captureRoboImage("build/screenshots/$name.png")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun quoteThaiLight() {
        render(ThemeChoice.Light, "quote-th-light")
        compose.onNodeWithText("เห็นด้วยมาก อยากให้มีแอปแบบนี้นานแล้ว 🙌").assertExists()
    }

    @Test @Config(qualifiers = "en-w411dp-h914dp-night-xxhdpi")
    fun quoteEnglishDark() = render(ThemeChoice.Dark, "quote-en-dark")

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun quoteComposerThai() = render(ThemeChoice.Light, "quote-composer-th", composing = true)
}
