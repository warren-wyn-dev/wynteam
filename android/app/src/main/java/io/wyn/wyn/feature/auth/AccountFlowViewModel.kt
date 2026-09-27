package io.wyn.wyn.feature.auth

import androidx.annotation.StringRes
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.wyn.wyn.R
import io.wyn.wyn.core.data.AccountStore
import io.wyn.wyn.core.data.AuthRepository
import io.wyn.wyn.core.data.EmailAlreadyRegisteredException
import io.wyn.wyn.core.data.EmailNotConfirmedException
import io.wyn.wyn.core.data.SavedAccount
import io.wyn.wyn.core.data.SavedSession
import io.wyn.wyn.core.data.UsernameReservedException
import io.wyn.wyn.core.data.UsernameTakenException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

/** A message from string resources, resolved by the screen. */
data class UiText(@StringRes val res: Int, val args: List<Any> = emptyList())

sealed interface Route {
    data object Booting : Route
    data object SessionCheckFailed : Route
    data object Welcome : Route
    data class Login(val addingAccount: Boolean = false) : Route
    data object SignupStep1 : Route
    data object SignupStep2 : Route
    data class CheckEmail(val email: String) : Route
    data object Onboarding : Route
    data object ForgotPassword : Route
    data object Home : Route
}

enum class InviteGate { Checking, Open, Blocked }
enum class UsernameState { Idle, Invalid, Checking, Available, Taken, Error }

/** web MAX_SAVED_ACCOUNTS. */
const val MAX_SAVED_ACCOUNTS = 9

/**
 * Navigation and logic for the account screens, following the web's
 * auth flow (web/components/auth-flow/screens.tsx) step for step so both
 * platforms create identical accounts.
 */
