package io.wyn.wyn.feature.settings

import io.wyn.wyn.R
import io.wyn.wyn.core.data.AppLanguage
import io.wyn.wyn.core.data.PasswordFormError
import io.wyn.wyn.core.data.PrivacyField
import io.wyn.wyn.core.data.ThemePreference
import io.wyn.wyn.core.data.validatePasswordChange
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.testing.ChatFixture
import io.wyn.wyn.testing.FakeChatRepository
import io.wyn.wyn.testing.FakeSettingsRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.Instant

@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val repo = FakeSettingsRepository()
    private val appearance = InMemoryAppearance()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    private fun vm() = SettingsViewModel(repo, appearance, ChatFixture.ME, deviceLanguage = AppLanguage.Thai)

    @Test fun passwordFormRulesMatchTheWeb() {
        assertEquals(PasswordFormError.Missing, validatePasswordChange("", "x", "x"))
        assertEquals(PasswordFormError.TooShort, validatePasswordChange("old", "short", "short"))
        assertEquals(PasswordFormError.Mismatch, validatePasswordChange("old", "long-enough-pass", "long-enough-pas"))
        assertEquals(PasswordFormError.Same, validatePasswordChange("long-enough-pass", "long-enough-pass", "long-enough-pass"))
        assertNull(validatePasswordChange("old", "long-enough-pass", "long-enough-pass"))
    }

    @Test fun sectionsAndBack() = runTest(dispatcher) {
        val vm = vm(); advanceUntilIdle()
        assertFalse(vm.back())
        vm.open(SettingsSection.Account)
        vm.open(SettingsSection.Password)
        assertTrue(vm.back())
        assertEquals("password returns to Account", SettingsSection.Account, vm.section)
        vm.back()
        assertEquals(SettingsSection.Root, vm.section)
    }

    @Test fun privacyIsOptimisticWithRollback() = runTest(dispatcher) {
        val vm = vm(); advanceUntilIdle()
        vm.setPrivacy(PrivacyField.IsPrivate, true); advanceUntilIdle()
        assertTrue(vm.privacy!!.isPrivate)
        assertEquals(listOf("is_private=true"), repo.writes)
        repo.fail = true
        vm.setPrivacy(PrivacyField.Dm, "no_one")
        assertEquals("no_one", vm.privacy!!.dmPermission)
        advanceUntilIdle()
        assertEquals("people_i_follow", vm.privacy!!.dmPermission)
        assertEquals(UiText(R.string.settings_save_failed), vm.error)
        vm.toggleOnline(false); advanceUntilIdle()
        assertTrue("rolled back", vm.online)
    }

    @Test fun unblockExportAndDeleteAfterTwoConfirms() = runTest(dispatcher) {
        val vm = vm(); advanceUntilIdle()
        vm.unblock(vm.blocked.single()); advanceUntilIdle()
        assertTrue(vm.blocked.isEmpty())
        var exported: String? = null
        vm.exportData { exported = it }; advanceUntilIdle()
        assertEquals("{\"profile\":{}}", exported)
        vm.ask(SettingsConfirm.DeleteAccount)
        vm.confirmNow()
        assertEquals(SettingsConfirm.DeleteAccountAgain, vm.confirm)
        assertFalse(repo.deleted)
        vm.confirmNow(); advanceUntilIdle()
        assertTrue(repo.deleted)
        assertTrue(vm.deleted)
    }

    @Test fun themeAndLanguageApplyHereAndSaveToTheAccount() = runTest(dispatcher) {
        val vm = vm(); advanceUntilIdle()
        assertEquals(ThemePreference.System, vm.theme)
        assertEquals(AppLanguage.Thai, vm.language)
        vm.chooseTheme(ThemePreference.Dark); advanceUntilIdle()
        assertEquals(ThemePreference.Dark, appearance.theme)
        assertEquals(ThemePreference.Dark, repo.theme)
        assertTrue(vm.chooseLanguage(AppLanguage.English))
        assertFalse("same language: no rebuild", vm.chooseLanguage(AppLanguage.English))
        advanceUntilIdle()
        assertEquals(AppLanguage.English, repo.language)
        repo.fail = true
        vm.chooseTheme(ThemePreference.Light); advanceUntilIdle()
        assertEquals("still applied on this phone", ThemePreference.Light, appearance.theme)
        assertTrue(vm.themeSaveFailed)
    }

    @Test fun passwordChange() = runTest(dispatcher) {
        val vm = vm(); advanceUntilIdle()
        vm.open(SettingsSection.Password)
        vm.submitPassword()
        assertEquals(UiText(R.string.password_missing), vm.passwordError)
        vm.updateCurrent("wrong-password-1"); vm.updateNew("brand-new-password"); vm.updateConfirm("brand-new-password")
        vm.submitPassword(); advanceUntilIdle()
        assertEquals(UiText(R.string.password_wrong), vm.passwordError)
        assertEquals("", vm.currentPassword)
        vm.updateCurrent("current-password-123")
        vm.submitPassword(); advanceUntilIdle()
        assertTrue(vm.passwordSaved)
        assertEquals("brand-new-password", repo.password)
        assertEquals("", vm.newPassword)
    }
}
