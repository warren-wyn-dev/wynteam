package io.wyn.wyn.core.push

import io.wyn.wyn.testing.FakeDeviceToken
import io.wyn.wyn.testing.FakePushTokens
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PushControllerTest {
    private val tokens = FakePushTokens()
    private val device = FakeDeviceToken()
    private val memory = InMemoryPushMemory()
    private var allowed = true
    private val push = PushController(tokens, device, memory) { allowed }

    @Test fun enableRegistersThisPhoneForTheAccount() = runTest {
        assertEquals(PushResult.Ok, push.enable("a"))
        assertEquals("a", tokens.registered["device-token-1"])
        assertTrue(push.isWanted("a"))
    }

    @Test fun enableNeedsPermissionConfigurationAndAToken() = runTest {
        allowed = false
        assertEquals(PushResult.Blocked(PushBlock.Denied), push.enable("a"))
        allowed = true
        device.value = null
        assertEquals(PushResult.Blocked(PushBlock.NoToken), push.enable("a"))
        device.value = "t"
        tokens.fail = true
        assertEquals(PushResult.Blocked(PushBlock.ServerFailed), push.enable("a"))
        device.configured = false
        assertEquals(PushResult.Blocked(PushBlock.NotConfigured), push.enable("a"))
        assertTrue(tokens.registered.isEmpty())
    }

    @Test fun switchingAccountsDetachesFirstAndKeepsPushOnForBoth() = runTest {
        push.enable("a")
        assertTrue(push.isOnBeforeAccountChange("a"))
        assertTrue(push.detachBeforeAccountChange())
        assertTrue("the old account must stop receiving on this phone", tokens.registered.isEmpty())
        push.keepOnAcrossAccountChange("a", "b")
        push.resync("b")
        assertEquals("b", tokens.registered["device-token-1"])
        push.detachBeforeAccountChange()
        push.resync("a")
        assertEquals("a", tokens.registered["device-token-1"])
    }

    @Test fun aFailedDetachBlocksTheSwitch() = runTest {
        push.enable("a")
        tokens.fail = true
        assertFalse(push.detachBeforeAccountChange())
    }

    @Test fun anAccountThatTurnedPushOffStaysOff() = runTest {
        push.enable("b")
        assertTrue(push.disable("b"))
        assertTrue(tokens.registered.isEmpty())
        push.keepOnAcrossAccountChange("a", "b")
        push.resync("b")
        assertTrue(tokens.registered.isEmpty())
        assertEquals(1, device.deleted)
    }

    @Test fun resyncNeverRegistersWithoutPermissionOrWish() = runTest {
        push.resync("a")
        assertTrue(tokens.registered.isEmpty())
        memory.wanted = setOf("a")
        allowed = false
        push.resync("a")
        assertTrue(tokens.registered.isEmpty())
    }

    @Test fun enabledHereHealsARotatedTokenOnlyWhenWanted() = runTest {
        assertEquals(false, push.enabledHere("a"))
        memory.wanted = setOf("a")
        assertEquals(true, push.enabledHere("a"))
        tokens.fail = true
        assertNull(push.enabledHere("a"))
    }

    @Test fun promptAsksOnceAndWaitsAWeekAfterNotNow() {
        assertTrue(push.shouldPrompt("a", now = 0, canAskPermission = true))
        push.dismissPrompt(0)
        assertFalse(push.shouldPrompt("a", now = PUSH_PROMPT_COOLDOWN_MS - 1, canAskPermission = true))
        assertTrue(push.shouldPrompt("a", now = PUSH_PROMPT_COOLDOWN_MS + 1, canAskPermission = true))
        push.setChosen("a", false)
        assertFalse(push.shouldPrompt("a", now = PUSH_PROMPT_COOLDOWN_MS * 3, canAskPermission = true))
        allowed = false
        assertFalse(push.shouldPrompt("b", now = PUSH_PROMPT_COOLDOWN_MS * 3, canAskPermission = false))
    }

    @Test fun pushTargetsAcceptOnlyUuids() {
        val good = "11111111-1111-4111-8111-111111111111"
        val target = PushTarget.from(mapOf("recipient_id" to good, "type" to "like_drop", "drop_id" to "../../etc", "actor_id" to good)::get)
        assertEquals(good, target?.actorId)
        assertNull(target?.dropId)
        assertNull(PushTarget.from(mapOf("type" to "like_drop")::get))
        assertNull(PushTarget.from(mapOf("recipient_id" to good, "type" to "x y")::get))
    }
}
