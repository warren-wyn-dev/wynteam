package io.wyn.wyn.core.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.storage.storage
import io.ktor.http.ContentType
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlin.time.Duration.Companion.hours

/** web ClubRow, plus the rules and owner the Club page reads. Image links are signed. */
data class Club(
    val id: String,
    val name: String,
    val description: String? = null,
    val category: String? = null,
    val privacy: String? = null,
    val coverUrl: String? = null,
    val iconUrl: String? = null,
    val createdAt: String = "",
    val memberCount: Int = 0,
    val rules: String? = null,
    val ownerId: String? = null,
) {
    val isPrivate: Boolean get() = privacy == "private"
}

/** My row in club_members. */
data class ClubMembership(val role: String, val status: String) {
    val approved: Boolean get() = status == "approved"
    val pending: Boolean get() = status == "pending"
    val owner: Boolean get() = role == "owner"
    /** Owner or admin: manage the Club and see Insights. */
    val canManage: Boolean get() = approved && role in setOf("owner", "admin")
    /** Owner, admin or moderator: pin and delete others' posts and messages. */
    val canModerate: Boolean get() = approved && role in MODERATOR_ROLES
}

val MODERATOR_ROLES = setOf("owner", "admin", "moderator")

data class ClubChannel(val id: String, val name: String)

/** web ClubData. */
data class ClubDetail(val club: Club, val membership: ClubMembership?, val channels: List<ClubChannel>, val muted: Boolean)

/** web ClubHomePost. */
data class ClubPost(
    val id: String,
    val clubId: String,
    val authorId: String,
    val authorUsername: String,
    val authorDisplayName: String? = null,
    val authorAvatarUrl: String? = null,
    val content: String? = null,
    val imageUrls: List<String> = emptyList(),
    val linkUrl: String? = null,
    val pinned: Boolean = false,
    val createdAt: String = "",
    val likeCount: Int = 0,
    val commentCount: Int = 0,
    val liked: Boolean = false,
    val saved: Boolean = false,
    val myRole: String? = null,
    val pollId: String? = null,
    val pollOptions: List<String> = emptyList(),
    val pollExpiresAt: String? = null,
    val pollMyVote: Int? = null,
    /** Null while results are hidden from me. */
    val pollTotalVotes: Int? = null,
    val pollOptionCounts: List<Int>? = null,
) {
    val authorLabel: String get() = authorDisplayName?.trim()?.takeIf { it.isNotEmpty() } ?: authorUsername.ifEmpty { "WYNOS" }
}

/** The single Club post page (web ClubPostRoute). */
data class ClubPostPage(
    val id: String,
    val clubId: String?,
    val clubName: String?,
    val authorUsername: String,
    val authorDisplayName: String?,
    val authorAvatarUrl: String?,
    val content: String?,
    val imageUrls: List<String>,
    val createdAt: String,
) {
    val authorLabel: String get() = authorDisplayName?.takeIf { it.isNotEmpty() } ?: authorUsername.ifEmpty { "WYNOS" }
}

/** web MessageRow (Beta1 fields only). */
data class ClubMessage(
    val id: String,
    val authorId: String,
    val content: String?,
    val imageUrl: String?,
    val createdAt: String,
    val authorUsername: String,
    val authorDisplayName: String?,
    val authorAvatarUrl: String?,
) {
    val authorLabel: String get() = authorDisplayName?.trim()?.takeIf { it.isNotEmpty() } ?: authorUsername
}

data class ClubMember(val userId: String, val role: String, val username: String, val displayName: String?, val avatarUrl: String?) {
    val label: String get() = displayName?.trim()?.takeIf { it.isNotEmpty() } ?: username
}

data class ClubEvent(val id: String, val title: String, val description: String?, val startsAt: String, val locationType: String, val location: String)

/** web preview_club_invite_link(). */
data class ClubInvitePreview(val status: String, val clubId: String?, val clubName: String?, val clubPrivacy: String?, val iconUrl: String?)

/** Explore Clubs: popular and newest, without Clubs I am already in. */
data class ClubSections(val popular: List<Club>, val newest: List<Club>, val pending: Set<String>)