class AccountFlowViewModel(
    private val repo: AuthRepository,
    private val accounts: AccountStore,
    val configured: Boolean,
) : ViewModel() {
    var stack by mutableStateOf<List<Route>>(listOf(Route.Booting))
        private set
    val route: Route get() = stack.last()

    // Welcome
    var inviteGate by mutableStateOf(InviteGate.Checking); private set
    var inviteCode by mutableStateOf(""); private set
    var inviteError by mutableStateOf<UiText?>(null); private set
    var inviteLoading by mutableStateOf(false); private set
    var welcomeError by mutableStateOf<UiText?>(null); private set
    private var pendingReferralCode: String? = null

    // Signup draft (passwords are cleared as soon as they are used)
    var username by mutableStateOf(""); private set
    var displayName by mutableStateOf(""); private set
    var birthDay by mutableStateOf<Int?>(null); private set
    var birthMonth by mutableStateOf<Int?>(null); private set
    var birthYear by mutableStateOf<Int?>(null); private set
    var email by mutableStateOf(""); private set
    var password by mutableStateOf(""); private set
    var confirmPassword by mutableStateOf(""); private set
    var usernameState by mutableStateOf(UsernameState.Idle); private set
    var signupError by mutableStateOf<UiText?>(null); private set
    var signupLoading by mutableStateOf(false); private set
    private var usernameCheck: Job? = null

    // Login / forgot password
    var loginEmail by mutableStateOf(""); private set
    var loginPassword by mutableStateOf(""); private set
    var loginError by mutableStateOf<UiText?>(null); private set
    var loginLoading by mutableStateOf(false); private set
    var resetEmail by mutableStateOf(""); private set
    var resetError by mutableStateOf<UiText?>(null); private set
    var resetLoading by mutableStateOf(false); private set
    var resetSent by mutableStateOf(false); private set

    // Onboarding
    var bio by mutableStateOf(""); private set
    var avatar by mutableStateOf<ByteArray?>(null); private set
    var onboardingError by mutableStateOf<UiText?>(null); private set
    var onboardingLoading by mutableStateOf(false); private set

    // Home (account switcher)
    var savedAccounts by mutableStateOf<List<SavedAccount>>(emptyList()); private set
    var activeUserId by mutableStateOf<String?>(null); private set
    var homeBusy by mutableStateOf(false); private set
    var homeMessage by mutableStateOf<UiText?>(null); private set
    private var returnToUserId: String? = null

    init {
        savedAccounts = accounts.all()
        boot()
    }

    fun boot() {
        stack = listOf(Route.Booting)
        if (!configured) {
            stack = listOf(Route.Welcome)
            inviteGate = InviteGate.Open
            return
        }
        viewModelScope.launch {
            val signedIn = try {
                repo.restoreSession()
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                stack = listOf(Route.SessionCheckFailed)
                return@launch
            }
            if (signedIn) {
                stack = listOf(postAuthRoute())
            } else {
                showWelcome()
            }
        }
    }

    private fun showWelcome() {
        stack = listOf(Route.Welcome)
        checkInviteGate()
    }

    private fun checkInviteGate() {
        inviteGate = InviteGate.Checking
        viewModelScope.launch {
            inviteGate = try {
                if (repo.isInviteGateEnabled()) InviteGate.Blocked else InviteGate.Open
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                InviteGate.Open
            }
        }
    }

    fun navigate(to: Route) {
        stack = stack + to
    }

    /** False when there is nowhere to go back to (the activity should finish). */
    fun back(): Boolean {
        val current = route
        if (current is Route.Login && current.addingAccount) {
            returnToUserId?.let { cancelAddAccount(it) }
            return true
        }
        if (stack.size <= 1) return false
        stack = stack.dropLast(1)
        return true
    }

    // ---- Welcome -----------------------------------------------------------------

    fun updateInviteCode(value: String) {
        inviteCode = value.uppercase()
        inviteError = null
    }

    fun submitInviteCode() {
        val code = inviteCode.trim()
        if (code.isEmpty()) {
            inviteError = UiText(R.string.err_invite_empty)
            return
        }
        inviteLoading = true
        inviteError = null
        viewModelScope.launch {
            try {
                if (repo.validateReferralCode(code)) {
                    pendingReferralCode = code
                    inviteGate = InviteGate.Open
                } else {
                    inviteError = UiText(R.string.err_invite_invalid)
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                inviteError = UiText(R.string.err_connection)
            } finally {
                inviteLoading = false
            }
        }
    }

    /** Google needs the Android OAuth client first (see ANDROID_NATIVE_PLAN.md). */
    fun signInWithGoogle() {
        welcomeError = UiText(R.string.google_not_ready)
    }

    // ---- Signup step 1 -------------------------------------------------------------

    fun updateUsername(value: String) {
        username = value
        signupError = null
        refreshUsernameState()
    }

    fun updateDisplayName(value: String) {
        displayName = value
        signupError = null
    }

    fun updateBirthDate(day: Int? = birthDay, month: Int? = birthMonth, year: Int? = birthYear) {
        birthDay = day
        birthMonth = month
        birthYear = year
        signupError = null
    }

    private fun refreshUsernameState() {
        usernameCheck?.cancel()
        val normalized = username.trim().lowercase()
        usernameState = when {
            normalized.isEmpty() -> UsernameState.Idle
            !AuthRules.isUsernameFormatValid(normalized) -> UsernameState.Invalid
            normalized in AuthRules.reservedUsernames -> UsernameState.Taken
            !configured -> UsernameState.Idle
            else -> UsernameState.Checking
        }
        if (usernameState != UsernameState.Checking) return
        usernameCheck = viewModelScope.launch {
            delay(400)
            usernameState = try {
                if (repo.isSignupUsernameAvailable(normalized)) UsernameState.Available else UsernameState.Taken
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                UsernameState.Error
            }
        }
    }

    fun submitStep1() {
        if (signupLoading) return
        val name = username.trim().lowercase()
        val shown = displayName.trim()
        username = name
        displayName = shown
        signupError = null
        if (!AuthRules.isUsernameFormatValid(name)) {
            signupError = UiText(R.string.err_username_format)
            return
        }
        if (name in AuthRules.reservedUsernames) {
            signupError = UiText(R.string.err_username_reserved)
            return
        }
        if (shown.isEmpty()) {
            signupError = UiText(R.string.err_display_name)
            return
        }
        val birthDate = AuthRules.parseBirthDate(birthYear, birthMonth, birthDay)
        if (birthDate == null) {
            signupError = UiText(R.string.err_birth_date, listOf(AuthRules.MIN_ONBOARDING_AGE))
            return
        }
        signupLoading = true
        viewModelScope.launch {
            try {
                val available = try {
                    repo.isSignupUsernameAvailable(name)
                } catch (error: CancellationException) {
                    throw error
                } catch (error: Exception) {
                    signupError = UiText(R.string.err_username_check)
                    return@launch
                }
                usernameCheck?.cancel()
                usernameState = if (available) UsernameState.Available else UsernameState.Taken
                if (!available) {
                    signupError = UiText(R.string.err_username_taken)
                    return@launch
                }
                val userId = repo.currentUserId()
                if (userId == null) {
                    // No session yet (email sign-up): collect email and password next.
                    navigate(Route.SignupStep2)
                    return@launch
                }
                // Already signed in (Google, or a confirmed email with no profile yet): commit now.
                commitProfile(userId, name, shown, birthDate)
                stack = listOf(Route.Onboarding)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                signupError = if (error is UsernameTakenException || error is UsernameReservedException) {
                    UiText(R.string.err_username_taken_retry)
                } else {
                    UiText(R.string.err_generic)
                }
            } finally {
                signupLoading = false
            }
        }
    }

    private suspend fun commitProfile(userId: String, name: String, shown: String, birthDate: String) {
        repo.setUsername(userId, name)
        repo.setDisplayName(userId, shown)
        repo.setDateOfBirth(userId, birthDate)
        pendingReferralCode?.let { code ->
            // Best effort, as on the web.
            runCatching { repo.redeemReferralCode(code) }
            pendingReferralCode = null
        }
        registerActive(userId)
    }

    // ---- Signup step 2 -------------------------------------------------------------

    fun updateEmail(value: String) {
        email = value
        signupError = null
    }

    fun updatePassword(value: String) {
        password = value
        signupError = null
    }

    fun updateConfirmPassword(value: String) {
        confirmPassword = value
        signupError = null
    }

    fun submitStep2() {
        if (signupLoading) return
        signupError = null
        val address = email.trim()
        if (!AuthRules.isEmailValid(address)) {
            signupError = UiText(R.string.err_email)
            return
        }
        if (password.length < AuthRules.MIN_SIGNUP_PASSWORD_LENGTH) {
            signupError = UiText(R.string.err_password_short, listOf(AuthRules.MIN_SIGNUP_PASSWORD_LENGTH))
            return
        }
        if (password != confirmPassword) {
            signupError = UiText(R.string.err_password_mismatch)
            return
        }
        val birthDate = AuthRules.parseBirthDate(birthYear, birthMonth, birthDay)
        if (birthDate == null) {
            stack = stack.dropLast(1)
            return
        }
        signupLoading = true
        viewModelScope.launch {
            try {
                // Someone may have taken the name since step 1; the UNIQUE constraint stays authoritative.
                val available = try {
                    repo.isSignupUsernameAvailable(username)
                } catch (error: CancellationException) {
                    throw error
                } catch (error: Exception) {
                    signupError = UiText(R.string.err_username_check)
                    return@launch
                }
                if (!available) {
                    signupError = UiText(R.string.err_username_taken_back)
                    return@launch
                }
                val secret = password
                password = ""
                confirmPassword = ""
                val hasSession = repo.signUpWithEmail(address, secret)
                if (!hasSession) {
                    // Email confirmation is on: RLS rejects profile writes until the address is confirmed.
                    stack = listOf(Route.Welcome, Route.CheckEmail(address))
                    return@launch
                }
                val userId = repo.currentUserId() ?: error("No session after sign-up")
                commitProfile(userId, username, displayName, birthDate)
                stack = listOf(Route.Onboarding)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                signupError = when (error) {
                    is EmailAlreadyRegisteredException -> UiText(R.string.err_email_registered)
                    is UsernameTakenException, is UsernameReservedException -> UiText(R.string.err_username_taken_back)
                    else -> UiText(R.string.err_signup_failed)
                }
            } finally {
                signupLoading = false
            }
        }
    }

    // ---- Login -------------------------------------------------------------------

    fun updateLoginEmail(value: String) {
        loginEmail = value
        loginError = null
    }

    fun updateLoginPassword(value: String) {
        loginPassword = value
        loginError = null
    }

    fun submitLogin() {
        if (loginLoading) return
        loginError = null
        val address = loginEmail.trim()
        if (address.isEmpty() || loginPassword.isEmpty()) {
            loginError = UiText(R.string.err_login_empty)
            return
        }
        loginLoading = true
        viewModelScope.launch {
            try {
                repo.signInWithEmail(address, loginPassword)
                loginPassword = ""
                returnToUserId = null
                stack = listOf(postAuthRoute())
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                loginError = if (error is EmailNotConfirmedException) {
                    UiText(R.string.err_login_unconfirmed)
                } else {
                    UiText(R.string.err_login_failed)
                }
            } finally {
                loginLoading = false
            }
        }
    }

    /** The web's resolvePostAuthPath: only a brand-new account (no profiles row) goes to signup. */
    private suspend fun postAuthRoute(): Route {
        val userId = repo.currentUserId() ?: return Route.Welcome
        return try {
            if (repo.hasProfileRow(userId)) {
                registerActive(userId)
                Route.Home
            } else {
                Route.SignupStep1
            }
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            registerActive(userId)
            Route.Home
        }
    }

    // ---- Forgot password -----------------------------------------------------------

    fun updateResetEmail(value: String) {
        resetEmail = value
        resetError = null
    }

    fun submitReset() {
        if (resetLoading) return
        resetError = null
        val address = resetEmail.trim()
        if (!AuthRules.isEmailValid(address)) {
            resetError = UiText(R.string.err_email)
            return
        }
        resetLoading = true
        viewModelScope.launch {
            try {
                repo.resetPasswordForEmail(address)
                resetSent = true
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                resetError = UiText(R.string.err_reset_failed)
            } finally {
                resetLoading = false
            }
        }
    }

    // ---- Onboarding --------------------------------------------------------------

    fun updateBio(value: String) {
        bio = value
    }

    fun setAvatar(jpeg: ByteArray?, error: UiText? = null) {
        onboardingError = error
        if (error == null) avatar = jpeg
    }

    fun finishOnboarding(skip: Boolean = false) {
        if (onboardingLoading) return
        onboardingLoading = true
        onboardingError = null
        viewModelScope.launch {
            try {
                val userId = repo.currentUserId() ?: error("Session unavailable")
                val photo = avatar
                if (!skip && photo != null) repo.uploadAvatar(userId, photo)
                if (bio.trim().isNotEmpty()) repo.saveBio(userId, bio.trim())
                repo.completeOnboarding(userId)
                registerActive(userId)
                stack = listOf(Route.Home)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                onboardingError = UiText(R.string.err_profile_save)
            } finally {
                onboardingLoading = false
            }
        }
    }

    // ---- Accounts ------------------------------------------------------------------

    /** Records the signed-in account as the active one (its session lives in Supabase's store). */
    private suspend fun registerActive(userId: String) {
        val summary = runCatching { repo.fetchAccountSummary(userId) }.getOrNull()
        val current = accounts.all()
        val updated = SavedAccount(
            userId = userId,
            username = summary?.username,
            displayName = summary?.displayName,
            avatarUrl = summary?.avatarUrl,
            session = null,
        )
        val next = current.filterNot { it.userId == userId } + updated
        // Only one account can be active: drop any stale entry without a saved session.
        save(next.filter { it.userId == userId || it.session != null })
        activeUserId = userId
        resetDrafts()
    }

    private fun save(list: List<SavedAccount>) {
        accounts.save(list)
        savedAccounts = list
    }

    private fun resetDrafts() {
        username = ""; displayName = ""; birthDay = null; birthMonth = null; birthYear = null
        email = ""; password = ""; confirmPassword = ""; usernameState = UsernameState.Idle
        loginEmail = ""; loginPassword = ""; bio = ""; avatar = null
        signupError = null; loginError = null; onboardingError = null
    }

    /** Keeps the current account for switching back, then shows Login for another one. */
    fun addAccount() {
        val activeId = repo.currentUserId() ?: return
        if (homeBusy) return
        if (accounts.all().size >= MAX_SAVED_ACCOUNTS) {
            homeMessage = UiText(R.string.accounts_limit, listOf(MAX_SAVED_ACCOUNTS))
            return
        }
        homeMessage = null
        homeBusy = true
        viewModelScope.launch {
            try {
                val session = repo.detachSession() ?: return@launch
                save(accounts.all().map { if (it.userId == activeId) it.copy(session = session.json) else it })
                returnToUserId = activeId
                activeUserId = null
                stack = listOf(Route.Login(addingAccount = true))
            } finally {
                homeBusy = false
            }
        }
    }

    /** Forgets another account on this phone, with its saved session (web removeSavedAccount). */
    fun removeAccount(userId: String) {
        if (homeBusy || userId == activeUserId) return
        save(accounts.all().filterNot { it.userId == userId })
    }

    fun clearHomeMessage() {
        homeMessage = null
    }

    private fun cancelAddAccount(userId: String) {
        switchTo(userId)
    }

    fun switchTo(userId: String) {
        if (homeBusy) return
        val target = accounts.all().firstOrNull { it.userId == userId } ?: return
        homeBusy = true
        homeMessage = null
        viewModelScope.launch {
            try {
                val activeId = repo.currentUserId()
                if (activeId == userId) {
                    stack = listOf(Route.Home)
                    return@launch
                }
                val previous = if (activeId != null) repo.detachSession() else null
                if (activeId != null && previous != null) {
                    save(accounts.all().map { if (it.userId == activeId) it.copy(session = previous.json) else it })
                }
                val saved = target.session
                if (saved != null && repo.attachSession(SavedSession(saved))) {
                    returnToUserId = null
                    registerActive(userId)
                    stack = listOf(Route.Home)
                    return@launch
                }
                // The saved session was revoked or expired: that account must sign in again.
                save(accounts.all().filterNot { it.userId == userId })
                homeMessage = UiText(R.string.account_needs_sign_in)
                val back = previous ?: accounts.all().firstOrNull { it.session != null }?.session?.let(::SavedSession)
                val restoredId = if (previous != null) activeId else accounts.all().firstOrNull { it.session != null }?.userId
                if (back != null && restoredId != null && repo.attachSession(back)) {
                    registerActive(restoredId)
                    stack = listOf(Route.Home)
                } else {
                    returnToUserId = null
                    showWelcome()
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                homeMessage = UiText(R.string.err_generic)
            } finally {
                homeBusy = false
            }
        }
    }

    /** Signs out of this account on this phone; another saved account takes over if there is one. */
    fun signOut() {
        if (homeBusy) return
        homeBusy = true
        viewModelScope.launch {
            try {
                val activeId = repo.currentUserId()
                runCatching { repo.signOut() }
                save(accounts.all().filterNot { it.userId == activeId })
                activeUserId = null
                for (next in accounts.all()) {
                    val saved = next.session ?: continue
                    if (repo.attachSession(SavedSession(saved))) {
                        registerActive(next.userId)
                        stack = listOf(Route.Home)
                        return@launch
                    }
                    save(accounts.all().filterNot { it.userId == next.userId })
                }
                showWelcome()
            } finally {
                homeBusy = false
            }
        }
    }
}
