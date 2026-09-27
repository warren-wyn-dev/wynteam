package io.wyn.wyn.core.data

import android.content.Context
import androidx.core.content.edit
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/**
 * Accounts signed in on this phone, for the account switcher (the web's
 * account-registry). Each inactive account keeps its own saved session in
 * app-private storage (never backed up: allowBackup="false"); the active
 * account's session lives in Supabase's own session store.
 */
@Serializable
data class SavedAccount(
    val userId: String,
    val username: String? = null,
    val displayName: String? = null,
    val avatarUrl: String? = null,
    /** Null for the active account; set while the account is switched away from. */
    val session: String? = null,
)

interface AccountStore {
    fun all(): List<SavedAccount>
    fun save(accounts: List<SavedAccount>)
}

class PreferencesAccountStore(context: Context) : AccountStore {
    private val prefs = context.getSharedPreferences("wynos_accounts", Context.MODE_PRIVATE)
    private val serializer = ListSerializer(SavedAccount.serializer())
    private val json = Json { ignoreUnknownKeys = true }

    override fun all(): List<SavedAccount> {
        val raw = prefs.getString(KEY, null) ?: return emptyList()
        return runCatching { json.decodeFromString(serializer, raw) }.getOrDefault(emptyList())
    }

    override fun save(accounts: List<SavedAccount>) {
        prefs.edit { putString(KEY, json.encodeToString(serializer, accounts)) }
    }

    private companion object {
        const val KEY = "accounts.v1"
    }
}

class MemoryAccountStore(private var accounts: List<SavedAccount> = emptyList()) : AccountStore {
    override fun all() = accounts
    override fun save(accounts: List<SavedAccount>) {
        this.accounts = accounts
    }
}
