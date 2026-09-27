package io.wyn.wyn.feature.auth

import io.wyn.wyn.R
import io.wyn.wyn.core.data.MemoryAccountStore
import io.wyn.wyn.testing.FakeAuthRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
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
import java.time.LocalDate

@OptIn(ExperimentalCoroutinesApi::class)
class AccountFlowViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val repo = FakeAuthRepository()
    private val store = MemoryAccountStore()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    private fun TestScope.start(): AccountFlowViewModel {
        val vm = AccountFlowViewModel(repo, store, configured = true)
        advanceUntilIdle()
        return vm
    }

    private fun AccountFlowViewModel.fillStep1(name: String = "somchai", shown: String = "Somchai", year: Int = 2000) {
        updateUsername(name)
        updateDisplayName(shown)
        updateBirthDate(day = 15, month = 6, year = year)
    }

    private fun AccountFlowViewModel.fillStep2(email: String = "s@example.com", password: String = "correct-horse-1") {
        updateEmail(email)
        updatePassword(password)
        updateConfirmPassword(password)
    }

    private fun TestScope.existingUser(id: String, email: String, username: String) {
        repo.users += FakeAuthRepository.User(id, email, "password-1234")
        repo.profiles[id] = FakeAuthRepository.Profile(username, username.replaceFirstChar(Char::uppercase))
    }

    @Test fun emailSignupWritesTheSameRowsAsTheWebAndEndsSignedIn() = runTest(dispatcher) {
        val vm = start()
        assertEquals(Route.Welcome, vm.route)
        vm.navigate(Route.SignupStep1)
        vm.fillStep1()
        advanceUntilIdle()
        assertEquals(UsernameState.Available, vm.usernameState)
        vm.submitStep1(); advanceUntilIdle()
        assertEquals(Route.SignupStep2, vm.route)

        vm.fillStep2()
        vm.submitStep2(); advanceUntilIdle()
        assertEquals(Route.Onboarding, vm.route)
        val id = repo.active!!
        assertEquals("somchai", repo.profiles.getValue(id).username)
        assertEquals("Somchai", repo.profiles.getValue(id).displayName)
        assertEquals("2000-06-15", repo.birthDates[id])
        assertEquals(listOf("setUsername", "setDisplayName", "setDateOfBirth"), repo.calls)
        assertEquals("", vm.password)

        vm.updateBio("  ชอบถ่ายรูป  ")
        vm.finishOnboarding(); advanceUntilIdle()
        assertEquals(Route.Home, vm.route)
        assertEquals("ชอบถ่ายรูป", repo.profiles.getValue(id).bio)
        assertTrue(id in repo.completed)
        assertEquals(listOf(id), store.all().map { it.userId })
    }

    @Test fun step1RejectsWhatTheWebRejects() = runTest(dispatcher) {
        val vm = start()
        vm.navigate(Route.SignupStep1)
        vm.fillStep1(name = "No Spaces")
        vm.submitStep1()
        assertEquals(R.string.err_username_format, vm.signupError?.res)
        vm.fillStep1(name = "admin")
        vm.submitStep1()
        assertEquals(R.string.err_username_reserved, vm.signupError?.res)
        vm.fillStep1(shown = "   ")
        vm.submitStep1()
        assertEquals(R.string.err_display_name, vm.signupError?.res)
        vm.fillStep1(year = LocalDate.now().year - 5)
        vm.submitStep1()
        assertEquals(R.string.err_birth_date, vm.signupError?.res)
        assertEquals(Route.SignupStep1, vm.route)
    }

    @Test fun aTakenUsernameStopsStep1AndAFailedCheckIsNeverAvailable() = runTest(dispatcher) {
        existingUser("u9", "old@example.com", "somchai")
        val vm = start()
        vm.navigate(Route.SignupStep1)
        vm.fillStep1()
        advanceUntilIdle()
        assertEquals(UsernameState.Taken, vm.usernameState)
        vm.submitStep1(); advanceUntilIdle()
        assertEquals(R.string.err_username_taken, vm.signupError?.res)

        repo.failUsernameCheck = true
        vm.fillStep1(name = "someone_new")
        advanceUntilIdle()
        assertEquals(UsernameState.Error, vm.usernameState)
        vm.submitStep1(); advanceUntilIdle()
        assertEquals(R.string.err_username_check, vm.signupError?.res)
        assertEquals(Route.SignupStep1, vm.route)
    }

    @Test fun step2ChecksPasswordsLikeTheWeb() = runTest(dispatcher) {
        val vm = start()
        vm.navigate(Route.SignupStep1); vm.fillStep1(); vm.submitStep1(); advanceUntilIdle()
        vm.fillStep2(email = "not-an-email"); vm.submitStep2()
        assertEquals(R.string.err_email, vm.signupError?.res)
        vm.fillStep2(password = "short"); vm.submitStep2()
        assertEquals(R.string.err_password_short, vm.signupError?.res)
        assertEquals(listOf<Any>(12), vm.signupError?.args)
        vm.fillStep2(); vm.updateConfirmPassword("different-pass-1"); vm.submitStep2()
        assertEquals(R.string.err_password_mismatch, vm.signupError?.res)
        existingUser("u9", "s@example.com", "other")
        vm.fillStep2(); vm.submitStep2(); advanceUntilIdle()
        assertEquals(R.string.err_email_registered, vm.signupError?.res)
    }

    @Test fun confirmationSignupWritesNothingUntilTheFirstLogin() = runTest(dispatcher) {
        repo.requireConfirmation = true
        val vm = start()
        vm.navigate(Route.SignupStep1); vm.fillStep1(); vm.submitStep1(); advanceUntilIdle()
        vm.fillStep2(); vm.submitStep2(); advanceUntilIdle()
        assertEquals(Route.CheckEmail("s@example.com"), vm.route)
        assertTrue(repo.profiles.isEmpty())

        vm.navigate(Route.Login())
        vm.updateLoginEmail("s@example.com"); vm.updateLoginPassword("correct-horse-1")
        vm.submitLogin(); advanceUntilIdle()
        assertEquals(R.string.err_login_unconfirmed, vm.loginError?.res)

        repo.users.first().confirmed = true
        vm.submitLogin(); advanceUntilIdle()
        // No profiles row yet: like the web, finish step 1 with the saved draft, straight to onboarding.
        assertEquals(Route.SignupStep1, vm.route)
        vm.submitStep1(); advanceUntilIdle()
        assertEquals(Route.Onboarding, vm.route)
        assertEquals("somchai", repo.profiles.getValue(repo.active!!).username)
    }

    @Test fun loginErrorsAndAnExistingAccountGoesHome() = runTest(dispatcher) {
        existingUser("u1", "a@example.com", "anna")
        val vm = start()
        vm.navigate(Route.Login())
        vm.submitLogin()
        assertEquals(R.string.err_login_empty, vm.loginError?.res)
        vm.updateLoginEmail("a@example.com"); vm.updateLoginPassword("wrong")
        vm.submitLogin(); advanceUntilIdle()
        assertEquals(R.string.err_login_failed, vm.loginError?.res)
        vm.updateLoginPassword("password-1234")
        vm.submitLogin(); advanceUntilIdle()
        assertEquals(listOf(Route.Home), vm.stack)
        assertEquals("u1", vm.activeUserId)
        assertEquals("", vm.loginPassword)
    }

    @Test fun addSwitchAndSignOutKeepEachAccountsOwnSession() = runTest(dispatcher) {
        existingUser("u1", "a@example.com", "anna")
        existingUser("u2", "b@example.com", "ben")
        val vm = start()
        vm.navigate(Route.Login()); vm.updateLoginEmail("a@example.com"); vm.updateLoginPassword("password-1234")
        vm.submitLogin(); advanceUntilIdle()

        vm.addAccount(); advanceUntilIdle()
        assertEquals(Route.Login(addingAccount = true), vm.route)
        assertNull(repo.active)
        // Back from "add account" returns to the first account.
        assertTrue(vm.back()); advanceUntilIdle()
        assertEquals("u1", repo.active)
        assertEquals(Route.Home, vm.route)

        vm.addAccount(); advanceUntilIdle()
        vm.updateLoginEmail("b@example.com"); vm.updateLoginPassword("password-1234")
        vm.submitLogin(); advanceUntilIdle()
        assertEquals("u2", repo.active)
        assertEquals(setOf("u1", "u2"), vm.savedAccounts.map { it.userId }.toSet())

        vm.switchTo("u1"); advanceUntilIdle()
        assertEquals("u1", repo.active)
        assertEquals("u1", vm.activeUserId)

        vm.signOut(); advanceUntilIdle()
        assertTrue("u1" in repo.revoked)
        assertEquals("u2", repo.active)
        assertEquals(listOf("u2"), store.all().map { it.userId })

        vm.signOut(); advanceUntilIdle()
        assertEquals(Route.Welcome, vm.route)
        assertTrue(store.all().isEmpty())
    }

    @Test fun pushFollowsTheActiveAccountAcrossAddSwitchAndSignOut() = runTest(dispatcher) {
        existingUser("u1", "a@example.com", "anna")
        existingUser("u2", "b@example.com", "ben")
        val tokens = io.wyn.wyn.testing.FakePushTokens()
        val push = io.wyn.wyn.core.push.PushController(tokens, io.wyn.wyn.testing.FakeDeviceToken("t1"), io.wyn.wyn.core.push.InMemoryPushMemory()) { true }
        val vm = AccountFlowViewModel(repo, store, configured = true, push = push); advanceUntilIdle()
        vm.navigate(Route.Login()); vm.updateLoginEmail("a@example.com"); vm.updateLoginPassword("password-1234")
        vm.submitLogin(); advanceUntilIdle()
        push.enable("u1")
        assertEquals("u1", tokens.registered["t1"])

        // Adding an account: u1 stops receiving before u2 signs in; Push stays on for both.
        vm.addAccount(); advanceUntilIdle()
        assertTrue(tokens.registered.isEmpty())
        vm.updateLoginEmail("b@example.com"); vm.updateLoginPassword("password-1234")
        vm.submitLogin(); advanceUntilIdle()
        assertEquals("u2", tokens.registered["t1"])

        vm.switchTo("u1"); advanceUntilIdle()
        assertEquals("u1", tokens.registered["t1"])

        // Offline: the switch must not happen while u1 could still receive on this phone.
        tokens.fail = true
        vm.switchTo("u2"); advanceUntilIdle()
        assertEquals("u1", repo.active)
        assertEquals(io.wyn.wyn.R.string.push_detach_failed, vm.homeMessage?.res)

        tokens.fail = false
        vm.signOut(); advanceUntilIdle()
        assertEquals("u2", repo.active)
        assertEquals("u2", tokens.registered["t1"])
    }

    @Test fun aRevokedSavedAccountIsDroppedAndTheCurrentOneKept() = runTest(dispatcher) {
        existingUser("u1", "a@example.com", "anna")
        existingUser("u2", "b@example.com", "ben")
        val vm = start()
        vm.navigate(Route.Login()); vm.updateLoginEmail("a@example.com"); vm.updateLoginPassword("password-1234")
        vm.submitLogin(); advanceUntilIdle()
        vm.addAccount(); advanceUntilIdle()
        vm.updateLoginEmail("b@example.com"); vm.updateLoginPassword("password-1234")
        vm.submitLogin(); advanceUntilIdle()

        repo.revoked += "u1"
        vm.switchTo("u1"); advanceUntilIdle()
        assertEquals(R.string.account_needs_sign_in, vm.homeMessage?.res)
        assertEquals("u2", repo.active)
        assertEquals(listOf("u2"), store.all().map { it.userId })
    }

    @Test fun inviteGateAndSessionCheckFailure() = runTest(dispatcher) {
        repo.inviteGate = true
        val vm = start()
        assertEquals(InviteGate.Blocked, vm.inviteGate)
        vm.submitInviteCode()
        assertEquals(R.string.err_invite_empty, vm.inviteError?.res)
        vm.updateInviteCode("nope"); vm.submitInviteCode(); advanceUntilIdle()
        assertEquals(R.string.err_invite_invalid, vm.inviteError?.res)
        vm.updateInviteCode("friend1"); vm.submitInviteCode(); advanceUntilIdle()
        assertEquals(InviteGate.Open, vm.inviteGate)

        vm.navigate(Route.SignupStep1); vm.fillStep1(); vm.submitStep1(); advanceUntilIdle()
        vm.fillStep2(); vm.submitStep2(); advanceUntilIdle()
        assertEquals(listOf("FRIEND1"), repo.redeemed)

        repo.failRestore = true
        vm.boot(); advanceUntilIdle()
        assertEquals(Route.SessionCheckFailed, vm.route)
    }

    @Test fun forgotPasswordSendsTheWebResetLink() = runTest(dispatcher) {
        val vm = start()
        vm.navigate(Route.ForgotPassword)
        vm.updateResetEmail("bad"); vm.submitReset()
        assertEquals(R.string.err_email, vm.resetError?.res)
        assertFalse(vm.resetSent)
        vm.updateResetEmail(" a@example.com "); vm.submitReset(); advanceUntilIdle()
        assertTrue(vm.resetSent)
        assertEquals(listOf("a@example.com"), repo.resetEmails)
    }
}
