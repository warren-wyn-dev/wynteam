package io.wyn.wyn.feature.notifications

import io.wyn.wyn.R
import io.wyn.wyn.core.data.NotificationItem
import io.wyn.wyn.core.data.mergeNewestNotificationPage
import io.wyn.wyn.testing.FakeNotificationRepository
import io.wyn.wyn.testing.HomeFixture
import io.wyn.wyn.testing.NotificationFixture
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneOffset

@OptIn(ExperimentalCoroutinesApi::class)
class NotificationsViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val repo = FakeNotificationRepository()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    @Test fun groupsLikesOnTheSamePostWithinADay() {
        val sections = NotificationRules.sections(NotificationFixture.rows, LocalDate.now(), java.time.ZoneId.systemDefault())
        val today = sections.first()
        assertEquals(DayBucket.Today, today.bucket)
        val likes = today.groups.first()
        assertEquals("n1", likes.head.id)
        assertEquals(3, likes.items.size)
        assertEquals(2, likes.extraActorCount)
        assertEquals(listOf(DayBucket.Today, DayBucket.Yesterday, DayBucket.Older), sections.map { it.bucket })
    }

    @Test fun dayBucketsUseTheLocalDate() {
        val today = LocalDate.of(2026, 9, 27)
        assertEquals(DayBucket.Today, NotificationRules.bucketFor("2026-09-27T00:30:00Z", today, ZoneOffset.UTC))
        assertEquals(DayBucket.Yesterday, NotificationRules.bucketFor("2026-09-26T23:59:00Z", today, ZoneOffset.UTC))
        assertEquals(DayBucket.Older, NotificationRules.bucketFor("2026-09-20T12:00:00Z", today, ZoneOffset.UTC))
        assertEquals(DayBucket.Today, NotificationRules.bucketFor("2026-09-26T20:00:00Z", today, ZoneOffset.ofHours(7)))
    }

    @Test fun openingMarksOnlyWhatWasShownAndKeepsTheHighlight() = runTest(dispatcher) {
        var marked = 0
        val vm = NotificationsViewModel(repo, HomeFixture.VIEWER) { marked++ }
        advanceUntilIdle()
        assertEquals(listOf(NotificationFixture.rows.first().createdAt), repo.marked)
        assertEquals(1, marked)
        assertEquals(setOf("n1", "n2", "n3", "n4"), vm.unreadSnapshot)
        // A quiet refresh (e.g. a push) keeps the highlight captured when the screen opened.
        vm.onHint(); advanceTimeBy(200); advanceUntilIdle()
        assertEquals(setOf("n1", "n2", "n3", "n4"), vm.unreadSnapshot)
        assertEquals(1, repo.marked.size)
    }

    @Test fun mentionsTabShowsOnlyMentions() = runTest(dispatcher) {
        val vm = NotificationsViewModel(repo, HomeFixture.VIEWER); advanceUntilIdle()
        vm.select(NotificationTab.Mentions)
        assertEquals(listOf("n7"), vm.visible.map { it.id })
    }

    @Test fun aFailedLoadShowsRetryAndAFailedMarkSaysSo() = runTest(dispatcher) {
        repo.failReads = true
        val vm = NotificationsViewModel(repo, HomeFixture.VIEWER); advanceUntilIdle()
        assertEquals(R.string.notifications_load_failed, vm.error?.res)
        repo.failReads = false
        repo.failWrites = true
        vm.retry(); advanceUntilIdle()
        assertEquals(R.string.notifications_mark_failed, vm.error?.res)
        assertEquals(8, vm.rows.size)
    }

    @Test fun seeMoreAppendsTheNextPage() = runTest(dispatcher) {
        repo.items = (1..45).map { NotificationItem("m$it", "follow", "2026-09-27T10:%02d:00Z".format(59 - it), actorId = "a$it") }
        val vm = NotificationsViewModel(repo, HomeFixture.VIEWER); advanceUntilIdle()
        assertTrue(vm.hasMore)
        vm.loadMore(); advanceUntilIdle()
        assertEquals(45, vm.rows.size)
        assertFalse(vm.hasMore)
    }

    @Test fun backgroundRefreshKeepsOlderPages() {
        val older = (1..40).map { NotificationItem("o$it", "follow", "2026-09-27T09:%02d:00Z".format(59 - it)) }
        val fresh = listOf(NotificationItem("new", "follow", "2026-09-27T11:00:00Z")) + older.take(29)
        val merged = mergeNewestNotificationPage(older, fresh)
        assertEquals(41, merged.size)
        assertEquals("new", merged.first().id)
    }

    @Test fun badgeClearsOnReadThenFollowsTheServer() = runTest(dispatcher) {
        val badge = UnreadBadge(repo, HomeFixture.VIEWER)
        badge.refresh(); advanceUntilIdle()
        assertEquals(3, badge.count)
        repo.unread = 1
        badge.markedRead()
        assertEquals(0, badge.count)
        advanceUntilIdle()
        assertEquals(1, badge.count)
        repo.failReads = true
        badge.refresh(); advanceUntilIdle()
        assertEquals("keeps the last known count offline", 1, badge.count)
    }
}