/** web fetchExplore(): popular by members, then the newest that are not already popular. */
fun exploreSections(all: List<Club>, approved: Set<String>, pending: Set<String>): ClubSections {
    val discoverable = all.distinctBy { it.id }.filterNot { it.id in approved }
    val popular = discoverable
        .sortedWith(compareByDescending<Club> { it.memberCount }.thenByDescending { it.createdAt })
        .take(10)
    val popularIds = popular.mapTo(HashSet()) { it.id }
    val newest = discoverable.filterNot { it.id in popularIds }.sortedByDescending { it.createdAt }.take(10)
    return ClubSections(popular, newest, pending)
}

const val CLUB_NAME_MAX = 50
const val CLUB_DESCRIPTION_MAX = 500
const val CLUB_CATEGORY_MAX = 50
const val CLUB_MESSAGE_MAX = 2000
const val CLUB_REPORT_DETAIL_MAX = 1000

/** Clubs, mirroring web Beta1 (phase3-data, home-parity-data, club-detail-golden). */
interface ClubRepository {
    suspend fun explore(userId: String): ClubSections
    /** web searchClubs(): names containing [query], newest first, 20 a page. */
    suspend fun search(query: String, page: Int): List<Club>
    suspend fun myClubs(userId: String): List<Club>
    suspend fun join(userId: String, club: Club)
    suspend fun leave(userId: String, clubId: String)
    /** Returns the new Club's id. */
    suspend fun create(userId: String, name: String, description: String, category: String, privacy: String, icon: PickedImage?): String
    suspend fun detail(userId: String, clubId: String): ClubDetail?
    /** One Club's posts (pinned first), or every Club I can read when [clubId] is null (Home "คลับของฉัน"). */
    suspend fun posts(userId: String, clubId: String?): List<ClubPost>
    suspend fun post(postId: String): ClubPostPage?
    suspend fun setLiked(userId: String, postId: String, liked: Boolean)
    suspend fun setSaved(userId: String, postId: String, saved: Boolean)
    suspend fun setPinned(postId: String, pinned: Boolean)
    suspend fun deletePost(postId: String)
    suspend fun vote(userId: String, pollId: String, option: Int)
    suspend fun setMuted(userId: String, clubId: String, muted: Boolean)
    suspend fun messages(channelId: String): List<ClubMessage>
    suspend fun markChannelRead(channelId: String)
    suspend fun sendMessage(userId: String, clubId: String, channelId: String, text: String?, image: PickedImage?)
    suspend fun deleteMessage(messageId: String)
    suspend fun members(clubId: String): List<ClubMember>
    suspend fun events(clubId: String): List<ClubEvent>
    /** club_insights for 30 days: the RPC's columns in order. */
    suspend fun insights(clubId: String): List<Pair<String, String>>?
    /** submit_report for "club", "club_post" or "club_channel_message". */
    suspend fun report(targetType: String, targetId: String, category: String, detail: String?)
    suspend fun previewInvite(code: String): ClubInvitePreview?
    /** Returns the joined Club's id. */
    suspend fun redeemInvite(code: String): String?
}

private const val CLUB_BUCKET = "club-media"
private const val CLUB_COLUMNS = "id,name,description,category,privacy,cover_url,icon_url,created_at"
private const val CLUB_PAGE = 20
private const val CLUB_POST_LIMIT = 100
private const val CLUB_POST_COLUMNS =
    "id,club_id,channel_id,author_id,content,image_urls,link_url,pinned,created_at," +
        "author:profiles!club_posts_author_id_fkey(username,display_name,avatar_url)," +
        "club_post_likes(count),club_post_comments(count),club_post_polls(id,options,expires_at)"

class SupabaseClubRepository(private val clientOrNull: SupabaseClient?) : ClubRepository {
    private val client: SupabaseClient get() = clientOrNull ?: throw NotConfiguredException()
    private val bucket get() = client.storage.from(CLUB_BUCKET)

    private suspend fun sign(path: String?): String? =
        path?.takeIf { it.isNotEmpty() }?.let { runCatching { bucket.createSignedUrl(it, 1.hours) }.getOrNull() }

