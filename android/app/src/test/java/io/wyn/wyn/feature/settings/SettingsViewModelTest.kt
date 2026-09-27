package io.wyn.wyn.feature.settings

import io.wyn.wyn.R
import io.wyn.wyn.core.data.AppLanguage
import io.wyn.wyn.core.data.PasswordFormError
import io.wyn.wyn.core.data.PrivacyField
import io.wyn.wyn.core.data.ThemePreference
import io.wyn.wyn.core.data.WyniiPet
import io.wyn.wyn.core.data.WyniiStage
import io.wyn.wyn.core.data.WyniiStatus
import io.wyn.wyn.core.data.validatePasswordChange
import io.wyn.wyn.core.data.wyniiNextMilestone
import io.wyn.wyn.core.data.wyniiProgress
import io.wyn.wyn.core.data.wyniiStage
import io.wyn.wyn.core.data.wyniiStatus
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.feature.chat.WyniiViewModel
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

    // ---- Wynii ------------------------------------------------------------------------

    @Test fun wyniiStagesMilestonesAndProgress() {
        assertEquals(WyniiStage.Egg, wyniiStage(0))
        assertEquals(WyniiStage.Hatching, wyniiStage(6))
        assertEquals(WyniiStage.Baby, wyniiStage(7))
        assertEquals(WyniiStage.Growing, wyniiStage(30))
        assertEquals(WyniiStage.Mature, wyniiStage(100))
        assertEquals(WyniiStage.Max, wyniiStage(365))
        assertEquals(7, wyniiNextMilestone(3))
        assertNull(wyniiNextMilestone(400))
        assertEquals(50f, wyniiProgress(4, 7), 0.01f)
        assertEquals(100f, wyniiProgress(400, null), 0.01f)
    }

    @Test fun wyniiStatusFollowsTheRound() {
        val now = Instant.parse("2026-09-27T12:00:00Z").toEpochMilli()
        val base = WyniiPet("c", ChatFixture.ME, ChatFixture.OTHER, 12, nextCycleAt = "2026-09-27T00:00:00Z")
        assertEquals(WyniiStatus.Idle(12), wyniiStatus(base, ChatFixture.ME, now))
        val round = base.copy(cycleStartedAt = "2026-09-27T10:00:00Z", userADone = true)
        assertEquals(WyniiStatus.WaitingForOther, wyniiStatus(round, ChatFixture.ME, now))
        assertEquals("seen from the other side", WyniiStatus.YourTurn, wyniiStatus(round, ChatFixture.OTHER, now))
        assertEquals(WyniiStatus.Resting, wyniiStatus(round.copy(cycleStartedAt = "2026-09-26T10:00:00Z"), ChatFixture.ME, now))
        val done = base.copy(lastCompletedAt = "2026-09-27T09:00:00Z", nextCycleAt = "2026-09-28T09:00:00Z")
        assertEquals(WyniiStatus.DoneToday, wyniiStatus(done, ChatFixture.ME, now))
    }

    @Test fun wyniiStartsOnlyInAnAcceptedChat() = runTest(dispatcher) {
        val chat = FakeChatRepository()
        val pet = WyniiViewModel(chat, ChatFixture.ME, ChatFixture.CONVERSATION); advanceUntilIdle()
        assertTrue(pet.loaded)
        assertNull(pet.pet)
        pet.begin(canStart = false); advanceUntilIdle()
        assertEquals(0, chat.startCalls)
        pet.begin(canStart = true); advanceUntilIdle()
        assertEquals(1, chat.startCalls)
        assertEquals(0, pet.pet?.ageDays)
        assertTrue(pet.sheetOpen)
    }
}
