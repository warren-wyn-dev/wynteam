package io.wyn.wyn.testing

import io.wyn.wyn.core.data.AccountSummary
import io.wyn.wyn.core.data.AuthRepository
import io.wyn.wyn.core.data.EmailAlreadyRegisteredException
import io.wyn.wyn.core.data.EmailNotConfirmedException
import io.wyn.wyn.core.data.SavedSession

/** An in-memory server: accounts, profiles and one active session. */
class FakeAuthRepository : AuthRepository {
    data class User(val id: String, val email: String, val password: String, var confirmed: Boolean = true)
    data class Profile(var username: String? = null, var displayName: String? = null, var bio: String? = null)

    val users = mutableListOf<User>()
    val profiles = mutableMapOf<String, Profile>()
    val birthDates = mutableMapOf<String, String>()
    val completed = mutableSetOf<String>()
    val redeemed = mutableListOf<String>()
    val revoked = mutableSetOf<String>()
    val resetEmails = mutableListOf<String>()
    val calls = mutableListOf<String>()
    var active: String? = null
    var inviteGate = false
    var requireConfirmation = false
    var failUsernameCheck = false
    var failRestore = false

    override fun currentUserId() = active
    override suspend fun restoreSession(): Boolean {
        if (failRestore) error("offline")
        return active != null
    }
    override suspend fun isInviteGateEnabled() = inviteGate
    override suspend fun validateReferralCode(code: String) = code == "FRIEND1"
    override suspend fun redeemReferralCode(code: String) { redeemed += code }

    override suspend fun signInWithEmail(email: String, password: String) {
        val user = users.firstOrNull { it.email == email && it.password == password } ?: error("invalid_credentials")
        if (!user.confirmed) throw EmailNotConfirmedException()
        active = user.id
    }

    override suspend fun signUpWithEmail(email: String, password: String): Boolean {
        if (users.any { it.email == email }) throw EmailAlreadyRegisteredException()
        val user = User("u${users.size + 1}", email, password, confirmed = !requireConfirmation)
        users += user
        if (requireConfirmation) return false
        active = user.id
        return true
    }

    override suspend fun resetPasswordForEmail(email: String) { resetEmails += email }

    override suspend fun isSignupUsernameAvailable(username: String): Boolean {
        if (failUsernameCheck) error("network")
        return profiles.values.none { it.username == username }
    }

    override suspend fun hasProfileRow(userId: String) = userId in profiles
    override suspend fun setUsername(userId: String, username: String) {
        calls += "setUsername"
        profiles.getOrPut(userId) { Profile() }.username = username
    }
    override suspend fun setDisplayName(userId: String, displayName: String) {
        calls += "setDisplayName"
        profiles.getValue(userId).displayName = displayName
    }
    override suspend fun setDateOfBirth(userId: String, isoDate: String) {
        calls += "setDateOfBirth"
        birthDates[userId] = isoDate
    }
    override suspend fun saveBio(userId: String, bio: String) { profiles.getValue(userId).bio = bio }
    override suspend fun uploadAvatar(userId: String, jpeg: ByteArray) { calls += "uploadAvatar" }
    override suspend fun completeOnboarding(userId: String) { completed += userId }

    override suspend fun fetchAccountSummary(userId: String) =
        profiles[userId]?.let { AccountSummary(userId, it.username, it.displayName, null) }

    override suspend fun signOut() {
        active?.let { revoked += it }
        active = null
    }

    override suspend fun detachSession(): SavedSession? {
        val id = active ?: return null
        active = null
        return SavedSession("session:$id")
    }

    override suspend fun attachSession(session: SavedSession): Boolean {
        val id = session.json.removePrefix("session:")
        if (id in revoked) return false
        active = id
        return true
    }
}
