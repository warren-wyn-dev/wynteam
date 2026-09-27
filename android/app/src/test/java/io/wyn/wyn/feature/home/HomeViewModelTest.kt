package io.wyn.wyn.feature.home

import io.wyn.wyn.R
import io.wyn.wyn.testing.FakeFeedRepository
import io.wyn.wyn.testing.HomeFixture
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
class HomeViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val repo = FakeFeedRepository()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    private fun TestScope.start(): HomeViewModel = HomeViewModel(repo, HomeFixture.VIEWER).also { advanceUntilIdle() }
    private fun HomeViewModel.row(id: String) = snapshot!!.rows.first { it.id == id }

    @Test fun loadsForYouAndCachesEachTab() = runTest(dispatcher) {
        val vm = start()
        assertEquals(4, vm.snapshot!!.rows.size)
        assertEquals("fixture", vm.identity?.username)
        vm.select(FeedMode.Following); advanceUntilIdle()
        assertTrue(vm.snapshot!!.rows.isEmpty())
        val reads = repo.reads
        vm.select(FeedMode.ForYou); advanceUntilIdle()
        assertEquals("switching back uses the cache", reads, repo.reads)
        assertEquals(4, vm.snapshot!!.rows.size)
    }

    @Test fun aFailedFirstLoadShowsRetry() = runTest(dispatcher) {
        repo.failReads = true
        val vm = start()
        assertNull(vm.snapshot)
        assertEquals(R.string.feed_load_failed, vm.error?.res)
        repo.failReads = false
        vm.load(); advanceUntilIdle()
        assertNull(vm.error)
        assertEquals(4, vm.snapshot!!.rows.size)
    }

    @Test fun likeIsOptimisticAndRollsBackOnFailure() = runTest(dispatcher) {
        val vm = start()
        vm.toggleLike(vm.row("drop-3")); advanceUntilIdle()
        assertTrue("drop-3" in vm.snapshot!!.viewer.liked)
        assertEquals(29, vm.row("drop-3").likeCount)
        assertEquals(listOf("like:drop-3:true"), repo.writes)

        repo.failWrites = true
        vm.toggleLike(vm.row("drop-3")); advanceUntilIdle()
        assertTrue("drop-3" in vm.snapshot!!.viewer.liked)
        assertEquals(29, vm.row("drop-3").likeCount)
        assertEquals(R.string.like_failed, vm.toast?.text?.res)
    }

    @Test fun doubleTapOnAPhotoOnlyLikes() = runTest(dispatcher) {
        val vm = start()
        vm.likeFromPhoto(vm.row("drop-1")); advanceUntilIdle()
        assertTrue("drop-1" in vm.snapshot!!.viewer.liked)
        assertTrue(repo.writes.isEmpty())
    }

    @Test fun aSecondTapWhileTheFirstIsInFlightIsIgnored() = runTest(dispatcher) {
        val vm = start()
        val row = vm.row("drop-3")
        vm.toggleLike(row)
        vm.toggleLike(row)
        advanceUntilIdle()
        assertEquals(listOf("like:drop-3:true"), repo.writes)
    }

    @Test fun saveOffersUndo() = runTest(dispatcher) {
        val vm = start()
        vm.toggleSave(vm.row("drop-2")); advanceUntilIdle()
        assertTrue("drop-2" in vm.snapshot!!.viewer.saved)
        assertEquals(R.string.post_saved, vm.toast?.text?.res)
        vm.toast!!.action!!.invoke(); advanceUntilIdle()
        assertFalse("drop-2" in vm.snapshot!!.viewer.saved)
        assertEquals(listOf("save:drop-2:true", "save:drop-2:false"), repo.writes)
    }

    @Test fun repostCountsAndClosesTheSheet() = runTest(dispatcher) {
        val vm = start()
        vm.openSheet(PostSheet.Repost(vm.row("drop-3")))
        vm.toggleRepost(vm.row("drop-3")); advanceUntilIdle()
        assertEquals(1, vm.row("drop-3").redropCount)
        assertNull(vm.sheet)
        assertFalse(vm.busy)
    }

    @Test fun followingAPrivateAuthorRequests() = runTest(dispatcher) {
        repo.viewer = HomeFixture.viewer.copy(privateAuthors = setOf("mint"))
        val vm = start()
        vm.toggleFollow(vm.row("drop-3")); advanceUntilIdle()
        assertTrue("mint" in vm.snapshot!!.viewer.requested)
        assertFalse("mint" in vm.snapshot!!.viewer.following)
    }

    @Test fun hideAndUndoKeepThePosition() = runTest(dispatcher) {
        val vm = start()
        vm.hide(vm.row("drop-2")); advanceUntilIdle()
        assertEquals(listOf("drop-1", "drop-3", "drop-4"), vm.snapshot!!.rows.map { it.id })
        vm.undoHide(); advanceUntilIdle()
        assertEquals(listOf("drop-1", "drop-2", "drop-3", "drop-4"), vm.snapshot!!.rows.map { it.id })
        assertEquals(listOf("hide:drop-2", "unhide:drop-2"), repo.writes)
    }

    @Test fun reportOtherNeedsDetails() = runTest(dispatcher) {
        val vm = start()
        vm.openSheet(PostSheet.Report(vm.row("drop-3")))
        vm.chooseReportCategory("other")
        vm.submitReport()
        assertEquals(R.string.report_detail_required, vm.reportError?.res)
        vm.updateReportDetail("  โพสต์ซ้ำ  ")
        vm.submitReport(); advanceUntilIdle()
        assertEquals(listOf("report:drop-3:other:โพสต์ซ้ำ"), repo.writes)
        assertNull(vm.sheet)
    }

    @Test fun likesStayInStepAcrossTabs() = runTest(dispatcher) {
        repo.following = listOf(HomeFixture.rows[1], HomeFixture.rows[3])
        val vm = start()
        vm.select(FeedMode.Following); advanceUntilIdle()
        vm.toggleLike(vm.row("drop-4")); advanceUntilIdle()
        vm.select(FeedMode.ForYou)
        assertTrue("drop-4" in vm.snapshot!!.viewer.liked)
        assertEquals(1, vm.row("drop-4").likeCount)
        // The For You-only like on drop-1 is kept.
        assertTrue("drop-1" in vm.snapshot!!.viewer.liked)
    }
}
