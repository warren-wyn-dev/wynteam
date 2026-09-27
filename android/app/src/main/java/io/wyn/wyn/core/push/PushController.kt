package io.wyn.wyn.core.push

import io.wyn.wyn.core.data.PushTokenRepository
import kotlin.coroutines.cancellation.CancellationException

/** Why Push could not be turned on (web PushBlockReason, the reasons that exist on Android). */
enum class PushBlock { NotConfigured, Denied, Dismissed, NoToken, ServerFailed, Temporary }

sealed interface PushResult {
    data object Ok : PushResult
    data class Blocked(val reason: PushBlock) : PushResult
}

/** This phone's FCM token. Null when it cannot be had right now. */
interface DeviceToken {
    val configured: Boolean
    suspend fun token(): String?
    suspend fun delete()
}

/**
 * On-device memory, as the web keeps in localStorage: which accounts turned
 * Push on here ("wanted"), which turned it off in Settings ("off"), when the
 * prompt was last dismissed, and the token last registered.
 */
interface PushMemory {
    var wanted: Set<String>
    var off: Set<String>
    var promptDismissedAt: Long?
    var lastToken: String?
    /** Whether Android's permission question was already shown (to tell "never asked" from "don't ask again"). */
    var permissionAsked: Boolean
}

class InMemoryPushMemory : PushMemory {
    override var wanted: Set<String> = emptySet()
    override var off: Set<String> = emptySet()
    override var promptDismissedAt: Long? = null
    override var lastToken: String? = null
    override var permissionAsked: Boolean = false
}

const val PUSH_PROMPT_COOLDOWN_MS = 7L * 24 * 60 * 60 * 1000

/**
 * The web's push rules (lib/push-notifications.ts) for this phone:
 * - a token is registered only after the person allows it;
 * - switching account or signing out removes the old account's token first (privacy);
 * - an account that had Push on gets it back by itself (resync), unless it turned it off in Settings.
 */
class PushController(
    private val tokens: PushTokenRepository,
    private val device: DeviceToken,
    private val memory: PushMemory,
    private val permissionGranted: () -> Boolean,
) {
    val configured: Boolean get() = device.configured

    private fun setWanted(userId: String, wanted: Boolean) {
        memory.wanted = if (wanted) memory.wanted + userId else memory.wanted - userId
    }

    /** web setPushChosen: the Settings switch (and the prompt's Allow). */
    fun setChosen(userId: String, on: Boolean) {
        setWanted(userId, on)
        memory.off = if (on) memory.off - userId else memory.off + userId
    }

    fun isWanted(userId: String) = userId in memory.wanted

    /** web pushPromptKind for a phone: ask once, not again for a week after "not now", never after an answer. */
    fun shouldPrompt(userId: String, now: Long, canAskPermission: Boolean): Boolean {
        if (!configured) return false
        if (userId in memory.wanted || userId in memory.off) return false
        memory.promptDismissedAt?.let { if (now - it < PUSH_PROMPT_COOLDOWN_MS) return false }
        return permissionGranted() || canAskPermission
    }

    fun markPermissionAsked() {
        memory.permissionAsked = true
    }

    val permissionAsked: Boolean get() = memory.permissionAsked

    fun dismissPrompt(now: Long) {
        memory.promptDismissedAt = now
    }

    /** Registers this phone for [userId]. Call only after the person allowed notifications. */
    suspend fun enable(userId: String): PushResult {
        if (!configured) return PushResult.Blocked(PushBlock.NotConfigured)
        if (!permissionGranted()) return PushResult.Blocked(PushBlock.Denied)
        val token = try {
            device.token()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            null
        } ?: return PushResult.Blocked(PushBlock.NoToken)
        return try {
            tokens.register(userId, token)
            memory.lastToken = token
            setChosen(userId, true)
            PushResult.Ok
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            PushResult.Blocked(PushBlock.ServerFailed)
        }
    }

    /** The Settings switch off: false when the server may still have this phone's token. */
    suspend fun disable(userId: String): Boolean {
        val token = memory.lastToken ?: runCatching { device.token() }.getOrNull()
        if (token != null) {
            try {
                tokens.unregister(token)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                return false
            }
        }
        memory.lastToken = null
        runCatching { device.delete() }
        setChosen(userId, false)
        return true
    }

    /** web isCurrentDevicePushEnabled; null when it cannot be checked right now. */
    suspend fun enabledHere(userId: String): Boolean? {
        if (!configured || !permissionGranted()) return false
        return try {
            val token = device.token() ?: return null
            when {
                tokens.isRegistered(userId, token) -> true
                isWanted(userId) -> {
                    tokens.register(userId, token)
                    memory.lastToken = token
                    true
                }
                else -> false
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            null
        }
    }

    /** web resyncPushRegistration: after sign-in, a switch back or a new token. Never prompts; silent on failure. */
    suspend fun resync(userId: String) {
        if (!configured || !permissionGranted()) return
        try {
            val token = device.token() ?: return
            if (isWanted(userId)) {
                tokens.register(userId, token)
                memory.lastToken = token
            } else if (tokens.isRegistered(userId, token)) {
                setWanted(userId, true)
                memory.lastToken = token
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            // The next start or token refresh tries again.
        }
    }

    /** A new FCM token for the signed-in account. */
    suspend fun onNewToken(userId: String?, token: String) {
        if (userId == null || !isWanted(userId) || !permissionGranted()) return
        runCatching { tokens.register(userId, token) }.onSuccess { memory.lastToken = token }
    }

    /** web isPushOnBeforeAccountChange. */
    fun isOnBeforeAccountChange(userId: String): Boolean = permissionGranted() && isWanted(userId)

    /**
     * Before another account becomes active: this phone must stop receiving the
     * current account's notifications. False means it could not be removed, and
     * the switch must not happen.
     */
    suspend fun detachBeforeAccountChange(): Boolean {
        val token = memory.lastToken ?: return true
        return try {
            tokens.unregister(token)
            memory.lastToken = null
            true
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            false
        }
    }

    /** web keepPushOnAcrossAccountChange: Push stays on for both accounts (unless the new one chose off). */
    fun keepOnAcrossAccountChange(fromUserId: String?, toUserId: String) {
        if (fromUserId != null) setWanted(fromUserId, true)
        if (toUserId !in memory.off) setWanted(toUserId, true)
    }
}
