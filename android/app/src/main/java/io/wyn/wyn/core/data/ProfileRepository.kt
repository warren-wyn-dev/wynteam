package io.wyn.wyn.core.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import io.github.jan.supabase.storage.storage
import io.ktor.http.ContentType
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.net.URI
import java.time.Instant

/** web ProfileRow: the columns every screen shows. */
data class Profile(
    val id: String,
    val username: String,
    val displayName: String? = null,
    val bio: String? = null,
    val avatarUrl: String? = null,
    val coverUrl: String? = null,
    val website: String? = null,
    val isPrivate: Boolean = false,
    val isVerified: Boolean = false,
    /** Every other social link, kept as-is when the website changes. */
    val socialLinks: Map<String, String> = emptyMap(),
) {
    /** web profileLabel(). */
    val label: String get() = displayName?.trim()?.takeIf { it.isNotEmpty() } ?: username.ifEmpty { "WYNOS" }
}

/** web ProfileSummary. */
data class ProfileSummary(
    val profile: Profile,
    val followerCount: Int,
    val followingCount: Int,
    val following: Boolean = false,
    val requested: Boolean = false,
    val blocked: Boolean = false,
    val blockedBy: Boolean = false,
    val muted: Boolean = false,
)

/** One row of a followers/following list, with the viewer's own follow state. */
data class Person(
    val id: String,
    val username: String,
    val displayName: String?,
    val avatarUrl: String?,
    val isVerified: Boolean,
    val isPrivate: Boolean,
    val following: Boolean,
    val requested: Boolean,
) {
    val label: String get() = displayName?.trim()?.takeIf { it.isNotEmpty() } ?: username
}

enum class ProfileTab { Posts, Reposts, Likes }
enum class FollowKind { Following, Followers }
enum class ProfileImage(val column: String, val file: String) { Avatar("avatar_url", "avatar"), Cover("cover_url", "cover") }

/** web profile-post-feed.ts page sizes. */
const val PROFILE_POST_PAGE_SIZE = 21
const val PROFILE_REPOST_PAGE_SIZE = 10
const val AVATAR_MAX_BYTES = 10 * 1024 * 1024

/** A message the profile screens show as-is (username taken). */
class ProfileRuleException(val reason: Reason) : Exception() {
    enum class Reason { UsernameTaken }
}

/** Profile, mirroring web/lib/phase3-data.ts, profile-post-feed.ts and profile-follow-list-route.tsx. */
interface ProfileRepository {
    suspend fun summary(viewerId: String, profileId: String): ProfileSummary?
    suspend fun profileIdForUsername(username: String): String?
    suspend fun rows(profileId: String, tab: ProfileTab, page: Int): List<FeedRow>
    suspend fun canViewLikes(profileId: String): Boolean
    suspend fun people(viewerId: String, profileId: String, kind: FollowKind): List<Person>
    suspend fun suggestions(viewerId: String, viewedId: String): List<Person>
    /** These profiles in this order, with my follow state for each. */
    suspend fun peopleByIds(viewerId: String, ids: List<String>): List<Person>
    suspend fun dismissSuggestion(viewerId: String, profileId: String)
    suspend fun setMuted(viewerId: String, profileId: String, muted: Boolean)
    suspend fun setBlocked(profileId: String, blocked: Boolean)
    suspend fun report(profileId: String, category: String, detail: String?)
    suspend fun updateBasics(userId: String, displayName: String, bio: String, socialLinks: Map<String, String>)
    suspend fun updateUsername(userId: String, username: String)
    suspend fun uploadImage(userId: String, kind: ProfileImage, bytes: ByteArray, contentType: String, extension: String): String
    suspend fun removeImage(userId: String, kind: ProfileImage)
}

private const val PROFILE_COLUMNS = "id,username,display_name,bio,avatar_url,cover_url,social_links,is_private,is_verified"
private const val FOLLOW_LIST_LIMIT = 200L

