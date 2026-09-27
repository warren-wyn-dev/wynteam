package io.wyn.wyn.feature.auth

import android.os.Looper
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import io.wyn.wyn.WynosApp
import io.wyn.wyn.core.data.MemoryAccountStore
import io.wyn.wyn.core.data.SavedAccount
import io.wyn.wyn.core.design.ThemeChoice
import io.wyn.wyn.core.design.WynosTheme
import io.wyn.wyn.testing.FakeAuthRepository
import io.wyn.wyn.testing.FakeFeedRepository
import io.wyn.wyn.testing.FakePostRepository
import io.wyn.wyn.testing.FakeComposerRepository
import io.wyn.wyn.testing.FakeQuoteRepository
import io.wyn.wyn.testing.FakeProfileRepository
import io.wyn.wyn.testing.FakeNotificationRepository
import io.wyn.wyn.testing.FakeChatRepository
import io.wyn.wyn.testing.FakeClubRepository
import io.wyn.wyn.feature.shell.Repositories
import androidx.compose.ui.test.performClick
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Duration

/** Every M1 account screen, Pixel 7 size, as the Founder will see it. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class AccountScreensScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private val repo = FakeAuthRepository()
    private val store = MemoryAccountStore()

    private fun app(theme: ThemeChoice = ThemeChoice.Light, setup: (AccountFlowViewModel) -> Unit): AccountFlowViewModel {
        val vm = AccountFlowViewModel(repo, store, configured = true)
        settle()
        setup(vm)
        settle()
        compose.setContent { WynosTheme(theme) { WynosApp(vm, Repositories(FakeFeedRepository(), FakePostRepository(), FakeComposerRepository(), FakeQuoteRepository(), profiles, FakeNotificationRepository(), FakeChatRepository(), FakeClubRepository()), onExit = {}) } }
        compose.waitForIdle()
        return vm
    }

    private val profiles = FakeProfileRepository().apply {
        summaries["u1"] = io.wyn.wyn.core.data.ProfileSummary(
            io.wyn.wyn.core.data.Profile(id = "u1", username = "somchai", displayName = "สมชาย ใจดี"), followerCount = 0, followingCount = 0,
        )
    }

    private fun settle() = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))

    private fun shot(name: String) = compose.onRoot().captureRoboImage("build/screenshots/$name.png")

    private fun AccountFlowViewModel.fillStep1() {
        updateUsername("somchai")
        updateDisplayName("สมชาย ใจดี")
        updateBirthDate(day = 15, month = 6, year = 2000)
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun loginThai() {
        app { it.navigate(Route.Login()); it.updateLoginEmail("somchai@example.com"); it.updateLoginPassword("secret") }
        compose.onNodeWithText("ลืมรหัสผ่าน?").assertExists()
        shot("login-th-light")
    }

    @Test @Config(qualifiers = "en-w411dp-h914dp-night-xxhdpi")
    fun loginEnglishDarkWithError() {
        app(ThemeChoice.Dark) { it.navigate(Route.Login()); it.submitLogin() }
        compose.onNodeWithText("Please enter your email and password").assertExists()
        shot("login-en-dark")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun signupStep1Thai() {
        app { it.navigate(Route.SignupStep1); it.fillStep1() }
        compose.onNodeWithText("ชื่อผู้ใช้นี้ใช้ได้").assertExists()
        compose.onNodeWithText("2543").assertExists()
        shot("signup1-th-light")
    }

    @Test @Config(qualifiers = "en-w411dp-h914dp-night-xxhdpi")
    fun signupStep1EnglishDarkWithError() {
        app(ThemeChoice.Dark) { it.navigate(Route.SignupStep1); it.updateUsername("No Spaces"); it.submitStep1() }
        compose.onNodeWithText("Use a-z, 0-9 or _, 3–20 characters").assertExists()
        shot("signup1-en-dark")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun signupStep2Thai() {
        app {
            it.navigate(Route.SignupStep1); it.fillStep1(); it.submitStep1(); settle()
            it.updateEmail("somchai@example.com"); it.updatePassword("short"); it.updateConfirmPassword("short"); it.submitStep2()
        }
        compose.onNodeWithText("รหัสผ่านต้องมีอย่างน้อย 12 ตัวอักษร").assertExists()
        shot("signup2-th-light")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun onboardingThai() {
        app {
            it.navigate(Route.SignupStep1); it.fillStep1(); it.submitStep1(); settle()
            it.updateEmail("somchai@example.com"); it.updatePassword("correct-horse-1"); it.updateConfirmPassword("correct-horse-1")
            it.submitStep2()
        }
        compose.onNodeWithText("เริ่มใช้งาน Wynos").assertExists()
        shot("onboarding-th-light")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun forgotPasswordSentThai() {
        app { it.navigate(Route.ForgotPassword); it.updateResetEmail("somchai@example.com"); it.submitReset() }
        compose.onNodeWithText("ส่งลิงก์ไปที่ somchai@example.com แล้ว ตรวจสอบกล่องอีเมลของคุณ").assertExists()
        shot("forgot-th-light")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun checkEmailThai() {
        repo.requireConfirmation = true
        app {
            it.navigate(Route.SignupStep1); it.fillStep1(); it.submitStep1(); settle()
            it.updateEmail("somchai@example.com"); it.updatePassword("correct-horse-1"); it.updateConfirmPassword("correct-horse-1")
            it.submitStep2()
        }
        compose.onNodeWithText("ตรวจสอบอีเมลของคุณ").assertExists()
        shot("check-email-th-light")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun welcomeInviteGateThai() {
        repo.inviteGate = true
        app { }
        compose.onNodeWithText("โค้ดเชิญ").assertExists()
        shot("welcome-invite-th-light")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun homeWithTwoAccountsThai() {
        repo.users += FakeAuthRepository.User("u1", "a@example.com", "password-1234")
        repo.profiles["u1"] = FakeAuthRepository.Profile("somchai", "สมชาย ใจดี")
        repo.active = "u1"
        store.save(listOf(SavedAccount("u2", "malee", "มาลี", session = "session:u2")))
        app { }
        // Signed in lands on the feed; the account switcher lives under Profile.
        compose.onNodeWithText("สำหรับคุณ").assertExists()
        compose.onNodeWithText("โปรไฟล์").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("ตัวเลือกของฉัน").performClick()
        compose.onNodeWithText("สลับบัญชี").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("มาลี").assertExists()
        shot("accounts-th-light")
    }
}
