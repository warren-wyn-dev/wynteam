package io.wyn.wyn.core.link

import android.content.Intent

/**
 * A wynos.online link the app opens itself (Android App Links): the share links the
 * app and the web hand out. Anything else is ignored and the app just opens.
 */
sealed interface AppLink {
    data class Drop(val id: String) : AppLink
    data class Quote(val id: String) : AppLink
    data class Club(val id: String) : AppLink
    data class ClubPost(val id: String) : AppLink
    data class ClubInvite(val code: String) : AppLink

    companion object {
        private const val HOST = "wynos.online"
        private val uuid = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
        // Invite codes are 10 hex characters today; allow a little more, never separators.
        private val inviteCode = Regex("^[A-Za-z0-9_-]{1,64}$")

        /** [scheme], [host] and the decoded [segments] of a link, e.g. ["drop", "<id>"]. */
        fun parse(scheme: String?, host: String?, segments: List<String>): AppLink? {
            if (!scheme.equals("https", ignoreCase = true)) return null
            if (!host.equals(HOST, ignoreCase = true)) return null
            if (segments.size != 2) return null
            val value = segments[1]
            fun id() = value.takeIf { uuid.matches(it) }?.lowercase()
            return when (segments[0]) {
                "drop" -> id()?.let(::Drop)
                "quote" -> id()?.let(::Quote)
                "club" -> id()?.let(::Club)
                "club-post" -> id()?.let(::ClubPost)
                "club-invite" -> value.takeIf { inviteCode.matches(it) }?.let(::ClubInvite)
                else -> null
            }
        }

        fun from(intent: Intent?): AppLink? {
            if (intent?.action != Intent.ACTION_VIEW) return null
            val uri = intent.data ?: return null
            return parse(uri.scheme, uri.host, uri.pathSegments.orEmpty())
        }
    }
}