class SupabaseProfileRepository(
    private val clientOrNull: SupabaseClient?,
    private val quotes: QuoteRepository = SupabaseQuoteRepository(clientOrNull),
) : ProfileRepository {
    private val client: SupabaseClient get() = clientOrNull ?: throw NotConfiguredException()

    private suspend fun profile(column: String, value: String): Profile? =
        client.from("profiles").select(Columns.raw(PROFILE_COLUMNS)) { filter { eq(column, value) } }
            .decodeList<JsonObject>().firstOrNull()?.let(::parseProfile)

    private suspend fun count(rpc: String, userId: String): Int =
        client.postgrest.rpc(rpc, buildJsonObject { put("p_user_id", userId) }).decodeAs<JsonElement>()
            .let { (it as? JsonPrimitive)?.content?.toIntOrNull() ?: 0 }

    private suspend fun exists(table: String, column: String, filters: Map<String, String>): Boolean =
        client.from(table).select(Columns.list(column)) { filter { filters.forEach { (k, v) -> eq(k, v) } } }
            .decodeList<JsonObject>().isNotEmpty()

    override suspend fun summary(viewerId: String, profileId: String): ProfileSummary? = coroutineScope {
        val profile = profile("id", profileId) ?: return@coroutineScope null
        val followers = async { count("follower_count", profileId) }
        val following = async { count("following_count", profileId) }
        if (viewerId == profileId) return@coroutineScope ProfileSummary(profile, followers.await(), following.await())
        val followRow = async { exists("follows", "following_id", mapOf("follower_id" to viewerId, "following_id" to profileId)) }
        val requestRow = async { exists("follow_requests", "target_id", mapOf("requester_id" to viewerId, "target_id" to profileId)) }
        val relationship = async {
            client.postgrest.rpc("block_relationship", buildJsonObject { put("p_other_user_id", profileId) })
                .decodeAs<JsonElement>().let { (it as? JsonPrimitive)?.takeIf { p -> p !is JsonNull }?.content ?: "none" }
        }
        val muteRow = async { exists("mutes", "muted_id", mapOf("muter_id" to viewerId, "muted_id" to profileId)) }
        val wire = relationship.await()
        ProfileSummary(
            profile = profile,
            followerCount = followers.await(),
            followingCount = following.await(),
            following = followRow.await(),
            requested = requestRow.await(),
            blocked = wire == "blocked" || wire == "both",
            blockedBy = wire == "blocked_by" || wire == "both",
            muted = muteRow.await(),
        )
    }

    override suspend fun profileIdForUsername(username: String): String? = profile("username", username.trim().lowercase())?.id

    override suspend fun rows(profileId: String, tab: ProfileTab, page: Int): List<FeedRow> = when (tab) {
        ProfileTab.Posts -> postTimeline(profileId, page)
        ProfileTab.Reposts -> standardReposts(profileId, page)
        ProfileTab.Likes -> likedContent(profileId, page)
    }

    /** Authored Drops and authored Quotes; fetched in full up to this page, then merged, so no source loses entries. */
    private suspend fun postTimeline(profileId: String, page: Int): List<FeedRow> = coroutineScope {
        val limit = (page.coerceAtLeast(0) + 1) * PROFILE_POST_PAGE_SIZE
        val posts = async {
            client.from("drops").select(Columns.raw(DROP_SELECT)) {
                filter { eq("author_id", profileId); exact("deleted_at", null) }
                order("created_at", Order.DESCENDING)
                range(0L, (limit - 1).toLong())
            }.decodeList<JsonObject>().map(::parseDropCard)
        }
        val authoredQuotes = async {
            FeedRow.parseList(
                client.from("home_feed").select {
                    filter {
                        eq("redropper_id", profileId)
                        filterNot("quote_text", FilterOperator.IS, "null")
                        eq("content_type", "drop")
                    }
                    order("created_at", Order.DESCENDING)
                    range(0L, (limit - 1).toLong())
                }.decodeAs<JsonElement>(),
                limit,
            ).filter { it.isQuote }
        }
        mergePostsAndQuotes(posts.await(), authoredQuotes.await(), page)
    }

    /** Only unannotated reposts belong here (web fetchProfileStandardReposts). */
    private suspend fun standardReposts(profileId: String, page: Int): List<FeedRow> = coroutineScope {
        val limit = (page.coerceAtLeast(0) + 1) * PROFILE_REPOST_PAGE_SIZE
        val originals = async {
            FeedRow.parseList(
                client.from("home_feed").select {
                    filter { eq("redropper_id", profileId); exact("quote_text", null); eq("content_type", "drop") }
                    order("created_at", Order.DESCENDING)
                    range(0L, (limit - 1).toLong())
                }.decodeAs<JsonElement>(),
                limit,
            )
        }
        val quoteShares = async { quotes.repostRows(listOf(profileId), limit) }
        (originals.await() + quoteShares.await())
            .sortedByDescending { instant(it.timelineAt) }
            .drop(page * PROFILE_REPOST_PAGE_SIZE).take(PROFILE_REPOST_PAGE_SIZE)
    }

    override suspend fun canViewLikes(profileId: String): Boolean =
        client.postgrest.rpc("can_view_likes", buildJsonObject { put("p_target", profileId) }).decodeAs<JsonElement>()
            .let { (it as? JsonPrimitive)?.content == "true" }

    /** Liked Drops and liked Quotes by when they were liked; nothing unless can_view_likes allows it. */
    private suspend fun likedContent(profileId: String, page: Int): List<FeedRow> = coroutineScope {
        if (!canViewLikes(profileId)) return@coroutineScope emptyList()
        val limit = (page.coerceAtLeast(0) + 1) * PROFILE_POST_PAGE_SIZE
        val drops = async { (0..page.coerceAtLeast(0)).flatMap { likedDrops(profileId, it) } }
        val likedQuotes = async { quotes.likedRows(profileId, limit) }
        val dropRows = drops.await()
        val ids = dropRows.map { it.id }.distinct()
        val likedAt = if (ids.isEmpty()) emptyMap() else client.from("drop_likes").select(Columns.list("drop_id", "created_at")) {
            filter { eq("user_id", profileId); isIn("drop_id", ids) }
        }.decodeList<JsonObject>().associate { it.text("drop_id").orEmpty() to it.text("created_at").orEmpty() }
        (dropRows.map { it to (likedAt[it.id] ?: it.createdAt) } + likedQuotes.await())
            .sortedByDescending { instant(it.second) }
            .map { it.first }
            .drop(page * PROFILE_POST_PAGE_SIZE).take(PROFILE_POST_PAGE_SIZE)
    }

    private suspend fun likedDrops(profileId: String, page: Int): List<FeedRow> {
        val ids = client.postgrest.rpc(
            "fetch_liked_drop_ids",
            buildJsonObject { put("p_target_user_id", profileId); put("p_page", page) },
        ).decodeList<JsonObject>().mapNotNull { it.text("drop_id") }
        if (ids.isEmpty()) return emptyList()
        val byId = client.from("drops").select(Columns.raw(DROP_SELECT)) {
            filter { isIn("id", ids); exact("deleted_at", null) }
        }.decodeList<JsonObject>().map(::parseDropCard).associateBy { it.id }
        return ids.mapNotNull { byId[it] }
    }

    override suspend fun people(viewerId: String, profileId: String, kind: FollowKind): List<Person> = coroutineScope {
        val (match, pick) = if (kind == FollowKind.Followers) "following_id" to "follower_id" else "follower_id" to "following_id"
        val ids = client.from("follows").select(Columns.list(pick)) {
            filter { eq(match, profileId) }
            order("created_at", Order.DESCENDING)
            limit(FOLLOW_LIST_LIMIT)
        }.decodeList<JsonObject>().mapNotNull { it.text(pick) }
        if (ids.isEmpty()) return@coroutineScope emptyList()
        peopleFor(viewerId, ids)
    }

    override suspend fun peopleByIds(viewerId: String, ids: List<String>): List<Person> =
        if (ids.isEmpty()) emptyList() else peopleFor(viewerId, ids.distinct())

    private suspend fun peopleFor(viewerId: String, ids: List<String>): List<Person> = coroutineScope {
        val profiles = async {
            client.from("profiles").select(Columns.list("id", "username", "display_name", "avatar_url", "is_verified", "is_private")) {
                filter { isIn("id", ids) }
            }.decodeList<JsonObject>()
        }
        val followed = async {
            client.from("follows").select(Columns.list("following_id")) { filter { eq("follower_id", viewerId); isIn("following_id", ids) } }
                .decodeList<JsonObject>().mapNotNull { it.text("following_id") }.toSet()
        }
        val pending = async {
            client.from("follow_requests").select(Columns.list("target_id")) { filter { eq("requester_id", viewerId); isIn("target_id", ids) } }
                .decodeList<JsonObject>().mapNotNull { it.text("target_id") }.toSet()
        }
        val byId = profiles.await().associateBy { it.text("id").orEmpty() }
        val following = followed.await()
        val requested = pending.await()
        ids.mapNotNull { id ->
            val raw = byId[id] ?: return@mapNotNull null
            Person(
                id = id,
                username = raw.text("username").orEmpty(),
                displayName = raw.text("display_name"),
                avatarUrl = raw.text("avatar_url"),
                isVerified = raw.bool("is_verified"),
                isPrivate = raw.bool("is_private"),
                following = id in following,
                requested = id in requested,
            )
        }
    }

    override suspend fun suggestions(viewerId: String, viewedId: String): List<Person> {
        val ids = client.postgrest.rpc("suggested_users", buildJsonObject { put("p_limit", 10) })
            .decodeList<JsonObject>().mapNotNull { it.text("profile_id") }
            .filter { it != viewerId && it != viewedId }
        if (ids.isEmpty()) return emptyList()
        return peopleFor(viewerId, ids)
    }

    override suspend fun dismissSuggestion(viewerId: String, profileId: String) {
        client.from("profile_recommendation_dismissals").insert(buildJsonObject { put("user_id", viewerId); put("dismissed_profile_id", profileId) })
    }

    override suspend fun setMuted(viewerId: String, profileId: String, muted: Boolean) {
        if (muted) {
            client.from("mutes").insert(buildJsonObject { put("muter_id", viewerId); put("muted_id", profileId) })
        } else {
            client.from("mutes").delete { filter { eq("muter_id", viewerId); eq("muted_id", profileId) } }
        }
    }

    override suspend fun setBlocked(profileId: String, blocked: Boolean) {
        client.postgrest.rpc(if (blocked) "block_user" else "unblock_user", buildJsonObject { put("p_target_user_id", profileId) })
    }

    override suspend fun report(profileId: String, category: String, detail: String?) {
        client.postgrest.rpc(
            "submit_report",
            buildJsonObject { put("p_target_type", "user"); put("p_target_id", profileId); put("p_category", category); put("p_detail", detail) },
        )
    }

    override suspend fun updateBasics(userId: String, displayName: String, bio: String, socialLinks: Map<String, String>) {
        client.from("profiles").update(
            buildJsonObject {
                put("display_name", displayName.trim().ifEmpty { null })
                put("bio", bio)
                put("social_links", buildJsonObject { socialLinks.forEach { (k, v) -> put(k, v) } })
            },
        ) { filter { eq("id", userId) } }
    }

    override suspend fun updateUsername(userId: String, username: String) {
        val normalized = username.trim().lowercase()
        val owner = profile("username", normalized)?.id
        if (owner != null && owner != userId) throw ProfileRuleException(ProfileRuleException.Reason.UsernameTaken)
        client.from("profiles").update(buildJsonObject { put("username", normalized) }) { filter { eq("id", userId) } }
    }

    /** Same bucket, path and cache-busting URL as the web's uploadProfileImage. */
    override suspend fun uploadImage(userId: String, kind: ProfileImage, bytes: ByteArray, contentType: String, extension: String): String {
        require(bytes.isNotEmpty() && bytes.size <= AVATAR_MAX_BYTES)
        val path = "$userId/${kind.file}.$extension"
        val bucket = client.storage.from("avatars")
        bucket.upload(path, bytes) {
            upsert = true
            this.contentType = ContentType.parse(contentType)
        }
        val url = "${bucket.publicUrl(path)}?v=${System.currentTimeMillis()}"
        client.from("profiles").update(buildJsonObject { put(kind.column, url) }) { filter { eq("id", userId) } }
        return url
    }

    override suspend fun removeImage(userId: String, kind: ProfileImage) {
        client.from("profiles").update(buildJsonObject { put(kind.column, null as String?) }) { filter { eq("id", userId) } }
    }
}

