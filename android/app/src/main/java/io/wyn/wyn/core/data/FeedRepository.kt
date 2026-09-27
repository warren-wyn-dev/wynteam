package io.wyn.wyn.core.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlin.coroutines.cancellation.CancellationException

/** Home feed reads and post actions, mirroring web/lib/home-feed-sources.ts and web/lib/home-actions.ts. */
interface FeedRepository {
    suspend fun fetchRanked(): List<FeedRow>
    suspend fun fetchFollowing(userId: String): List<FeedRow>
    suspend fun fetchImages(rows: List<FeedRow>): Map<String, List<String>>
    suspend fun loadViewer(userId: String, rows: List<FeedRow>): ViewerState
    suspend fun fetchIdentity(userId: String): HomeIdentity?

    suspend fun setLiked(userId: String, dropId: String, liked: Boolean)
    suspend fun setSaved(userId: String, dropId: String, saved: Boolean)
    suspend fun setRedropped(userId: String, dropId: String, redropped: Boolean)
    suspend fun deleteRedrop(userId: String, redropId: String)
    suspend fun toggleFollow(userId: String, authorId: String, following: Boolean, requested: Boolean, isPrivate: Boolean): FollowState
    suspend fun hide(userId: String, dropId: String)
    suspend fun unhide(userId: String, dropId: String)
    suspend fun report(dropId: String, category: String, detail: String?)
}

private const val RANKED_LIMIT = 200
private const val FOLLOWING_LIMIT = 200
private const val IMPRESSION_LIMIT = 10
private val FEED_SOURCES = listOf("following", "recommended", "trending", "latest", "club", "new_creator", "exploration")

