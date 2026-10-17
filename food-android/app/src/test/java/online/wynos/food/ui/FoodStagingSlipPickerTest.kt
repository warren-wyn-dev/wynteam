package online.wynos.food.ui

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodStagingSlipPickerTest {
    @Test fun productionAndOrdinaryApksNeverShowPreview() {
        assertFalse(shouldShowStagingSlipPreview(false, "pending_acceptance", "pending"))
    }

    @Test fun onlyUnpaidStagingOrderEligible() {
        assertTrue(shouldShowStagingSlipPreview(true, "pending_acceptance", "pending"))
        assertTrue(shouldShowStagingSlipPreview(true, "pending_acceptance", "issue"))
        assertFalse(shouldShowStagingSlipPreview(true, "pending_acceptance", "submitted"))
        assertFalse(shouldShowStagingSlipPreview(true, "pending_acceptance", "paid"))
        assertFalse(shouldShowStagingSlipPreview(true, "pending_acceptance", "refunded"))
    }

    @Test fun terminalAndOtherStatusesCannotShowPicker() {
        for (status in listOf("cancelled", "delivered", "preparing", "out_for_delivery")) {
            assertFalse(shouldShowStagingSlipPreview(true, status, "pending"))
        }
    }
}