internal fun parseProfile(row: JsonObject): Profile {
    val links = (row["social_links"] as? JsonObject).orEmpty()
        .mapNotNull { (k, v) -> (v as? JsonPrimitive)?.takeIf { it.isString }?.let { k to it.content } }.toMap()
    return Profile(
        id = row.text("id").orEmpty(),
        username = row.text("username").orEmpty(),
        displayName = row.text("display_name"),
        bio = row.text("bio"),
        avatarUrl = row.text("avatar_url"),
        coverUrl = row.text("cover_url"),
        website = links["website"],
        isPrivate = row.bool("is_private"),
        isVerified = row.bool("is_verified"),
        socialLinks = links,
    )
}

private fun instant(value: String): Long = runCatching { Instant.parse(value).toEpochMilli() }.getOrDefault(0L)

/** web mergeProfilePostsAndQuotes(): newest first, ties by id, then this page. */
fun mergePostsAndQuotes(posts: List<FeedRow>, quotes: List<FeedRow>, page: Int, pageSize: Int = PROFILE_POST_PAGE_SIZE): List<FeedRow> {
    val start = page.coerceAtLeast(0) * pageSize
    return (posts + quotes.filter { it.isQuote })
        .sortedWith(compareByDescending<FeedRow> { instant(it.createdAt) }.thenByDescending { it.redropId ?: it.id })
        .drop(start).take(pageSize)
}

