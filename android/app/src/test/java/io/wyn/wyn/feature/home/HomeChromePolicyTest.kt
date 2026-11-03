package io.wyn.wyn.feature.home

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HomeChromePolicyTest {
    @Test fun staysVisibleNearTopAndOnSmallScrollCorrections() {
        val policy = HomeChromePolicy()
        assertTrue(policy.update(0, 0, false, 112))
        assertTrue(policy.update(0, 100, true, 112))
        assertTrue(policy.update(0, 113, true, 112))
        assertTrue(policy.update(0, 118, true, 112))
    }

    @Test fun deliberateDownwardSwipeHidesAndShorterUpwardSwipeRestores() {
        val policy = HomeChromePolicy()
        policy.update(0, 130, false, 112)
        assertTrue(policy.update(0, 149, true, 112))
        assertFalse(policy.update(0, 165, true, 112))
        assertFalse(policy.update(0, 159, true, 112))
        assertTrue(policy.update(0, 150, true, 112))
    }

    @Test fun returningToTopRestoresChromeEvenAfterFastPaging() {
        val policy = HomeChromePolicy()
        policy.update(0, 200, false, 112)
        assertFalse(policy.update(1, 5, true, 112))
        assertTrue(policy.update(0, 30, true, 112))
    }

    @Test fun restingNetworkRefreshDoesNotToggleVisibility() {
        val policy = HomeChromePolicy()
        policy.update(0, 200, false, 112)
        policy.update(0, 250, true, 112)
        assertFalse(policy.visible)
        assertFalse(policy.update(1, 0, false, 112))
    }
}