    /** web mapClubs(): one batch of signed links and one member count call for a list. */
    private suspend fun mapClubs(rows: List<JsonObject>): List<Club> {
        if (rows.isEmpty()) return emptyList()
        val paths = rows.flatMap { listOfNotNull(it.text("cover_url"), it.text("icon_url")) }.filter { it.isNotEmpty() }.distinct()
        val signed = if (paths.isEmpty()) emptyMap() else runCatching {
            bucket.createSignedUrls(1.hours, paths).mapNotNull { entry -> entry.path?.let { path -> path to entry.signedURL } }.toMap()
        }.getOrDefault(emptyMap())
        val ids = rows.map { it.text("id").orEmpty() }
        val counts = client.postgrest.rpc("club_member_counts", buildJsonObject { put("p_club_ids", JsonArray(ids.map(::JsonPrimitive))) })
            .decodeList<JsonObject>().associate { it.text("club_id").orEmpty() to (it.int("member_count") ?: 0) }
        return rows.map { row ->
            val id = row.text("id").orEmpty()
            parseClub(row).copy(
                coverUrl = row.text("cover_url")?.let(signed::get),
                iconUrl = row.text("icon_url")?.let(signed::get),
                memberCount = counts[id] ?: 0,
            )
        }
    }

    override suspend fun search(query: String, page: Int): List<Club> = mapClubs(clubPage(page, query))

    private suspend fun clubPage(page: Int, query: String = ""): List<JsonObject> =
        client.from("clubs").select(Columns.raw(CLUB_COLUMNS)) {
            filter { ilike("name", "%${query.trim()}%") }
            order("created_at", Order.DESCENDING)
            range((page * CLUB_PAGE).toLong(), (page * CLUB_PAGE + CLUB_PAGE - 1).toLong())
        }.decodeList()

    override suspend fun explore(userId: String): ClubSections = coroutineScope {
        val pages = (0..2).map { page -> async { clubPage(page) } }
        val membership = async {
            client.from("club_members").select(Columns.list("club_id", "status")) { filter { eq("user_id", userId) } }.decodeList<JsonObject>()
        }
        val all = mapClubs(pages.awaitAll().flatten())
        val rows = membership.await()
        fun ids(status: String) = rows.filter { it.text("status") == status }.mapNotNullTo(HashSet()) { it.text("club_id") }
        exploreSections(all, ids("approved"), ids("pending"))
    }

    override suspend fun myClubs(userId: String): List<Club> {
        val ids = client.from("club_members").select(Columns.list("club_id")) {
            filter { eq("user_id", userId); eq("status", "approved") }
        }.decodeList<JsonObject>().mapNotNull { it.text("club_id") }
        if (ids.isEmpty()) return emptyList()
        val byId = client.from("clubs").select(Columns.raw(CLUB_COLUMNS)) { filter { isIn("id", ids) } }
            .decodeList<JsonObject>().associateBy { it.text("id") }
        return mapClubs(ids.mapNotNull { byId[it] })
    }

    override suspend fun join(userId: String, club: Club) {
        client.from("club_members").insert(
            buildJsonObject {
                put("club_id", club.id)
                put("user_id", userId)
                put("role", "member")
                put("status", if (club.isPrivate) "pending" else "approved")
            },
        )
    }

    override suspend fun leave(userId: String, clubId: String) {
        client.from("club_members").delete { filter { eq("club_id", clubId); eq("user_id", userId) } }
    }

    override suspend fun create(userId: String, name: String, description: String, category: String, privacy: String, icon: PickedImage?): String {
        require(name.isNotBlank() && privacy in setOf("public", "private"))
        val id = client.from("clubs").insert(
            buildJsonObject {
                put("name", name.trim().take(CLUB_NAME_MAX))
                put("description", description.trim().take(CLUB_DESCRIPTION_MAX).ifEmpty { null })
                put("category", category.trim().take(CLUB_CATEGORY_MAX).ifEmpty { null })
                put("privacy", privacy)
                put("owner_id", userId)
            },
        ) { select(Columns.list("id")) }.decodeSingle<JsonObject>().text("id") ?: error("no club id")
        if (icon != null) {
            require(icon.bytes.size <= IMAGE_MAX_BYTES)
            val path = "$id/icon.${icon.extension}"
            bucket.upload(path, icon.bytes) {
                upsert = true
                contentType = ContentType.parse(icon.contentType)
            }
            client.from("clubs").update(buildJsonObject { put("icon_url", path) }) { filter { eq("id", id) } }
        }
        return id
    }

