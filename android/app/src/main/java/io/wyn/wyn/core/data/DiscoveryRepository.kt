package io.wyn.wyn.core.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.Instant
import kotlin.math.pow

/** web RankedHashtag. */
data class RankedHashtag(val tag: String, val score: Double, val postCount: Int)

/** One trending_hashtag_candidates row. */
data class HashtagCandidate(
    val createdAt: String,
    val caption: String?,
    val likeCount: Int,
    val commentCount: Int,
    val redropCount: Int,
    val viewCount: Int,
)

private val HASHTAG = Regex("#[\\p{L}\\p{N}_]+")

/** web extractHashtags(): distinct lower-case tags without "#". */
fun extractHashtags(text: String): List<String> =
    HASHTAG.findAll(text).map { it.value.drop(1).lowercase() }.filter { it.isNotEmpty() }.distinct().toList()

/**
 * web fetchTrendingHashtags(): engagement (likes + comments×2 + reposts×3 +
 * views×0.1) decayed by age, summed per tag; ties go to the tag in more posts.
 */
fun rankHashtags(rows: List<HashtagCandidate>, limit: Int, now: Instant = Instant.now()): List<RankedHashtag> {
    val scores = LinkedHashMap<String, Double>()
    val counts = HashMap<String, Int>()
    for (row in rows) {
        val tags = extractHashtags(row.caption.orEmpty())
        if (tags.isEmpty()) continue
        val ageHours = maxOf(0.0, (now.toEpochMilli() - instantMillis(row.createdAt)) / 3_600_000.0)
        val engagement = row.likeCount + row.commentCount * 2.0 + row.redropCount * 3.0 + row.viewCount * 0.1
        val score = engagement / (ageHours + 2).pow(1.5)
        for (tag in tags) {
            scores[tag] = (scores[tag] ?: 0.0) + score
            counts[tag] = (counts[tag] ?: 0) + 1
        }
    }
    return scores.keys
        .sortedWith(compareByDescending<String> { scores.getValue(it) }.thenByDescending { counts[it] ?: 0 })
        .take(limit)
        .map { RankedHashtag(it, scores.getValue(it), counts[it] ?: 0) }
}

const val SEARCH_PEOPLE_PAGE = 30
const val SEARCH_POSTS_PAGE = 21
const val SEARCH_CLUBS_PAGE = 20
const val SAVED_PAGE = 21

/** Search, trending hashtags and saved posts (web search-route, trending-route, bookmarks-route). */
interface DiscoveryRepository {
    suspend fun trending(limit: Int): List<RankedHashtag>
    suspend fun suggested(viewerId: String, limit: Int): List<Person>
    suspend fun searchPeople(viewerId: String, query: String, page: Int): List<Person>
    suspend fun searchPosts(query: String, page: Int): List<FeedRow>
    suspend fun searchClubs(query: String, page: Int): List<Club>
    /** Saved Drops and saved Quotes, newest save first, one page of [SAVED_PAGE]. */
    suspend fun saved(userId: String, page: Int): List<FeedRow>
}

/** web safeOrPattern(): the query quoted for a PostgREST or() filter. */
internal fun safeOrPattern(query: String): String {
    val escaped = "%$query%".replace("\\", "\\\\").replace("\"", "\\\"")
    return "\"$escaped\""
}

class SupabaseDiscoveryRepository(
    private val clientOrNull: SupabaseClient?,
    private val profiles: ProfileRepository,
    private val clubs: ClubRepository,
    private val quotes: QuoteRepository,
) : DiscoveryRepository {
    private val client: SupabaseClient get() = clientOrNull ?: throw NotConfiguredException()

    override suspend fun trending(limit: Int): List<RankedHashtag> {
        val rows = client.postgrest.rpc("trending_hashtag_candidates", buildJsonObject { put("p_hours", 48); put("p_limit", 100) })
            .decodeList<JsonObject>().map { row ->
                HashtagCandidate(
                    createdAt = row.text("created_at").orEmpty(),
                    caption = row.text("caption"),
                    likeCount = row.int("like_count") ?: 0,
                    commentCount = row.int("comment_count") ?: 0,
                    redropCount = row.int("redrop_count") ?: 0,
                    viewCount = row.int("view_count") ?: 0,
                )
            }
        return rankHashtags(rows, limit)
    }

    override suspend fun suggested(viewerId: String, limit: Int): List<Person> {
        val ids = client.postgrest.rpc("suggested_users", buildJsonObject { put("p_limit", limit) })
            .decodeList<JsonObject>().mapNotNull { it.text("profile_id") }
        return if (ids.isEmpty()) emptyList() else profiles.peopleByIds(viewerId, ids)
    }

    override suspend fun searchPeople(viewerId: String, query: String, page: Int): List<Person> {
        val pattern = safeOrPattern(query.trim())
        val from = (page * SEARCH_PEOPLE_PAGE).toLong()
        val ids = client.from("profiles").select(Columns.list("id")) {
            filter { or { ilike("username", pattern); ilike("display_name", pattern) } }
            range(from, from + SEARCH_PEOPLE_PAGE - 1)
        }.decodeList<JsonObject>().mapNotNull { it.text("id") }
        return if (ids.isEmpty()) emptyList() else profiles.peopleByIds(viewerId, ids)
    }

    override suspend fun searchPosts(query: String, page: Int): List<FeedRow> {
        val from = (page * SEARCH_POSTS_PAGE).toLong()
        return client.from("drops").select(Columns.raw(DROP_SELECT)) {
            filter { ilike("caption", "%${query.trim()}%"); exact("deleted_at", null) }
            order("created_at", Order.DESCENDING)
            range(from, from + SEARCH_POSTS_PAGE - 1)
        }.decodeList<JsonObject>().map(::parseDropCard)
    }

    override suspend fun searchClubs(query: String, page: Int): List<Club> = clubs.search(query, page)

    override suspend fun saved(userId: String, page: Int): List<FeedRow> = coroutineScope {
        val limit = (page.coerceAtLeast(0) + 1) * SAVED_PAGE
        val originals = async {
            val raw = client.from("saved_feed").select {
                filter { eq("user_id", userId); neq("content_type", "pop") }
                order("saved_at", Order.DESCENDING)
                range(0L, (limit - 1).toLong())
            }.decodeAs<JsonElement>()
            val savedAt = (raw as? kotlinx.serialization.json.JsonArray).orEmpty()
                .mapNotNull { it as? JsonObject }.associate { it.text("id").orEmpty() to it.text("saved_at").orEmpty() }
            FeedRow.parseList(raw, limit).map { it to (savedAt[it.id] ?: it.createdAt) }
        }
        val savedQuotes = async { quotes.savedRows(userId, limit) }
        (originals.await() + savedQuotes.await())
            .sortedByDescending { instantMillis(it.second) }
            .map { it.first }
            .drop(page * SAVED_PAGE).take(SAVED_PAGE)
    }
}
