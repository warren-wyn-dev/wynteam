package io.wyn.wyn.feature.notifications

import io.wyn.wyn.R
import io.wyn.wyn.core.push.InMemoryPushMemory
import io.wyn.wyn.core.push.PushBlock
import io.wyn.wyn.core.push.PushController
import io.wyn.wyn.testing.FakeDeviceToken
import io.wyn.wyn.testing.FakeNotificationRepository
import io.wyn.wyn.testing.FakePushTokens
import io.wyn.wyn.testing.HomeFixture
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
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

@OptIn(ExperimentalCoroutinesApi::class)
class NotificationSettingsViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val repo = FakeNotificationRepository()
    private val tokens = FakePushTokens()
    private val device = FakeDeviceToken()
    private val push = PushController(tokens, device, InMemoryPushMemory()) { true }

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    @Test fun preferencesToggleAndRollBack() = runTest(dispatcher) {
        val vm = NotificationSettingsViewModel(repo, push, HomeFixture.VIEWER); advanceUntilIdle()
        vm.toggle("likes", false); advanceUntilIdle()
        assertFalse(vm.prefs!!.likes)
        assertEquals(listOf("likes:false"), repo.writes)
        repo.failWrites = true
        vm.toggle("club", false); advanceUntilIdle()
        assertTrue(vm.prefs!!.club)
        assertEquals(R.string.notification_settings_save_failed, vm.error?.res)
    }

    @Test fun pushSwitchRegistersAndUnregistersThisPhone() = runTest(dispatcher) {
        val vm = NotificationSettingsViewModel(repo, push, HomeFixture.VIEWER); advanceUntilIdle()
        vm.checkPush(allowed = true); advanceUntilIdle()
        assertEquals(false, vm.pushEnabled)
        vm.setPush(true, allowed = true); advanceUntilIdle()
        assertEquals(true, vm.pushEnabled)
        assertEquals(HomeFixture.VIEWER, tokens.registered["device-token-1"])
        vm.setPush(false, allowed = true); advanceUntilIdle()
        assertEquals(false, vm.pushEnabled)
        assertTrue(tokens.registered.isEmpty())
    }

    @Test fun deniedAndUnconfiguredAreExplained() = runTest(dispatcher) {
        val vm = NotificationSettingsViewModel(repo, push, HomeFixture.VIEWER); advanceUntilIdle()
        vm.checkPush(allowed = false)
        assertEquals(PushBlock.Denied, vm.pushBlocked)
        vm.setPush(true, allowed = false)
        assertEquals(R.string.push_reason_denied, vm.pushError?.res)
        device.configured = false
        vm.checkPush(allowed = true)
        assertEquals(PushBlock.NotConfigured, vm.pushBlocked)
    }
}