    override suspend fun detail(userId: String, clubId: String): ClubDetail? = coroutineScope {
        val base = async {
            client.from("clubs").select(Columns.raw("$CLUB_COLUMNS,rules,owner_id")) { filter { eq("id", clubId) } }.decodeList<JsonObject>().firstOrNull()
        }
        val member = async {
            client.from("club_members").select(Columns.list("role", "status")) {
                filter { eq("club_id", clubId); eq("user_id", userId) }
            }.decodeList<JsonObject>().firstOrNull()
        }
        val channels = async {
            client.from("club_channels").select(Columns.list("id", "name", "created_at")) {
                filter { eq("club_id", clubId) }
                order("created_at", Order.ASCENDING)
            }.decodeList<JsonObject>()
        }
        val mute = async {
            runCatching {
                client.from("club_notification_mutes").select(Columns.list("club_id")) {
                    filter { eq("club_id", clubId); eq("user_id", userId) }
                }.decodeList<JsonObject>().isNotEmpty()
            }.getOrDefault(false)
        }
        val row = base.await() ?: return@coroutineScope null
        // web mapClub(): club_member_count shows a public Club's size to anyone.
        val count = client.postgrest.rpc("club_member_count", buildJsonObject { put("p_club_id", clubId) })
            .decodeAs<JsonElement>().let { (it as? JsonPrimitive)?.content?.toIntOrNull() } ?: 0
        val club = parseClub(row).copy(
            coverUrl = sign(row.text("cover_url")),
            iconUrl = sign(row.text("icon_url")),
            memberCount = count,
            rules = row.text("rules"),
            ownerId = row.text("owner_id"),
        )
        ClubDetail(
            club = club,
            membership = member.await()?.let { ClubMembership(it.text("role").orEmpty(), it.text("status").orEmpty()) },
            channels = channels.await().map { ClubChannel(it.text("id").orEmpty(), it.text("name") ?: "ทั่วไป") },
            muted = mute.await(),
        )
    }

