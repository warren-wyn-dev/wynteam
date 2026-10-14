package online.wynos.merchant

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OrderRulesTest {
    private val now = 1_800_000_000_000L

    @Test fun deliveredIsVisibleWithin24Hours() {
        assertTrue(terminalWithin24h("delivered", now - 1, now))
        assertTrue(terminalWithin24h("delivered", now - 86_399_999, now))
    }

    @Test fun completedOrdersDisappearAt24HourBoundary() {
        assertFalse(terminalWithin24h("delivered", now - 86_400_000, now))
        assertFalse(terminalWithin24h("cancelled", now - 86_400_001, now))
    }

    @Test fun cancelledCanAppearFor24Hours() {
        assertTrue(terminalWithin24h("cancelled", now - 10_000, now))
    }

    @Test fun liveOrdersNeverUseTerminalExpiry() {
        for (status in listOf("pending_acceptance", "preparing", "ready_for_delivery", "out_for_delivery")) {
            assertFalse(terminalWithin24h(status, now - 500, now))
        }
    }

    @Test fun missingAndFutureCompletionAreNotVisible() {
        assertFalse(terminalWithin24h("delivered", null, now))
        assertFalse(terminalWithin24h("cancelled", now + 1, now))
    }
}
