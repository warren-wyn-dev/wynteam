package io.wyn.wyn.feature.quote

import io.wyn.wyn.R
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
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class QuoteDetailViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val repo = FakeQuoteRepository()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    private fun TestScope.open(id: String = QuoteFixture.QUOTE_ID) =
        QuoteDetailViewModel(repo, HomeFixture.VIEWER, id).also { advanceUntilIdle() }

    @Test fun loadsTheQuoteAndItsOwnCounts() = runTest(dispatcher) {
        val vm = open()
        assertEquals(QuoteFixture.quote, vm.row)
        assertEquals(3, vm.quote.engagement.getValue(QuoteFixture.QUOTE_ID).likeCount)
    }

    @Test fun anUnknownQuoteIsNotFound() = runTest(dispatcher) {
        assertTrue(open("missing").notFound)
    }

    @Test fun commentingAdjustsTheQuotesCount() = runTest(dispatcher) {
        val vm = open()
        vm.updateDraft("  สวัสดี  ")
        vm.send(); advanceUntilIdle()
        assertEquals(listOf("comment:${QuoteFixture.QUOTE_ID}:สวัสดี"), repo.writes)
        assertEquals(1, vm.comments.size)
        assertEquals("", vm.draft)
        assertEquals(2, vm.quote.engagement.getValue(QuoteFixture.QUOTE_ID).commentCount)

        vm.remove(vm.comments.first()); advanceUntilIdle()
        assertTrue(vm.comments.isEmpty())
        assertEquals(1, vm.quote.engagement.getValue(QuoteFixture.QUOTE_ID).commentCount)
    }

    @Test fun aFailedCommentKeepsTheDraft() = runTest(dispatcher) {
        val vm = open()
        repo.failWrites = true
        vm.updateDraft("สวัสดี")
        vm.send(); advanceUntilIdle()
        assertEquals("สวัสดี", vm.draft)
        assertTrue(vm.error != null || vm.toast != null)
    }
}
