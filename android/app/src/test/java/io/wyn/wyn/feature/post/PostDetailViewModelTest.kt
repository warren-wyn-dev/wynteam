package io.wyn.wyn.feature.post

import io.wyn.wyn.R
import io.wyn.wyn.core.data.Comment
import io.wyn.wyn.core.data.EngagementSync
import io.wyn.wyn.feature.home.HomeViewModel
import io.wyn.wyn.testing.FakeFeedRepository
import io.wyn.wyn.testing.FakePostRepository
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
import java.time.Instant

@OptIn(ExperimentalCoroutinesApi::class)
class PostDetailViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val feed = FakeFeedRepository()
    private val posts = FakePostRepository(
        comments = mutableListOf(
            Comment("c1", "drop-3", "warren", "สวยมาก", "2026-09-27T09:00:00Z", authorUsername = "warren"),
            Comment("c2", "drop-3", HomeFixture.VIEWER, "ขอบคุณ", "2026-09-27T09:05:00Z", parentId = "c1", authorUsername = "fixture"),
            Comment("c3", "drop-3", "mint", "☕", "2026-09-27T09:10:00Z", authorUsername = "mint"),
        ),
    )

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    private fun TestScope.open(dropId: String = "drop-3", sync: EngagementSync = EngagementSync(), now: Instant = Instant.now()) =
        PostDetailViewModel(posts, feed, HomeFixture.VIEWER, dropId, sync) { now }.also { advanceUntilIdle() }

    @Test fun loadsThePostThreadsCommentsAndRecordsAView() = runTest(dispatcher) {
        val vm = open()
        assertEquals("drop-3", vm.row?.id)
        assertEquals(listOf("c1", "c3"), vm.threads.map { it.first.id })
        assertEquals(listOf("c2"), vm.threads.first().second.map { it.id })
        assertEquals(1, posts.views)
        assertFalse(vm.hasMoreComments)
    }

    @Test fun aMissingPostShowsNotFound() = runTest(dispatcher) {
        val vm = open("gone")
        assertNull(vm.row)
        assertFalse(vm.loading)
    }

    @Test fun replyingAddsTheCommentAndCountsIt() = runTest(dispatcher) {
        val vm = open()
        vm.replyTo(vm.comments.first())
        vm.updateDraft("  ตอบนะ  ")
        vm.submitComment(); advanceUntilIdle()
        assertEquals("comment:drop-3:ตอบนะ:c1", posts.writes.single())
        assertEquals(6, vm.row?.commentCount)
        assertEquals("", vm.draft)
        assertNull(vm.replyTo)
        assertEquals(listOf("c2", "new-1"), vm.threads.first().second.map { it.id })
    }

    @Test fun deletingACommentAlsoRemovesItsReplies() = runTest(dispatcher) {
        val vm = open()
        vm.deleteComment(vm.comments.first { it.id == "c1" }) // not mine: ignored
        advanceUntilIdle()
        assertTrue(posts.writes.isEmpty())
        posts.comments[0] = posts.comments[0].copy(authorId = HomeFixture.VIEWER)
        val mine = open()
        mine.deleteComment(mine.comments.first { it.id == "c1" }); advanceUntilIdle()
        assertEquals(listOf("c3"), mine.comments.map { it.id })
        assertEquals(3, mine.row?.commentCount)
    }

    @Test fun likesMadeHereReachTheHomeFeed() = runTest(dispatcher) {
        val sync = EngagementSync()
        val home = HomeViewModel(feed, HomeFixture.VIEWER, sync)
        advanceUntilIdle()
        val vm = open(sync = sync)
        vm.toggleLike(); advanceUntilIdle()
        assertTrue("drop-3" in home.snapshot!!.viewer.liked)
        assertEquals(29, home.snapshot!!.rows.first { it.id == "drop-3" }.likeCount)
        home.toggleSave(home.snapshot!!.rows.first { it.id == "drop-3" }); advanceUntilIdle()
        assertTrue("drop-3" in vm.viewer.saved)
    }

    @Test fun onlyTheAuthorCanEditAndOnlyForThirtyMinutes() = runTest(dispatcher) {
        posts.drops["mine"] = HomeFixture.rows[2].copy(id = "mine", authorId = HomeFixture.VIEWER, createdAt = "2026-09-27T10:00:00Z")
        assertTrue(open("mine", now = Instant.parse("2026-09-27T10:29:00Z")).canEdit)
        assertFalse(open("mine", now = Instant.parse("2026-09-27T10:31:00Z")).canEdit)
        assertFalse(open("drop-3").canEdit)
        val vm = open("mine", now = Instant.parse("2026-09-27T10:05:00Z"))
        vm.open(DetailDialog.Edit)
        vm.updateEditCaption("  ใหม่  ")
        vm.saveEdit(); advanceUntilIdle()
        assertEquals("ใหม่", vm.row?.caption)
        vm.deletePost(); advanceUntilIdle()
        assertTrue(vm.deleted)
        assertEquals(listOf("edit:mine:ใหม่", "delete:mine"), posts.writes)
    }

    @Test fun reportNeedsText() = runTest(dispatcher) {
        val vm = open()
        vm.open(DetailDialog.Report)
        vm.submitReport(); advanceUntilIdle()
        assertTrue(feed.writes.isEmpty())
        vm.updateReportText("สแปม")
        vm.submitReport(); advanceUntilIdle()
        assertEquals(listOf("report:drop-3:other:สแปม"), feed.writes)
        assertEquals(R.string.report_sent, vm.toast?.text?.res)
    }

    @Test fun activityListsWhoLiked() = runTest(dispatcher) {
        val vm = open()
        vm.open(DetailDialog.Activity); advanceUntilIdle()
        assertEquals(listOf("warren"), vm.activity?.likes?.map { it.id })
    }
}
