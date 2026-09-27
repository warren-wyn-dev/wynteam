package io.wyn.wyn.feature.profile

import io.wyn.wyn.core.data.FollowKind
import io.wyn.wyn.testing.FakeFeedRepository
import io.wyn.wyn.testing.FakeProfileRepository
import io.wyn.wyn.testing.HomeFixture
import io.wyn.wyn.testing.ProfileFixture
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
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
class FollowListViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val profiles = FakeProfileRepository()
    private val feed = FakeFeedRepository()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    @Test fun switchesBetweenFollowersAndFollowing() = runTest(dispatcher) {
        val vm = FollowListViewModel(profiles, feed, HomeFixture.VIEWER, ProfileFixture.OTHER, FollowKind.Followers); advanceUntilIdle()
        assertEquals(2, vm.people?.size)
        vm.select(FollowKind.Following); advanceUntilIdle()
        assertEquals(1, vm.people?.size)
    }

    @Test fun followingSomeoneAndCancellingAPrivateRequestAsksFirst() = runTest(dispatcher) {
        val vm = FollowListViewModel(profiles, feed, HomeFixture.VIEWER, ProfileFixture.OTHER, FollowKind.Followers); advanceUntilIdle()
        vm.follow(vm.people!![1])
        assertEquals("p2", vm.confirmCancel?.id)
        assertTrue(feed.writes.isEmpty())
        vm.follow(vm.people!![1], confirmed = true); advanceUntilIdle()
        assertEquals(listOf("follow:p2"), feed.writes)
    }

    @Test fun neverFollowsYourself() = runTest(dispatcher) {
        profiles.followers = listOf(ProfileFixture.people[0].copy(id = HomeFixture.VIEWER))
        val vm = FollowListViewModel(profiles, feed, HomeFixture.VIEWER, ProfileFixture.OTHER, FollowKind.Followers); advanceUntilIdle()
        vm.follow(vm.people!![0]); advanceUntilIdle()
        assertTrue(feed.writes.isEmpty())
    }
}
