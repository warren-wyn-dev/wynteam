package io.wyn.wyn.core.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.SignOutScope
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import io.wyn.wyn.BuildConfig
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.Instant

/** The profile's privacy columns (web Settings > Privacy). */
data class PrivacySettings(
    val isPrivate: Boolean = false,
    val dmPermission: String = "everyone",
    val mentionPermission: String = "everyone",
    val commentPermission: String = "everyone",
    val likesVisibility: String = "everyone",
)

enum class PrivacyField(val column: String) {
    IsPrivate("is_private"), Dm("dm_permission"), Mention("mention_permission"), Comment("comment_permission"), Likes("likes_visibility"),
}

/** web: who may message / mention / comment; who sees likes. */
val INTERACTION_CHOICES = listOf("everyone", "people_i_follow", "no_one")
val LIKES_CHOICES = listOf("everyone", "friends", "only_me")

/** web legalTypes, in order. */
val LEGAL_TYPES = listOf("terms_of_service", "privacy_policy", "community_guidelines", "copyright_policy", "report_policy", "appeal_policy")

data class LegalDocument(val type: String, val version: String, val title: String, val content: String)

enum class ThemePreference(val wire: String) {
    System("system"), Light("light"), Dark("dark");
    companion object { fun of(value: String?) = entries.firstOrNull { it.wire == value } }
}

enum class AppLanguage(val wire: String) {
    Thai("th"), English("en");
    companion object { fun of(value: String?) = entries.firstOrNull { it.wire == value } }
}

/** Why changing the password did not happen (web AccountPasswordError). */
class PasswordChangeException(val reason: Reason) : Exception(reason.name) {
    enum class Reason { AccountChanged, NoEmail, WrongPassword, ReauthenticationRequired, UpdateFailed }
}

/** web signup-password-policy MIN_SIGNUP_PASSWORD_LENGTH. */
const val MIN_PASSWORD_LENGTH = io.wyn.wyn.feature.auth.AuthRules.MIN_SIGNUP_PASSWORD_LENGTH

enum class PasswordFormError { Missing, TooShort, Mismatch, Same }

/** web validatePasswordChange(): checked before any network call. */
fun validatePasswordChange(current: String, next: String, confirmation: String): PasswordFormError? = when {
    current.isEmpty() || next.isEmpty() || confirmation.isEmpty() -> PasswordFormError.Missing
    next.length < MIN_PASSWORD_LENGTH -> PasswordFormError.TooShort
    next != confirmation -> PasswordFormError.Mismatch
    current == next -> PasswordFormError.Same
    else -> null
}

/** Settings reads and writes, mirroring web/lib/phase3-data.ts and settings-route.tsx. */
interface SettingsRepository {
    suspend fun privacy(userId: String): PrivacySettings
    suspend fun setPrivacy(userId: String, field: PrivacyField, value: Any)
    suspend fun showOnline(userId: String): Boolean
    suspend fun setShowOnline(userId: String, value: Boolean)
    suspend fun blocked(userId: String): List<Person>
    suspend fun unblock(profileId: String)
    suspend fun muted(userId: String): List<Person>
    suspend fun unmute(userId: String, profileId: String)
    /** export_my_data as pretty JSON. */
    suspend fun exportData(): String
    suspend fun deleteAccount()
    suspend fun legal(type: String): LegalDocument?
    /** null: the account never chose; throws when it cannot be read. */
    suspend fun theme(userId: String): ThemePreference?
    suspend fun saveTheme(userId: String, value: ThemePreference)
    suspend fun language(userId: String): AppLanguage?
    suspend fun saveLanguage(userId: String, value: AppLanguage)
    /** web changeAccountPassword(): proves the current password without touching this device's session. */
    suspend fun changePassword(userId: String, current: String, next: String)
}

private const val PERSON_COLUMNS = "id,username,display_name,avatar_url,is_verified,is_private"
private val prettyJson = Json { prettyPrint = true }

class SupabaseSettingsRepository(private val clientOrNull: SupabaseClient?) : SettingsRepository {
    private val client: SupabaseClient get() = clientOrNull ?: throw NotConfiguredException()

    override suspend fun privacy(userId: String): PrivacySettings {
        val row = client.from("profiles").select(Columns.list("is_private", "dm_permission", "mention_permission", "comment_permission", "likes_visibility")) {
            filter { eq("id", userId) }
        }.decodeList<JsonObject>().firstOrNull() ?: return PrivacySettings()
        return PrivacySettings(
            isPrivate = row.bool("is_private"),
            dmPermission = row.text("dm_permission") ?: "everyone",
            mentionPermission = row.text("mention_permission") ?: "everyone",
            commentPermission = row.text("comment_permission") ?: "everyone",
            likesVisibility = row.text("likes_visibility") ?: "everyone",
        )
    }

    override suspend fun setPrivacy(userId: String, field: PrivacyField, value: Any) {
        val body = buildJsonObject {
            when (field) {
                PrivacyField.IsPrivate -> put(field.column, value as Boolean)
                PrivacyField.Likes -> put(field.column, (value as String).also { require(it in LIKES_CHOICES) })
                else -> put(field.column, (value as String).also { require(it in INTERACTION_CHOICES) })
            }
        }
        client.from("profiles").update(body) { filter { eq("id", userId) } }
    }

    override suspend fun showOnline(userId: String): Boolean =
        client.from("user_presence").select(Columns.list("show_online_status")) { filter { eq("user_id", userId) } }
            .decodeList<JsonObject>().firstOrNull()
            // web: a missing row or value counts as shown; only an explicit false hides it.
            ?.let { (it["show_online_status"] as? JsonPrimitive)?.booleanOrNull != false } ?: true

