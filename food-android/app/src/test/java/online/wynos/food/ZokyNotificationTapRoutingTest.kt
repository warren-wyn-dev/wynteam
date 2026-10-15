package online.wynos.food

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ZokyNotificationTapRoutingTest {
    @Test
    fun foregroundLocalNotificationBooleanRoutesToMessages() {
        assertTrue(ZokyNotificationTapRouting.shouldOpenMessages(true, false, true, true))
        assertFalse(ZokyNotificationTapRouting.shouldOpenMessages(true, false, false, true))
        assertFalse(ZokyNotificationTapRouting.shouldOpenMessages(true, false, true, false))
    }

    @Test
    fun backgroundFcmConsoleCustomDataStringRoutesToMessages() {
        assertTrue(ZokyNotificationTapRouting.shouldOpenMessages("true", false, true, true))
        assertTrue(ZokyNotificationTapRouting.shouldOpenMessages("TRUE", false, true, true))
        assertFalse(ZokyNotificationTapRouting.shouldOpenMessages("true", false, false, true))
        assertFalse(ZokyNotificationTapRouting.shouldOpenMessages("true", false, true, false))
    }

    @Test
    fun backgroundFcmConsoleMetadataRoutesOnlyInOptedInDebugPreview() {
        assertTrue(ZokyNotificationTapRouting.shouldOpenMessages(null, true, true, true))
        assertFalse(ZokyNotificationTapRouting.shouldOpenMessages(null, true, true, false))
        assertFalse(ZokyNotificationTapRouting.shouldOpenMessages(null, true, false, true))
    }

    @Test
    fun ordinaryLauncherAndUnrelatedDataCannotTriggerNavigation() {
        assertFalse(ZokyNotificationTapRouting.shouldOpenMessages(null, false, true, true))
        assertFalse(ZokyNotificationTapRouting.shouldOpenMessages(false, false, true, true))
        assertFalse(ZokyNotificationTapRouting.shouldOpenMessages("false", false, true, true))
        assertFalse(ZokyNotificationTapRouting.shouldOpenMessages("order", false, true, true))
        assertFalse(ZokyNotificationTapRouting.shouldOpenMessages(123, false, true, true))
    }
}
