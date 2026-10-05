package io.wyn.wyn.core.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.RealtimeChannel
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.channelFlow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.util.UUID

/**
 * Live chat updates over Supabase Realtime, as on the web: new messages
 * (web subscribeConversationMessages / subscribeMyMessages) and who is online
 * (web presence.ts). Every flow only runs while it is collected; the regular
 * checks stay as a fallback when the connection drops.
 */
interface ChatLive {
    /** Emits when a message in this conversation is added, changed or deleted. */
    fun conversationChanges(conversationId: String): Flow<Unit>

    /** Emits on every new message this account can see (RLS scopes it), to refresh the inbox. */
    fun newMessages(userId: String): Flow<Unit>

    /** People online now, while [presence] runs. */
    val onlineIds: StateFlow<Set<String>>

    /**
     * Joins the shared online channel until cancelled. This account is shown
     * as online only when [visible] (its "show online status" setting).
     */
    suspend fun presence(userId: String, visible: Boolean)
}

/** No live updates (no configuration, and tests): the regular checks do the work. */
object NoChatLive : ChatLive {
    override fun conversationChanges(conversationId: String): Flow<Unit> = emptyFlow()
    override fun newMessages(userId: String): Flow<Unit> = emptyFlow()
    override val onlineIds: StateFlow<Set<String>> = MutableStateFlow(emptySet())
    override suspend fun presence(userId: String, visible: Boolean) = awaitCancellation()
}

/** web presence.ts PRESENCE_CHANNEL: the same channel, so web and Android see each other. */
const val PRESENCE_CHANNEL = "wynos:online-presence"

/**
 * Presence refs per user id after a join/leave diff. A person stays online
 * while any of their sessions (web tab, phone) is still there.
 */
fun applyPresenceDiff(current: Map<String, Set<String>>, joins: Map<String, String>, leaves: Map<String, String>): Map<String, Set<String>> {
    val next = current.toMutableMap()
    joins.forEach { (id, ref) -> next[id] = next[id].orEmpty() + ref }
    leaves.forEach { (id, ref) ->
        val left = next[id].orEmpty() - ref
        if (left.isEmpty()) next.remove(id) else next[id] = left
    }
    return next
}

class SupabaseChatLive(private val client: SupabaseClient?) : ChatLive {
    private val online = MutableStateFlow<Set<String>>(emptySet())
    override val onlineIds: StateFlow<Set<String>> = online.asStateFlow()

    override fun conversationChanges(conversationId: String): Flow<Unit> =
        live("android-conversation-$conversationId") { channel ->
            channel.postgresChangeFlow<PostgresAction>(schema = "public") {
                table = "messages"
                filter("conversation_id", FilterOperator.EQ, conversationId)
            }
        }

    override fun newMessages(userId: String): Flow<Unit> =
        live("android-chat-inbox-$userId") { channel ->
            channel.postgresChangeFlow<PostgresAction.Insert>(schema = "public") { table = "messages" }
        }

    /** One channel per collection; the changes are registered before joining, as Realtime requires. */
    private fun live(name: String, listen: (RealtimeChannel) -> Flow<*>): Flow<Unit> {
        val client = client ?: return emptyFlow()
        return channelFlow {
            val channel = client.channel("$name-${UUID.randomUUID()}")
            val changes = listen(channel)
            val forward = launch { changes.collect { send(Unit) } }
            try {
                channel.subscribe()
                awaitCancellation()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // No connection: the regular checks keep the screen up to date.
            } finally {
                forward.cancel()
                withContext(NonCancellable) { runCatching { client.realtime.removeChannel(channel) } }
            }
        }
    }

    override suspend fun presence(userId: String, visible: Boolean) {
        val client = client ?: return awaitCancellation()
        val channel = client.channel(PRESENCE_CHANNEL) { presence { key = userId } }
        var refs = emptyMap<String, Set<String>>()
        coroutineScope {
            val watch = launch {
                channel.presenceChangeFlow().collect { action ->
                    refs = applyPresenceDiff(
                        refs,
                        joins = action.joins.mapValues { it.value.presenceRef },
                        leaves = action.leaves.mapValues { it.value.presenceRef },
                    )
                    online.value = refs.keys
                }
            }
            try {
                channel.subscribe(blockUntilSubscribed = true)
                if (visible) channel.track(buildJsonObject { put("user_id", userId) })
                awaitCancellation()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // No connection: nobody is shown online until the app comes back.
            } finally {
                watch.cancel()
                withContext(NonCancellable) {
                    if (visible) runCatching { channel.untrack() }
                    runCatching { client.realtime.removeChannel(channel) }
                    online.value = emptySet()
                }
            }
        }
    }
}
