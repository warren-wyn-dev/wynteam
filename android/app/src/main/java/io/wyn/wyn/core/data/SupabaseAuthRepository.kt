package io.wyn.wyn.core.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.exception.AuthErrorCode
import io.github.jan.supabase.auth.exception.AuthRestException
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.user.UserSession
import io.github.jan.supabase.postgrest.exception.PostgrestRestException
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.storage.storage
import io.ktor.http.ContentType
import io.wyn.wyn.feature.auth.AuthRules
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.time.Instant
import kotlin.coroutines.cancellation.CancellationException

/** Web links that finish email flows (the same pages the web uses). */
private const val SITE_URL = "https://wynos.online"

class SupabaseAuthRepository(private val clientOrNull: SupabaseClient?) : AuthRepository {
    private val client: SupabaseClient get() = clientOrNull ?: throw NotConfiguredException()
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    override fun currentUserId(): String? {
        val auth = clientOrNull?.auth ?: return null
        return auth.currentUserOrNull()?.id ?: auth.currentSessionOrNull()?.user?.id
    }

    override suspend fun restoreSession(): Boolean {
        val auth = client.auth
        auth.awaitInitialization()
        return auth.currentSessionOrNull() != null
    }

    override suspend fun isInviteGateEnabled(): Boolean =
        client.postgrest.rpc("is_invite_gate_enabled").decodeAs<Boolean>()

    override suspend fun validateReferralCode(code: String): Boolean =
        client.postgrest.rpc("validate_referral_code", buildJsonObject { put("p_code", code) }).decodeAs<Boolean>()

    override suspend fun redeemReferralCode(code: String) {
        client.postgrest.rpc("redeem_referral_code", buildJsonObject { put("p_code", code) })
    }

    override suspend fun signInWithEmail(email: String, password: String) {
        try {
            client.auth.signInWith(Email) {
                this.email = email
                this.password = password
            }
        } catch (error: AuthRestException) {
            if (error.errorCode == AuthErrorCode.EmailNotConfirmed) throw EmailNotConfirmedException()
            throw error
        }
    }

    override suspend fun signUpWithEmail(email: String, password: String): Boolean {
        try {
            client.auth.signUpWith(Email, redirectUrl = "$SITE_URL/auth/callback") {
                this.email = email
                this.password = password
            }
        } catch (error: AuthRestException) {
            if (error.errorCode == AuthErrorCode.UserAlreadyExists || error.errorCode == AuthErrorCode.EmailExists) {
                throw EmailAlreadyRegisteredException()
            }
            throw error
        }
        return client.auth.currentSessionOrNull() != null
    }

    override suspend fun resetPasswordForEmail(email: String) {
        client.auth.resetPasswordForEmail(email, redirectUrl = "$SITE_URL/reset-password")
    }

    override suspend fun isSignupUsernameAvailable(username: String): Boolean {
        val normalized = username.trim().lowercase()
        if (!AuthRules.isUsernameFormatValid(normalized) || normalized in AuthRules.reservedUsernames) return false
        // A failed lookup throws: it must never read as "available".
        return client.postgrest.rpc("is_signup_username_available", buildJsonObject { put("p_username", normalized) })
            .decodeAs<Boolean>()
    }

    override suspend fun hasProfileRow(userId: String): Boolean =
        client.from("profiles").select(Columns.list("id")) { filter { eq("id", userId) } }
            .decodeList<JsonObject>().isNotEmpty()

    override suspend fun setUsername(userId: String, username: String) {
        if (username.lowercase() in AuthRules.reservedUsernames) throw UsernameReservedException()
        val existing = client.from("profiles").select(Columns.list("id")) { filter { eq("username", username) } }
            .decodeList<JsonObject>()
        if (existing.any { it["id"]?.jsonPrimitive?.contentOrNull != userId }) throw UsernameTakenException()
        try {
            client.from("profiles").upsert(buildJsonObject { put("id", userId); put("username", username) })
        } catch (error: PostgrestRestException) {
            if (error.code == "23505") throw UsernameTakenException()
            throw error
        }
    }

    override suspend fun setDisplayName(userId: String, displayName: String) {
        client.from("profiles").update(buildJsonObject { put("display_name", displayName) }) { filter { eq("id", userId) } }
    }

    override suspend fun setDateOfBirth(userId: String, isoDate: String) {
        client.from("profiles").upsert(buildJsonObject { put("id", userId) })
        client.from("profile_private").upsert(buildJsonObject { put("id", userId); put("date_of_birth", isoDate) })
    }

    override suspend fun saveBio(userId: String, bio: String) {
        client.from("profiles").update(buildJsonObject { put("bio", bio) }) { filter { eq("id", userId) } }
    }

    /** Same bucket, path and cache-busting URL as the web's uploadProfileImage. */
    override suspend fun uploadAvatar(userId: String, jpeg: ByteArray) {
        val path = "$userId/avatar.jpg"
        val bucket = client.storage.from("avatars")
        bucket.upload(path, jpeg) {
            upsert = true
            contentType = ContentType.Image.JPEG
        }
        val url = "${bucket.publicUrl(path)}?v=${System.currentTimeMillis()}"
        client.from("profiles").update(buildJsonObject { put("avatar_url", url) }) { filter { eq("id", userId) } }
    }

    override suspend fun completeOnboarding(userId: String) {
        client.from("profile_private").update(
            buildJsonObject {
                put("onboarding_completed", true)
                put("onboarding_completed_at", Instant.now().toString())
            },
        ) { filter { eq("id", userId) } }
    }

    override suspend fun fetchAccountSummary(userId: String): AccountSummary? {
        val row = client.from("profiles").select(Columns.list("username", "display_name", "avatar_url")) {
            filter { eq("id", userId) }
        }.decodeList<JsonObject>().firstOrNull() ?: return null
        fun text(key: String) = (row[key] as? JsonPrimitive)?.takeIf { it.isString }?.content
        return AccountSummary(userId, text("username"), text("display_name"), text("avatar_url"))
    }

    override suspend fun signOut() {
        client.auth.signOut()
    }

    override suspend fun detachSession(): SavedSession? {
        val session = client.auth.currentSessionOrNull() ?: return null
        client.auth.clearSession()
        return SavedSession(json.encodeToString(UserSession.serializer(), session))
    }

    override suspend fun attachSession(session: SavedSession): Boolean {
        val auth = client.auth
        return try {
            auth.importSession(json.decodeFromString(UserSession.serializer(), session.json))
            // Proves the saved refresh token is still valid before showing the account.
            auth.refreshCurrentSession()
            true
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            runCatching { auth.clearSession() }
            false
        }
    }
}
