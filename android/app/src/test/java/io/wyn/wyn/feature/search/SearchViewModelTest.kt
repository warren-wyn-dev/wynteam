package io.wyn.wyn.feature.search

import io.wyn.wyn.R
import io.wyn.wyn.core.data.EngagementSync
import io.wyn.wyn.core.data.HashtagCandidate
import io.wyn.wyn.core.data.extractHashtags
import io.wyn.wyn.core.data.rankHashtags
import io.wyn.wyn.core.data.safeOrPattern
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.testing.FakeDiscoveryRepository
import io.wyn.wyn.testing.FakeFeedRepository
import io.wyn.wyn.testing.HomeFixture
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.Instant

@OptIn(ExperimentalCoroutinesApi::class)
class SearchViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val repo = FakeDiscoveryRepository()
    private val feed = FakeFeedRepository()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    @Test fun hashtagsAreExtractedAndRankedLikeTheWeb() {
        assertEquals(listOf("wynos", "กาแฟ", "a_1"), extractHashtags("#WYNOS ชอบ #กาแฟ #wynos #a_1 # #"))
        val now = Instant.parse("2026-09-27T12:00:00Z")
        val rows = listOf(
            HashtagCandidate("2026-09-27T11:00:00Z", "#hot #both", likeCount = 10, commentCount = 0, redropCount = 0, viewCount = 0),
            HashtagCandidate("2026-09-25T12:00:00Z", "#old #both", likeCount = 100, commentCount = 0, redropCount = 0, viewCount = 0),
            HashtagCandidate("2026-09-27T11:00:00Z", "no tags", likeCount = 1000, commentCount = 0, redropCount = 0, viewCount = 0),
        )
        val ranked = rankHashtags(rows, 10, now)
        // 10/3^1.5 ≈ 1.92 beats 100/50^1.5 ≈ 0.28; "both" gets the two summed.
        assertEquals(listOf("both", "hot", "old"), ranked.map { it.tag })
        assertEquals(2, ranked.first().postCount)
        assertEquals(1, rankHashtags(rows, 1, now).size)
    }

    @Test fun orPatternIsQuoted() {
        assertEquals("\"%a\\\"b\\\\c%\"", safeOrPattern("a\"b\\c"))
    }

    @Test fun discoveryThenDebouncedSearch() = runTest(dispatcher) {
        val vm = SearchViewModel(repo, feed, HomeFixture.VIEWER); advanceUntilIdle()
        assertEquals(6, vm.hashtags.size)
        assertEquals(4, vm.suggested.size)
        vm.updateDraft("w")
        advanceUntilIdle()
        assertEquals("one letter is not searched", "", vm.query)
        vm.updateDraft("wyn")
        advanceTimeBy(300); runCurrent()
        assertEquals("", vm.query)
        advanceTimeBy(150); runCurrent()
        assertEquals("wyn", vm.query)
        advanceUntilIdle()
        assertEquals(listOf("wyn_team"), vm.allUsers.map { it.username })
        assertTrue(vm.allPosts.isNotEmpty())
        vm.clear(); advanceUntilIdle()
        assertEquals("", vm.query)
    }

    @Test fun submitSkipsTheWaitAndTabsLoadTheirOwnResults() = runTest(dispatcher) {
        val vm = SearchViewModel(repo, feed, HomeFixture.VIEWER); advanceUntilIdle()
        vm.updateDraft("s")
        vm.submitNow(); advanceUntilIdle()
        assertEquals("", vm.query)
        vm.updateDraft("sky"); vm.submitNow(); runCurrent()
        assertEquals("sky", vm.query)
        advanceUntilIdle()
        vm.select(SearchTab.Users); advanceUntilIdle()
        assertEquals(listOf("sky_blue"), vm.users.rows.map { it.username })
        assertFalse(vm.users.hasMore)
        vm.select(SearchTab.Clubs); advanceUntilIdle()
        assertTrue(vm.clubs.rows.isEmpty())
        repo.fail = true
        vm.select(SearchTab.Users); advanceUntilIdle()
        assertEquals(UiText(R.string.search_people_failed), vm.error)
    }

    @Test fun followAsksBeforeCancellingAPrivateRequest() = runTest(dispatcher) {
        val vm = SearchViewModel(repo, feed, HomeFixture.VIEWER); advanceUntilIdle()
        val requested = vm.suggested.first { it.requested }
        vm.follow(requested)
        assertEquals(requested, vm.confirmCancel)
        vm.follow(requested, confirmed = true); advanceUntilIdle()
        assertNull(vm.confirmCancel)
        val open = vm.suggested.first { it.username == "mind_coffee" }
        vm.follow(open); advanceUntilIdle()
        assertTrue(vm.suggested.first { it.id == open.id }.following)
    }

    @Test fun postsFollowTheQueryWithPaging() = runTest(dispatcher) {
        val posts = SearchPostsViewModel(repo, feed, HomeFixture.VIEWER, EngagementSync(), null); advanceUntilIdle()
        assertTrue(posts.snapshot?.rows.orEmpty().isEmpty())
        posts.select("กาแฟ"); advanceUntilIdle()
        assertEquals(listOf("drop-3"), posts.snapshot?.rows?.map { it.id })
        assertFalse(posts.snapshot!!.hasMore)
    }

    @Test fun trendingAndBookmarks() = runTest(dispatcher) {
        val trending = TrendingViewModel(repo); advanceUntilIdle()
        assertEquals(6, trending.hashtags.size)
        repo.fail = true
        trending.load(); advanceUntilIdle()
        assertEquals(UiText(R.string.trending_failed), trending.error)
        repo.fail = false
        val saved = BookmarksViewModel(repo, feed, HomeFixture.VIEWER, EngagementSync(), null); advanceUntilIdle()
        assertEquals(listOf("drop-1", "drop-2"), saved.snapshot?.rows?.map { it.id })
    }
}
