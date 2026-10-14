package online.wynos.food.ui

import android.content.Context
import java.security.MessageDigest
import java.util.Locale

/**
 * Web parity: favorites on food.wynos.online are browser-local per account.
 * Keep the Android version local to this installation too; NEVER claim sync
 * across devices and NEVER expose one account's favorites to another.
 * Store public merchant IDs only. No email/password/token stored in prefs.
 */
internal fun favoriteNamespace(email: String): String {
    val normalized = email.trim().lowercase(Locale.ROOT)
    require(normalized.isNotBlank()) { "Favorites require an authenticated account" }
    val digest = MessageDigest.getInstance("SHA-256")
        .digest(normalized.toByteArray(Charsets.UTF_8))
    return digest.joinToString(separator = "") { byte -> "%02x".format(byte.toInt() and 0xff) }
}

internal fun toggleFavoriteId(ids: Set<String>, storeId: String): Set<String> {
    if (storeId.isBlank()) return ids
    return if (storeId in ids) ids - storeId else ids + storeId
}

internal class FoodLocalFavoriteStores(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        "wynos_food_favorite_stores_v1", Context.MODE_PRIVATE,
    )

    private fun scopedKey(email: String) = "stores:" + favoriteNamespace(email)

    fun get(email: String?): Set<String> {
        if (email.isNullOrBlank()) return emptySet()
        return preferences.getStringSet(scopedKey(email), emptySet())?.toSet() ?: emptySet()
    }

    fun toggle(email: String?, storeId: String): Set<String> {
        if (email.isNullOrBlank() || storeId.isBlank()) return emptySet()
        val key = scopedKey(email)
        val next = toggleFavoriteId(get(email), storeId)
        // Copy sets; SharedPreferences does not permit mutation of returned sets.
        preferences.edit().putStringSet(key, next.toSet()).apply()
        return next
    }
}