    /** web fetchClubPostRows(). */
    override suspend fun posts(userId: String, clubId: String?): List<ClubPost> = coroutineScope {
        val raw = client.from("club_posts").select(Columns.raw(CLUB_POST_COLUMNS)) {
            if (clubId != null) filter { eq("club_id", clubId) }
            if (clubId != null) order("pinned", Order.DESCENDING)
            order("created_at", Order.DESCENDING)
            range(0L, (CLUB_POST_LIMIT - 1).toLong())
        }.decodeList<JsonObject>()
        if (raw.isEmpty()) return@coroutineScope emptyList()
        val ids = raw.mapNotNull { it.text("id") }
        val clubIds = raw.mapNotNull { it.text("club_id") }.distinct()
        val pollIds = raw.mapNotNull { relation(it["club_post_polls"]).text("id") }
        val likes = async {
            client.from("club_post_likes").select(Columns.list("club_post_id")) {
                filter { eq("user_id", userId); isIn("club_post_id", ids) }
            }.decodeList<JsonObject>().mapNotNullTo(HashSet()) { it.text("club_post_id") }
        }
        val saves = async {
            client.from("saves").select(Columns.list("content_id")) {
                filter { eq("user_id", userId); eq("content_type", "club_post"); isIn("content_id", ids) }
            }.decodeList<JsonObject>().mapNotNullTo(HashSet()) { it.text("content_id") }
        }
        val roles = async {
            client.from("club_members").select(Columns.list("club_id", "role", "status")) {
                filter { eq("user_id", userId); eq("status", "approved"); isIn("club_id", clubIds) }
            }.decodeList<JsonObject>().associate { it.text("club_id").orEmpty() to it.text("role").orEmpty() }
        }
        val votes = async {
            if (pollIds.isEmpty()) emptyMap() else client.from("club_post_poll_votes").select(Columns.list("poll_id", "option_index")) {
                filter { eq("voter_id", userId); isIn("poll_id", pollIds) }
            }.decodeList<JsonObject>().associate { it.text("poll_id").orEmpty() to (it.int("option_index") ?: -1) }
        }
        val results = async {
            if (pollIds.isEmpty()) emptyMap() else client.postgrest.rpc(
                "get_club_poll_results", buildJsonObject { put("p_poll_ids", JsonArray(pollIds.map(::JsonPrimitive))) },
            ).decodeList<JsonObject>().associateBy { it.text("poll_id").orEmpty() }
        }
        val images = raw.map { row ->
            async { stringList(row["image_urls"]).mapNotNull { sign(it) } }
        }
        val liked = likes.await()
        val saved = saves.await()
        val roleByClub = roles.await()
        val voteByPoll = votes.await()
        val resultByPoll = results.await()
        raw.mapIndexed { index, row ->
            val id = row.text("id").orEmpty()
            val club = row.text("club_id").orEmpty()
            val author = relation(row["author"])
            val poll = relation(row["club_post_polls"])
            val pollId = poll.text("id")
            val result = pollId?.let(resultByPoll::get)
            val visible = result?.bool("visible") == true
            ClubPost(
                id = id,
                clubId = club,
                authorId = row.text("author_id").orEmpty(),
                authorUsername = author.text("username").orEmpty(),
                authorDisplayName = author.text("display_name"),
                authorAvatarUrl = author.text("avatar_url"),
                content = row.text("content"),
                imageUrls = images[index].await(),
                linkUrl = row.text("link_url"),
                pinned = row.bool("pinned"),
                createdAt = row.text("created_at").orEmpty(),
                likeCount = firstCount(row["club_post_likes"]),
                commentCount = firstCount(row["club_post_comments"]),
                liked = id in liked,
                saved = id in saved,
                myRole = roleByClub[club],
                pollId = pollId,
                pollOptions = stringList(poll["options"]),
                pollExpiresAt = poll.text("expires_at"),
                pollMyVote = pollId?.let(voteByPoll::get),
                pollTotalVotes = if (visible) result?.int("total_votes") ?: 0 else null,
                pollOptionCounts = if (visible) (result?.get("option_counts") as? JsonArray)?.map { (it as? JsonPrimitive)?.content?.toDoubleOrNull()?.toInt() ?: 0 } else null,
            )
        }
    }

    override suspend fun post(postId: String): ClubPostPage? {
        val row = client.from("club_posts").select(
            Columns.raw("*,author:profiles!club_posts_author_id_fkey(username,display_name,avatar_url),club:clubs(name)"),
        ) { filter { eq("id", postId) } }.decodeList<JsonObject>().firstOrNull() ?: return null
        val author = relation(row["author"])
        return ClubPostPage(
            id = row.text("id").orEmpty(),
            clubId = row.text("club_id"),
            clubName = relation(row["club"]).text("name"),
            authorUsername = author.text("username").orEmpty(),
            authorDisplayName = author.text("display_name"),
            authorAvatarUrl = author.text("avatar_url"),
            content = row.text("content"),
            imageUrls = coroutineScope { stringList(row["image_urls"]).map { async { sign(it) } }.awaitAll().filterNotNull() },
            createdAt = row.text("created_at").orEmpty(),
        )
    }

    override suspend fun setLiked(userId: String, postId: String, liked: Boolean) {
        if (liked) {
            client.from("club_post_likes").insert(buildJsonObject { put("club_post_id", postId); put("user_id", userId) })
        } else {
            client.from("club_post_likes").delete { filter { eq("club_post_id", postId); eq("user_id", userId) } }
        }
    }

