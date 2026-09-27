package io.wyn.wyn.core.data

/**
 * Account operations, mirroring web/lib/auth-repository.ts so every
 * platform writes the same rows through the same RLS. The interface keeps
 * screens and view models testable without a network.
 */
interface AuthRepository {
    /** The signed-in user's id, or null. */
    fun currentUserId(): String?

    /** Waits for the saved session to load; true when one is signed in. */
    suspend fun restoreSession(): Boolean

    suspend fun isInviteGateEnabled(): Boolean
    suspend fun validateReferralCode(code: String): Boolean
    suspend fun redeemReferralCode(code: String)

    /** Throws [EmailNotConfirmedException] or another error on failure. */
    suspend fun signInWithEmail(email: String, password: String)

    /** True when a session was created, false when the email must be confirmed first. */
    suspend fun signUpWithEmail(email: String, password: String): Boolean

    suspend fun resetPasswordForEmail(email: String)

    /** Boolean-only pre-signup check (RPC is_signup_username_available). */
    suspend fun isSignupUsernameAvailable(username: String): Boolean

    suspend fun hasProfileRow(userId: String): Boolean
    suspend fun setUsername(userId: String, username: String)
    suspend fun setDisplayName(userId: String, displayName: String)
    suspend fun setDateOfBirth(userId: String, isoDate: String)
    suspend fun saveBio(userId: String, bio: String)
    suspend fun uploadAvatar(userId: String, jpeg: ByteArray)
    suspend fun completeOnboarding(userId: String)

    suspend fun fetchAccountSummary(userId: String): AccountSummary?

    /** Signs out on this device only (the web's `scope: "local"`). */
    suspend fun signOut()

    /** Forgets the local session without revoking it, so it can be switched back to. */
    suspend fun detachSession(): SavedSession?
    suspend fun attachSession(session: SavedSession): Boolean
}

data class AccountSummary(val userId: String, val username: String?, val displayName: String?, val avatarUrl: String?)

/** An opaque saved session (JSON) for account switching. */
@JvmInline
value class SavedSession(val json: String)

class UsernameTakenException : Exception()
class UsernameReservedException : Exception()
class EmailAlreadyRegisteredException : Exception()
class EmailNotConfirmedException : Exception()
class NotConfiguredException : Exception()
