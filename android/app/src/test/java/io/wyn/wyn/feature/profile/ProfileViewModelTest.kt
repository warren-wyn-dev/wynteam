package io.wyn.wyn.feature.profile

import io.wyn.wyn.R
import io.wyn.wyn.core.data.ProfileTab
import io.wyn.wyn.testing.FakeFeedRepository
import io.wyn.wyn.testing.FakeProfileRepository
import io.wyn.wyn.testing.HomeFixture
import io.wyn.wyn.testing.ProfileFixture
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
class ProfileViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val profiles = FakeProfileRepository()
    private val feed = FakeFeedRepository()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    private fun TestScope.open(id: String = ProfileFixture.OTHER) =
        ProfileViewModel(profiles, feed, HomeFixture.VIEWER, id).also { advanceUntilIdle() }

    @Test fun loadsSummaryPostsAndSuggestions() = runTest(dispatcher) {
        val vm = open()
        assertEquals("mint", vm.summary?.profile?.username)
        assertEquals(2, vm.snapshot?.rows?.size)
        assertEquals(2, vm.suggestions.size)
        assertFalse(vm.own)
        vm.select(ProfileTab.Reposts); advanceUntilIdle()
        assertTrue(vm.snapshot!!.rows.isEmpty())
    }

    @Test fun ownProfileHasNoSuggestions() = runTest(dispatcher) {
        val vm = open(HomeFixture.VIEWER)
        assertTrue(vm.own)
        assertTrue(vm.suggestions.isEmpty())
    }

    @Test fun anUnknownProfileIsNotFound() = runTest(dispatcher) {
        val vm = open("missing")
        assertNull(vm.summary)
        assertTrue(vm.summaryFailed)
    }

    @Test fun followIsOptimisticAndRollsBack() = runTest(dispatcher) {
        val vm = open()
        feed.failWrites = true
        vm.follow()
        assertTrue(vm.summary!!.following)
        assertEquals(13, vm.summary!!.followerCount)
        advanceUntilIdle()
        assertFalse(vm.summary!!.following)
        assertEquals(12, vm.summary!!.followerCount)
        assertEquals(R.string.profile_follow_failed, vm.actionError?.res)
    }

    @Test fun cancellingARequestToAPrivateAccountAsksFirst() = runTest(dispatcher) {
        profiles.summaries[ProfileFixture.OTHER] = ProfileFixture.other.copy(
            profile = ProfileFixture.other.profile.copy(isPrivate = true), requested = true,
        )
        val vm = open()
        vm.follow()
        assertEquals(ProfileConfirm.CancelRequest, vm.confirm)
        assertTrue(feed.writes.isEmpty())
        vm.follow(confirmed = true); advanceUntilIdle()
        assertEquals(listOf("follow:${ProfileFixture.OTHER}"), feed.writes)
    }

    @Test fun blockingAsksFirstAndUnblockDoesNot() = runTest(dispatcher) {
        val vm = open()
        vm.block()
        assertEquals(ProfileConfirm.Block, vm.confirm)
        vm.block(confirmed = true); advanceUntilIdle()
        assertTrue(vm.summary!!.blocked)
        vm.block(); advanceUntilIdle()
        assertFalse(vm.summary!!.blocked)
        assertEquals(listOf("block:${ProfileFixture.OTHER}:true", "block:${ProfileFixture.OTHER}:false"), profiles.writes)
    }

    @Test fun muteAndReport() = runTest(dispatcher) {
        val vm = open()
        vm.toggleMute(); advanceUntilIdle()
        vm.openProfileSheet(ProfileSheet.Report)
        vm.chooseReportReason("other")
        vm.submitProfileReport(); advanceUntilIdle()
        assertEquals(R.string.report_detail_required, vm.sheetError?.res)
        vm.updateReportText(" ปลอมตัว ")
        vm.submitProfileReport(); advanceUntilIdle()
        assertEquals(listOf("mute:${ProfileFixture.OTHER}:true", "report:${ProfileFixture.OTHER}:other:ปลอมตัว"), profiles.writes)
        assertNull(vm.profileSheet)
    }

    @Test fun ownProfileCannotFollowBlockOrReportItself() = runTest(dispatcher) {
        val vm = open(HomeFixture.VIEWER)
        vm.follow(); vm.block(confirmed = true); vm.toggleMute(); vm.submitProfileReport(); advanceUntilIdle()
        assertTrue(feed.writes.isEmpty())
        assertTrue(profiles.writes.isEmpty())
    }

    @Test fun hiddenLikesShowTheOwnersChoice() = runTest(dispatcher) {
        profiles.likesAllowed = false
        val vm = open()
        assertFalse(vm.likesAllowed)
    }

    @Test fun suggestionsFollowAndDismiss() = runTest(dispatcher) {
        val vm = open()
        val first = vm.suggestions.first()
        vm.followSuggestion(first); advanceUntilIdle()
        assertTrue(vm.suggestions.first().following)
        val private = vm.suggestions[1]
        vm.followSuggestion(private)
        assertTrue(vm.confirm is ProfileConfirm.CancelSuggestionRequest)
        vm.dismissSuggestion(private); advanceUntilIdle()
        assertEquals(1, vm.suggestions.size)
        assertEquals(listOf("dismiss:p2"), profiles.writes)
    }

    @Test fun shareLinkUsesTheUsername() = runTest(dispatcher) {
        assertEquals("https://wynos.online/@mint", open().profileUrl())
    }
}