    override suspend fun setSaved(userId: String, postId: String, saved: Boolean) {
        if (saved) {
            client.from("saves").insert(buildJsonObject { put("user_id", userId); put("content_type", "club_post"); put("content_id", postId) })
        } else {
            client.from("saves").delete { filter { eq("user_id", userId); eq("content_type", "club_post"); eq("content_id", postId) } }
        }
    }

    override suspend fun setPinned(postId: String, pinned: Boolean) {
        client.from("club_posts").update(buildJsonObject { put("pinned", pinned) }) { filter { eq("id", postId) } }
    }

    override suspend fun deletePost(postId: String) {
        client.from("club_posts").delete { filter { eq("id", postId) } }
    }

    override suspend fun vote(userId: String, pollId: String, option: Int) {
        client.from("club_post_poll_votes").upsert(
            buildJsonObject { put("poll_id", pollId); put("voter_id", userId); put("option_index", option) },
        ) { onConflict = "poll_id,voter_id" }
    }

    override suspend fun setMuted(userId: String, clubId: String, muted: Boolean) {
        if (muted) {
            client.from("club_notification_mutes").insert(buildJsonObject { put("club_id", clubId); put("user_id", userId) })
        } else {
            client.from("club_notification_mutes").delete { filter { eq("club_id", clubId); eq("user_id", userId) } }
        }
    }

    override suspend fun messages(channelId: String): List<ClubMessage> = coroutineScope {
        client.from("club_channel_messages").select(
            Columns.raw("id,channel_id,author_id,content,image_url,created_at,author:profiles!club_channel_messages_author_id_fkey(username,display_name,avatar_url)"),
        ) {
            filter { eq("channel_id", channelId) }
            order("created_at", Order.ASCENDING)
            limit(150)
        }.decodeList<JsonObject>().map { row ->
            async {
                val author = relation(row["author"])
                ClubMessage(
                    id = row.text("id").orEmpty(),
                    authorId = row.text("author_id").orEmpty(),
                    content = row.text("content"),
                    imageUrl = sign(row.text("image_url")),
                    createdAt = row.text("created_at").orEmpty(),
                    authorUsername = author.text("username").orEmpty(),
                    authorDisplayName = author.text("display_name"),
                    authorAvatarUrl = author.text("avatar_url"),
                )
            }
        }.awaitAll()
    }

    override suspend fun markChannelRead(channelId: String) {
        client.postgrest.rpc("mark_club_channel_read", buildJsonObject { put("p_channel_id", channelId) })
    }

    override suspend fun sendMessage(userId: String, clubId: String, channelId: String, text: String?, image: PickedImage?) {
        val body = text?.trim()?.take(CLUB_MESSAGE_MAX)?.takeIf { it.isNotEmpty() }
        require(body != null || image != null) { "empty message" }
        var path: String? = null
        if (image != null) {
            require(image.bytes.size <= IMAGE_MAX_BYTES)
            path = "$clubId/chat/$channelId/$userId-${System.currentTimeMillis()}.${image.extension}"
            bucket.upload(path, image.bytes) {
                upsert = false
                contentType = ContentType.parse(image.contentType)
            }
        }
        try {
            client.from("club_channel_messages").insert(
                buildJsonObject {
                    put("channel_id", channelId)
                    put("author_id", userId)
                    put("content", body)
                    put("image_url", path)
                },
            )
        } catch (e: Exception) {
            // A photo that never became a message should not stay in the private bucket.
            path?.let { uploaded -> runCatching { bucket.delete(listOf(uploaded)) } }
            throw e
        }
    }

    override suspend fun deleteMessage(messageId: String) {
        client.from("club_channel_messages").delete { filter { eq("id", messageId) } }
    }