class SupabaseFeedRepository(
    private val clientOrNull: SupabaseClient?,
    private val quotes: QuoteRepository = SupabaseQuoteRepository(clientOrNull),
) : FeedRepository {
    private val client: SupabaseClient get() = clientOrNull ?: throw NotConfiguredException()

    override suspend fun fetchRanked(): List<FeedRow> {
        val started = System.currentTimeMillis()
        val raw = client.postgrest.rpc("get_wynos_ranked_feed").decodeAs<JsonElement>()
        val rows = FeedRow.parseList(raw, RANKED_LIMIT)
        recordImpressions(raw, System.currentTimeMillis() - started)
        return hydrateAspectRatios(rows)
    }

    /**
     * The ranked feed down-ranks what was recently shown only once the client
     * records the first window (as the web and Flutter do). Best effort.
     */
    private suspend fun recordImpressions(raw: JsonElement, latencyMs: Long) {
        val items = buildJsonArray {
            var rank = 0
            for (candidate in (raw as? JsonArray).orEmpty()) {
                val obj = candidate as? JsonObject ?: continue
                val row = (obj["row_data"] as? JsonObject) ?: obj
                val id = row.text("id")
                if (row.text("content_type") != "drop" || id == null) continue
                rank += 1
                add(
                    buildJsonObject {
                        put("contentId", id)
                        put("renderKey", "$id:${row.text("redrop_id").orEmpty()}")
                        put("feedSource", impressionSource(row))
                        put("rankPosition", rank)
                        put("contentType", "drop")
                        put("topic", row.text("feed_topic"))
                        put("candidateOrigin", row.text("feed_candidate_origin") ?: "direct")
                        putJsonArray("experiments") {}
                    },
                )
                if (rank >= IMPRESSION_LIMIT) break
            }
        }
        if (items.isEmpty()) return
        try {
            client.postgrest.rpc(
                "record_feed_impressions",
                buildJsonObject {
                    put("p_session_key", "android-home-v1-${System.currentTimeMillis()}-${(0..Int.MAX_VALUE).random().toString(36)}")
                    put("p_latency_ms", latencyMs.coerceAtLeast(0))
                    put("p_items", items)
                },
            )
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            // Telemetry must never block a valid feed.
        }
    }

    private fun impressionSource(row: JsonObject): String {
        val scores = row["feed_source_scores"] as? JsonObject ?: return "recommended"
        var selected = "recommended"
        var best = Double.NEGATIVE_INFINITY
        for (source in FEED_SOURCES) {
            val score = (scores[source] as? JsonPrimitive)?.content?.toDoubleOrNull() ?: continue
            if (score > best) {
                selected = source
                best = score
            }
        }
        return selected
    }

    /** home_feed has no image_aspect_ratio; read it from drops like the web does (4:5 when missing). */
    private suspend fun hydrateAspectRatios(rows: List<FeedRow>): List<FeedRow> {
        val ids = rows.filter { it.imageUrl != null }.map { it.id }.distinct()
        if (ids.isEmpty()) return rows
        val ratios = runCatching {
            client.from("drops").select(Columns.list("id", "image_aspect_ratio")) { filter { isIn("id", ids) } }
                .decodeList<JsonObject>().associate { it.text("id").orEmpty() to it.text("image_aspect_ratio") }
        }.getOrElse { if (it is CancellationException) throw it else return rows }
        return rows.map { row -> if (ratios.containsKey(row.id)) row.copy(imageAspectRatio = ratios[row.id]) else row }
    }

    override suspend fun fetchFollowing(userId: String): List<FeedRow> {
        val followingIds = client.from("follows").select(Columns.list("following_id")) { filter { eq("follower_id", userId) } }
            .decodeList<JsonObject>().mapNotNull { it.text("following_id") }
        if (followingIds.isEmpty()) return emptyList()
        // Original Drops from followed authors, and reposts BY followed people (never strangers reposting them).
        val raw = client.from("home_feed").select {
            filter {
                or {
                    and {
                        isIn("author_id", followingIds)
                        exact("redrop_id", null)
                    }
                    isIn("redropper_id", followingIds)
                }
                neq("content_type", "pop")
            }
            order("created_at", Order.DESCENDING)
            range(0L, (FOLLOWING_LIMIT - 1).toLong())
        }.decodeAs<JsonElement>()
        // Quotes that followed people reposted belong on their timeline too, at the time of the repost.
        val quoteShares = quotes.repostRows(followingIds, FOLLOWING_LIMIT)
        val combined = (FeedRow.parseList(raw, FOLLOWING_LIMIT) + quoteShares)
            .sortedByDescending { io.wyn.wyn.feature.home.FeedText.parseInstant(it.timelineAt) ?: java.time.Instant.EPOCH }
            .take(FOLLOWING_LIMIT)
        return hydrateAspectRatios(combined)
    }

    override suspend fun fetchImages(rows: List<FeedRow>): Map<String, List<String>> {
        val map = LinkedHashMap<String, MutableList<String>>()
        rows.forEach { row -> row.imageUrl?.let { map[row.id] = mutableListOf(it) } }
        val ids = rows.filter { it.imageCount > 1 }.map { it.id }.distinct()
        if (ids.isEmpty()) return map
        val images = runCatching {
            client.from("drop_images").select(Columns.list("drop_id", "image_url", "position")) {
                filter { isIn("drop_id", ids) }
                order("position", Order.ASCENDING)
            }.decodeList<JsonObject>()
        }.getOrElse { if (it is CancellationException) throw it else return map }
        for (image in images) {
            val id = image.text("drop_id") ?: continue
            val url = image.text("image_url")?.takeIf { it.isNotEmpty() } ?: continue
            val list = map.getOrPut(id) { mutableListOf() }
            if (url !in list) list += url
        }
        return map
    }

    override suspend fun loadViewer(userId: String, rows: List<FeedRow>): ViewerState {
        val dropIds = rows.map { it.id }.distinct()
        val authorIds = rows.map { it.authorId }.filter { it.isNotEmpty() }.distinct()
        if (dropIds.isEmpty()) return ViewerState()
        fun List<JsonObject>.ids(key: String) = mapNotNull { it.text(key) }.toSet()
        val liked = client.from("drop_likes").select(Columns.list("drop_id")) {
            filter { eq("user_id", userId); isIn("drop_id", dropIds) }
        }.decodeList<JsonObject>().ids("drop_id")
        val saved = client.from("saves").select(Columns.list("content_id")) {
            filter { eq("user_id", userId); eq("content_type", "drop"); isIn("content_id", dropIds) }
        }.decodeList<JsonObject>().ids("content_id")
        val redropped = client.from("redrops").select(Columns.list("drop_id")) {
            filter { eq("redropper_id", userId); exact("quote_text", null); isIn("drop_id", dropIds) }
        }.decodeList<JsonObject>().ids("drop_id")
        val following = client.from("follows").select(Columns.list("following_id")) {
            filter { eq("follower_id", userId); isIn("following_id", authorIds) }
        }.decodeList<JsonObject>().ids("following_id")
        val requested = client.from("follow_requests").select(Columns.list("target_id")) {
            filter { eq("requester_id", userId); isIn("target_id", authorIds) }
        }.decodeList<JsonObject>().ids("target_id")
        val privateAuthors = client.from("profiles").select(Columns.list("id", "is_private")) {
            filter { isIn("id", authorIds) }
        }.decodeList<JsonObject>().filter { it.bool("is_private") }.ids("id")
        return ViewerState(liked, saved, redropped, following, requested, privateAuthors)
    }

    override suspend fun fetchIdentity(userId: String): HomeIdentity? =
        client.from("profiles").select(Columns.list("username", "display_name", "avatar_url")) { filter { eq("id", userId) } }
            .decodeList<JsonObject>().firstOrNull()
            ?.let { HomeIdentity(it.text("username"), it.text("display_name"), it.text("avatar_url")) }

    override suspend fun setLiked(userId: String, dropId: String, liked: Boolean) {
        if (liked) {
            client.from("drop_likes").upsert(buildJsonObject { put("drop_id", dropId); put("user_id", userId) }) {
                onConflict = "drop_id,user_id"
                ignoreDuplicates = true
            }
        } else {
            client.from("drop_likes").delete { filter { eq("drop_id", dropId); eq("user_id", userId) } }
        }
    }

    override suspend fun setSaved(userId: String, dropId: String, saved: Boolean) {
        if (saved) {
            client.from("saves").upsert(
                buildJsonObject { put("user_id", userId); put("content_type", "drop"); put("content_id", dropId) },
            ) {
                onConflict = "user_id,content_type,content_id"
                ignoreDuplicates = true
            }
        } else {
            client.from("saves").delete { filter { eq("user_id", userId); eq("content_type", "drop"); eq("content_id", dropId) } }
        }
    }

    override suspend fun setRedropped(userId: String, dropId: String, redropped: Boolean) {
        if (redropped) {
            client.from("redrops").insert(buildJsonObject { put("drop_id", dropId); put("redropper_id", userId) })
        } else {
            client.from("redrops").delete { filter { eq("drop_id", dropId); eq("redropper_id", userId); exact("quote_text", null) } }
        }
    }

    override suspend fun deleteRedrop(userId: String, redropId: String) {
        client.from("redrops").delete { filter { eq("id", redropId); eq("redropper_id", userId) } }
    }

    /** web toggleAuthorFollow(): re-reads the real row first so a stale screen never double-toggles. */
    override suspend fun toggleFollow(userId: String, authorId: String, following: Boolean, requested: Boolean, isPrivate: Boolean): FollowState {
        if (authorId == userId) return FollowState.None
        val actuallyFollowing = client.from("follows").select(Columns.list("following_id")) {
            filter { eq("follower_id", userId); eq("following_id", authorId) }
        }.decodeList<JsonObject>().isNotEmpty()
        if (actuallyFollowing != following) return if (actuallyFollowing) FollowState.Following else FollowState.None
        if (actuallyFollowing) {
            client.from("follows").delete { filter { eq("follower_id", userId); eq("following_id", authorId) } }
            return FollowState.None
        }
        if (isPrivate) {
            val pending = client.from("follow_requests").select(Columns.list("target_id")) {
                filter { eq("requester_id", userId); eq("target_id", authorId) }
            }.decodeList<JsonObject>().isNotEmpty()
            if (pending != requested) return if (pending) FollowState.Requested else FollowState.None
            if (pending) {
                client.from("follow_requests").delete { filter { eq("requester_id", userId); eq("target_id", authorId) } }
                return FollowState.None
            }
            client.from("follow_requests").upsert(buildJsonObject { put("requester_id", userId); put("target_id", authorId) }) {
                onConflict = "requester_id,target_id"
                ignoreDuplicates = true
            }
            return FollowState.Requested
        }
        client.from("follows").upsert(buildJsonObject { put("follower_id", userId); put("following_id", authorId) }) {
            onConflict = "follower_id,following_id"
            ignoreDuplicates = true
        }
        return FollowState.Following
    }

    override suspend fun hide(userId: String, dropId: String) {
        client.from("feed_signals").insert(
            buildJsonObject {
                put("user_id", userId); put("signal_type", "hide"); put("target_type", "drop"); put("target_id", dropId)
            },
        )
    }

    override suspend fun unhide(userId: String, dropId: String) {
        client.from("feed_signals").delete {
            filter { eq("user_id", userId); eq("signal_type", "hide"); eq("target_type", "drop"); eq("target_id", dropId) }
        }
    }

    override suspend fun report(dropId: String, category: String, detail: String?) {
        client.postgrest.rpc(
            "submit_report",
            buildJsonObject {
                put("p_target_type", "drop")
                put("p_target_id", dropId)
                put("p_category", category)
                put("p_detail", detail)
            },
        )
    }
}
