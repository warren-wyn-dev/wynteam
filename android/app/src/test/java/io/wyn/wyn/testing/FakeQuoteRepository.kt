package io.wyn.wyn.testing

import io.wyn.wyn.core.data.FeedRow
import io.wyn.wyn.core.data.QuoteComment
import io.wyn.wyn.core.data.QuoteEngagement
import io.wyn.wyn.core.data.QuoteRepository

/** In-memory Quotes; [failWrites] makes every action fail so rollbacks can be tested. */
class FakeQuoteRepository(
    var quotes: List<FeedRow> = listOf(QuoteFixture.quote),
    var counts: Map<String, QuoteEngagement> = mapOf(QuoteFixture.QUOTE_ID to QuoteFixture.engagement),
    var reposts: List<FeedRow> = emptyList(),
) : QuoteRepository {
    val writes = mutableListOf<String>()
    var failWrites = false
    var failEngagement = false
    val commentStore = mutableListOf<QuoteComment>()

    override suspend fun engagement(quoteIds: List<String>): Map<String, QuoteEngagement> {
        if (failEngagement) error("offline")
        return counts.filterKeys { it in quoteIds }
    }

    private fun write(entry: String) { if (failWrites) error("write failed"); writes += entry }
    override suspend fun setLiked(userId: String, quoteId: String, liked: Boolean) = write("like:$quoteId:$liked")
    override suspend fun setSaved(userId: String, quoteId: String, saved: Boolean) = write("save:$quoteId:$saved")
    override suspend fun setReposted(userId: String, quoteId: String, reposted: Boolean) = write("repost:$quoteId:$reposted")
    override suspend fun quoteDrop(userId: String, dropId: String, text: String) = write("quote:$dropId:${text.trim()}")
    override suspend fun deleteQuote(userId: String, quoteId: String) = write("delete:$quoteId")
    override suspend fun report(quoteId: String, category: String, detail: String?) = write("report:$quoteId:$category:${detail.orEmpty()}")
    override suspend fun fetchQuote(quoteId: String) = quotes.firstOrNull { it.redropId == quoteId }
    override suspend fun repostRows(userIds: List<String>, limit: Int) = reposts.filter { it.quoteReposterId in userIds }.take(limit)
    var liked: List<Pair<FeedRow, String>> = emptyList()
    override suspend fun likedRows(userId: String, limit: Int) = liked.take(limit)
    var saved: List<Pair<FeedRow, String>> = emptyList()
    override suspend fun savedRows(userId: String, limit: Int) = saved.take(limit)
    override suspend fun fetchImages(dropId: String, fallback: String?) = listOfNotNull(fallback)
    override suspend fun comments(quoteId: String, page: Int) =
        commentStore.filter { it.quoteId == quoteId }.drop(page * io.wyn.wyn.core.data.QUOTE_COMMENT_PAGE).take(io.wyn.wyn.core.data.QUOTE_COMMENT_PAGE)
    override suspend fun addComment(userId: String, quoteId: String, text: String) {
        write("comment:$quoteId:${text.trim()}")
        commentStore.add(0, QuoteComment("c${commentStore.size + 1}", quoteId, userId, "fixture", "Fixture", null, false, text.trim(), "2026-09-27T10:00:00.000Z"))
    }
    override suspend fun removeComment(userId: String, commentId: String) {
        write("uncomment:$commentId")
        commentStore.removeAll { it.id == commentId && it.authorId == userId }
    }
}

/** The web's Quote fixture (web/app/dev/quote-fixture). */
object QuoteFixture {
    const val QUOTE_ID = "quote-fixture-1"
    val quote = FeedRow(
        id = "drop-1", authorId = "warren", authorUsername = "warren", authorDisplayName = "WARREN",
        createdAt = "2026-09-04T10:00:00.000Z",
        caption = "WYNOS เริ่มจากคำถามง่าย ๆ ว่า...\n“ทำไม Social Media กับการซื้อของ ต้องแยกกัน?”",
        likeCount = 6, commentCount = 2, redropCount = 2, audience = "everyone",
        redropId = QUOTE_ID, redropperId = "mint", redropperUsername = "mint", redropperDisplayName = "mint",
        quoteText = "เห็นด้วยมาก อยากให้มีแอปแบบนี้นานแล้ว 🙌",
    )
    val engagement = QuoteEngagement(QUOTE_ID, likeCount = 3, commentCount = 1, repostCount = 1)
}