    override suspend fun setShowOnline(userId: String, value: Boolean) {
        client.from("user_presence").upsert(
            buildJsonObject { put("user_id", userId); put("show_online_status", value); put("updated_at", Instant.now().toString()) },
        )
    }

    private fun person(row: JsonObject) = Person(
        id = row.text("id").orEmpty(),
        username = row.text("username").orEmpty(),
        displayName = row.text("display_name"),
        avatarUrl = row.text("avatar_url"),
        isVerified = row.bool("is_verified"),
        isPrivate = row.bool("is_private"),
        following = false,
        requested = false,
    )

    override suspend fun blocked(userId: String): List<Person> =
        client.from("blocks").select(Columns.raw("created_at,blocked:profiles!blocks_blocked_id_fkey($PERSON_COLUMNS)")) {
            filter { eq("blocker_id", userId) }
            order("created_at", Order.DESCENDING)
            range(0L, 29L)
        }.decodeList<JsonObject>().map { person(relation(it["blocked"])) }.filter { it.id.isNotEmpty() }

    override suspend fun unblock(profileId: String) {
        client.postgrest.rpc("unblock_user", buildJsonObject { put("p_target_user_id", profileId) })
    }

    override suspend fun muted(userId: String): List<Person> =
        client.from("mutes").select(Columns.raw("created_at,muted:profiles!mutes_muted_id_fkey($PERSON_COLUMNS)")) {
            filter { eq("muter_id", userId) }
            order("created_at", Order.DESCENDING)
            range(0L, 29L)
        }.decodeList<JsonObject>().map { person(relation(it["muted"])) }.filter { it.id.isNotEmpty() }

    override suspend fun unmute(userId: String, profileId: String) {
        client.from("mutes").delete { filter { eq("muter_id", userId); eq("muted_id", profileId) } }
    }

    override suspend fun exportData(): String =
        prettyJson.encodeToString(JsonElement.serializer(), client.postgrest.rpc("export_my_data").decodeAs<JsonElement>())

    override suspend fun deleteAccount() {
        client.postgrest.rpc("delete_my_account")
    }

    override suspend fun legal(type: String): LegalDocument? {
        require(type in LEGAL_TYPES)
        val row = client.from("platform_documents").select(Columns.list("type", "version", "title", "content", "effective_at")) {
            filter { eq("type", type) }
            order("version", Order.DESCENDING)
            limit(1)
        }.decodeList<JsonObject>().firstOrNull() ?: return null
        return LegalDocument(
            type = row.text("type") ?: type,
            version = row["version"]?.let { (it as? JsonPrimitive)?.content }.orEmpty(),
            title = row.text("title").orEmpty(),
            content = row.text("content").orEmpty(),
        )
    }

    private suspend fun preference(userId: String, column: String): String? =
        client.from("user_preferences").select(Columns.list(column)) { filter { eq("user_id", userId) } }
            .decodeList<JsonObject>().firstOrNull()?.text(column)

    override suspend fun theme(userId: String): ThemePreference? = ThemePreference.of(preference(userId, "theme_preference"))

    override suspend fun saveTheme(userId: String, value: ThemePreference) {
        client.from("user_preferences").upsert(buildJsonObject { put("user_id", userId); put("theme_preference", value.wire) }) { onConflict = "user_id" }
    }

    override suspend fun language(userId: String): AppLanguage? = AppLanguage.of(preference(userId, "language_preference"))

    override suspend fun saveLanguage(userId: String, value: AppLanguage) {
        client.from("user_preferences").upsert(buildJsonObject { put("user_id", userId); put("language_preference", value.wire) }) { onConflict = "user_id" }
    }

    override suspend fun changePassword(userId: String, current: String, next: String) {
        require(current.isNotEmpty() && next.length >= MIN_PASSWORD_LENGTH && current != next)
        val auth = client.auth
        val original = runCatching { auth.retrieveUserForCurrentSession(updateSession = true) }.getOrNull()
        if (original == null || original.id != userId) throw PasswordChangeException(PasswordChangeException.Reason.AccountChanged)
        val email = original.email ?: throw PasswordChangeException(PasswordChangeException.Reason.NoEmail)

        // Verify on a separate client that never stores or refreshes its session,
        // so the signed-in account on this phone cannot be replaced.
        val verifier = createSupabaseClient(BuildConfig.SUPABASE_URL, BuildConfig.SUPABASE_PUBLISHABLE_KEY) {
            install(Auth) {
                autoLoadFromStorage = false
                autoSaveToStorage = false
                alwaysAutoRefresh = false
                enableLifecycleCallbacks = false
            }
        }
        try {
            val verified = runCatching {
                verifier.auth.signInWith(Email) { this.email = email; password = current }
                verifier.auth.currentUserOrNull()?.id
            }.getOrNull()
            if (verified != userId) throw PasswordChangeException(PasswordChangeException.Reason.WrongPassword)
        } finally {
            runCatching { verifier.auth.signOut(SignOutScope.LOCAL) }
            runCatching { verifier.close() }
        }

        // The person may have switched accounts while the check ran.
        val still = runCatching { auth.retrieveUserForCurrentSession(updateSession = true) }.getOrNull()
        if (still == null || still.id != userId || still.email != email) throw PasswordChangeException(PasswordChangeException.Reason.AccountChanged)

        try {
            auth.updateUser { password = next }
        } catch (e: Exception) {
            val message = e.message.orEmpty()
            if ("reauthentication_needed" in message || "reauthentication_required" in message) {
                throw PasswordChangeException(PasswordChangeException.Reason.ReauthenticationRequired)
            }
            throw PasswordChangeException(PasswordChangeException.Reason.UpdateFailed)
        }
    }
}
