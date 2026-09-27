package io.wyn.wyn.feature.quote

import io.wyn.wyn.R
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.feature.home.FeedMode
import io.wyn.wyn.feature.home.HomeViewModel
import io.wyn.wyn.testing.FakeFeedRepository
import io.wyn.wyn.testing.FakeQuoteRepository
import io.wyn.wyn.testing.HomeFixture
import io.wyn.wyn.testing.QuoteFixture
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class QuoteControllerTest {
    private val dispatcher = StandardTestDispatcher()
    private val repo = FakeQuoteRepository()
    private val toasts = mutableListOf<UiText>()
    private val quote = QuoteFixture.quote
    private val mine = quote.copy(redropperId = HomeFixture.VIEWER)

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    private fun TestScope.controller() = QuoteController(this, repo, HomeFixture.VIEWER, onToast = { toasts += it })
    private fun QuoteController.counts() = engagement.getValue(QuoteFixture.QUOTE_ID)

    @Test fun loadsTheQuotesOwnCountsNotTheOriginals() = runTest(dispatcher) {
        val c = controller()
        c.load(listOf(quote, HomeFixture.rows[2]))
        assertEquals(3, c.counts().likeCount)
        assertEquals(setOf(QuoteFixture.QUOTE_ID), c.engagement.keys)
    }

    @Test fun aFailedLoadLeavesARetry() = runTest(dispatcher) {
        repo.failEngagement = true
        val c = controller()
        c.load(listOf(quote))
        assertTrue(QuoteFixture.QUOTE_ID in c.failed)
        repo.failEngagement = false
        c.retry(quote); advanceUntilIdle()
        assertFalse(QuoteFixture.QUOTE_ID in c.failed)
    }

    @Test fun likeIsOptimisticAndRollsBack() = runTest(dispatcher) {
        val c = controller()
        c.load(listOf(quote))
        c.toggleLike(quote); advanceUntilIdle()
        assertTrue(c.counts().liked)
        assertEquals(4, c.counts().likeCount)
        assertEquals(listOf("like:${QuoteFixture.QUOTE_ID}:true"), repo.writes)

        repo.failWrites = true
        c.toggleLike(quote); advanceUntilIdle()
        assertEquals(R.string.quote_like_failed, toasts.last().res)
        assertEquals(3, c.counts().likeCount)
    }

    @Test fun aSecondTapInFlightIsIgnored() = runTest(dispatcher) {
        val c = controller()
        c.load(listOf(quote))
        c.toggleRepost(quote)
        c.toggleRepost(quote)
        advanceUntilIdle()
        assertEquals(listOf("repost:${QuoteFixture.QUOTE_ID}:true"), repo.writes)
        assertEquals(2, c.counts().repostCount)
    }

    @Test fun saveShowsAToast() = runTest(dispatcher) {
        val c = controller()
        c.load(listOf(quote))
        c.toggleSave(quote); advanceUntilIdle()
        assertTrue(c.counts().saved)
        assertEquals(R.string.post_saved, toasts.last().res)
    }

    @Test fun reportingNeedsDetailForOtherAndNeverOwnQuote() = runTest(dispatcher) {
        val c = controller()
        c.open(QuoteSheet.Report(quote))
        c.chooseReason("other")
        c.submitReport(); advanceUntilIdle()
        assertEquals(R.string.report_detail_required, c.error?.res)
        c.updateReportDetail("  ขายของปลอม  ")
        c.submitReport(); advanceUntilIdle()
        assertEquals(listOf("report:${QuoteFixture.QUOTE_ID}:other:ขายของปลอม"), repo.writes)
        assertNull(c.sheet)

        c.open(QuoteSheet.Report(mine))
        c.submitReport(); advanceUntilIdle()
        assertEquals(1, repo.writes.size)
    }

    @Test fun onlyTheAuthorCanDelete() = runTest(dispatcher) {
        val c = controller()
        var deleted = 0
        c.open(QuoteSheet.ConfirmDelete(quote))
        c.delete { deleted++ }; advanceUntilIdle()
        assertEquals(0, deleted)
        assertTrue(repo.writes.isEmpty())

        c.open(QuoteSheet.ConfirmDelete(mine))
        c.delete { deleted++ }; advanceUntilIdle()
        assertEquals(1, deleted)
        assertEquals(listOf("delete:${QuoteFixture.QUOTE_ID}"), repo.writes)
    }

    @Test fun quotingIsOnlyForPublicPostsAndAsksBeforeDiscarding() = runTest(dispatcher) {
        val c = controller()
        c.startQuote(HomeFixture.rows[2].copy(audience = "followers"))
        assertNull(c.quoting)

        val drop = HomeFixture.rows[2]
        c.startQuote(drop)
        c.updateQuoteText("x".repeat(600))
        assertEquals(500, c.quoteText.length)
        c.requestCloseQuote()
        assertTrue(c.quoteDiscardPrompt)
        c.keepQuoting()
        c.updateQuoteText("  น่าสนใจ  ")
        var published = 0
        c.submitQuote { published++ }; advanceUntilIdle()
        assertEquals(1, published)
        assertEquals(listOf("quote:${drop.id}:น่าสนใจ"), repo.writes)
        assertNull(c.quoting)
        assertEquals(R.string.quote_published, toasts.last().res)
    }

    @Test fun aFailedQuoteKeepsTheText() = runTest(dispatcher) {
        repo.failWrites = true
        val c = controller()
        c.startQuote(HomeFixture.rows[2])
        c.updateQuoteText("น่าสนใจ")
        c.submitQuote {}; advanceUntilIdle()
        assertEquals("น่าสนใจ", c.quoteText)
        assertEquals(R.string.quote_failed, c.error?.res)
    }

    @Test fun homeShowsFollowedQuoteRepostsAndRemovesDeletedQuotes() = runTest(dispatcher) {
        val feed = FakeFeedRepository(ranked = HomeFixture.rows + quote)
        val vm = HomeViewModel(feed, HomeFixture.VIEWER, quotes = repo); advanceUntilIdle()
        assertEquals(3, vm.quote!!.engagement.getValue(QuoteFixture.QUOTE_ID).likeCount)
        assertEquals("https://wynos.online/quote/${QuoteFixture.QUOTE_ID}", vm.shareUrl(quote))
        vm.removeQuote(quote)
        assertFalse(vm.snapshot!!.rows.any { it.isQuote })
        vm.select(FeedMode.ForYou)
        assertEquals(4, vm.snapshot!!.rows.size)
    }
}