/** web normalizeExternalUrl(): http(s) only, a dotted host, at most 300 characters. */
object ExternalUrl {
    fun normalize(input: String): String? {
        val trimmed = input.trim()
        if (trimmed.isEmpty()) return null
        val withScheme = if (Regex("^[a-z][a-z0-9+.-]*://", RegexOption.IGNORE_CASE).containsMatchIn(trimmed)) trimmed else "https://$trimmed"
        val uri = runCatching { URI(withScheme) }.getOrNull() ?: return null
        val scheme = uri.scheme?.lowercase()
        if (scheme != "http" && scheme != "https") return null
        val host = uri.host ?: return null
        if (!host.contains('.')) return null
        val path = uri.rawPath.orEmpty().ifEmpty { "/" }
        val normalized = buildString {
            append(scheme).append("://")
            uri.rawUserInfo?.let { append(it).append('@') }
            append(host.lowercase())
            if (uri.port != -1) append(':').append(uri.port)
            append(path)
            uri.rawQuery?.let { append('?').append(it) }
            uri.rawFragment?.let { append('#').append(it) }
        }
        return normalized.takeIf { it.length <= 300 }
    }

    /** web formatWebsiteLabel(): host and path, without a trailing slash. */
    fun label(url: String): String {
        val uri = runCatching { URI(url) }.getOrNull() ?: return url
        val host = uri.host ?: return url
        val path = uri.rawPath.orEmpty().takeIf { it != "/" }.orEmpty()
        return "$host$path".trimEnd('/')
    }
}