    override suspend fun members(clubId: String): List<ClubMember> {
        val viaRpc = runCatching {
            client.postgrest.rpc(
                "club_member_profiles",
                buildJsonObject { put("p_club_id", clubId); put("p_status", "approved"); put("p_limit", 200); put("p_offset", 0) },
            ).decodeList<JsonObject>()
        }.getOrNull()
        if (viaRpc != null) {
            return viaRpc.map { row ->
                ClubMember(
                    userId = row.text("user_id") ?: row.text("id").orEmpty(),
                    role = row.text("role") ?: "member",
                    username = row.text("username").orEmpty(),
                    displayName = row.text("display_name"),
                    avatarUrl = row.text("avatar_url"),
                )
            }.filter { it.userId.isNotEmpty() }
        }
        val membership = client.from("club_members").select(Columns.list("user_id", "role")) {
            filter { eq("club_id", clubId); eq("status", "approved") }
            limit(200)
        }.decodeList<JsonObject>()
        val ids = membership.mapNotNull { it.text("user_id") }
        if (ids.isEmpty()) return emptyList()
        val profiles = client.from("profiles").select(Columns.list("id", "username", "display_name", "avatar_url")) {
            filter { isIn("id", ids) }
        }.decodeList<JsonObject>().associateBy { it.text("id") }
        return membership.map { row ->
            val id = row.text("user_id").orEmpty()
            val profile = profiles[id]
            ClubMember(id, row.text("role").orEmpty(), profile?.text("username").orEmpty(), profile?.text("display_name"), profile?.text("avatar_url"))
        }
    }

    override suspend fun events(clubId: String): List<ClubEvent> =
        client.from("club_events").select(Columns.list("id", "title", "description", "starts_at", "location_type", "location")) {
            filter { eq("club_id", clubId) }
            order("starts_at", Order.ASCENDING)
            limit(50)
        }.decodeList<JsonObject>().map { row ->
            ClubEvent(
                id = row.text("id").orEmpty(),
                title = row.text("title").orEmpty(),
                description = row.text("description"),
                startsAt = row.text("starts_at").orEmpty(),
                locationType = row.text("location_type").orEmpty(),
                location = row.text("location").orEmpty(),
            )
        }

    override suspend fun insights(clubId: String): List<Pair<String, String>>? {
        val value = client.postgrest.rpc("club_insights", buildJsonObject { put("p_club_id", clubId); put("p_days", 30) })
            .decodeAs<JsonElement>()
        val row = (value as? JsonArray)?.firstOrNull() as? JsonObject ?: value as? JsonObject ?: return null
        return row.map { (key, element) -> key to ((element as? JsonPrimitive)?.content?.takeIf { it != "null" } ?: "0") }
    }

    override suspend fun report(targetType: String, targetId: String, category: String, detail: String?) {
        require(targetType in setOf("club", "club_post", "club_channel_message"))
        client.postgrest.rpc(
            "submit_report",
            buildJsonObject {
                put("p_target_type", targetType)
                put("p_target_id", targetId)
                put("p_category", category)
                put("p_detail", detail?.take(CLUB_REPORT_DETAIL_MAX))
            },
        )
    }

    override suspend fun previewInvite(code: String): ClubInvitePreview? {
        val value = client.postgrest.rpc("preview_club_invite_link", buildJsonObject { put("p_code", code) }).decodeAs<JsonElement>()
        val row = (value as? JsonArray)?.firstOrNull() as? JsonObject ?: value as? JsonObject
            ?: return ClubInvitePreview("not_found", null, null, null, null)
        val status = row.text("status") ?: "not_found"
        return ClubInvitePreview(
            status = status,
            clubId = row.text("club_id"),
            clubName = row.text("club_name"),
            clubPrivacy = row.text("club_privacy"),
            iconUrl = if (status == "valid") sign(row.text("club_icon_url")) else null,
        )
    }

    override suspend fun redeemInvite(code: String): String? =
        client.postgrest.rpc("redeem_club_invite_link", buildJsonObject { put("p_code", code) })
            .decodeAs<JsonElement>().let { (it as? JsonPrimitive)?.content?.takeIf { id -> id != "null" } }
}

internal fun parseClub(row: JsonObject) = Club(
    id = row.text("id").orEmpty(),
    name = row.text("name").orEmpty(),
    description = row.text("description"),
    category = row.text("category"),
    privacy = row.text("privacy"),
    createdAt = row.text("created_at").orEmpty(),
)

private fun stringList(value: JsonElement?): List<String> =
    (value as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.content?.takeIf { text -> text != "null" } }
