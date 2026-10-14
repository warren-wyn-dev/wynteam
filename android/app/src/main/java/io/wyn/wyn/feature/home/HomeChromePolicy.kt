package io.wyn.wyn.feature.home

import kotlin.math.abs

/**
 * Native equivalent of web/components/home/home-header.tsx's scroll-direction
 * hysteresis: show both Home chrome bars near the top, hide after a deliberate
 * downward swipe, show again after a shorter upward swipe. No global/browser state.
 */
internal class HomeChromePolicy {
    private var previousIndex = 0
    private var previousOffset = 0
    private var direction = 0
    private var distance = 0
    var visible: Boolean = true
        private set

    fun update(firstIndex: Int, firstOffsetPx: Int, isScrolling: Boolean, topThresholdPx: Int): Boolean {
        val delta = when {
            firstIndex == previousIndex -> firstOffsetPx - previousOffset
            firstIndex > previousIndex -> (firstIndex - previousIndex) * 48 + firstOffsetPx - previousOffset
            else -> -(previousIndex - firstIndex) * 48 + firstOffsetPx - previousOffset
        }
        previousIndex = firstIndex
        previousOffset = firstOffsetPx

        if (firstIndex == 0 && firstOffsetPx <= topThresholdPx) {
            visible = true
            distance = 0
            direction = 0
            return visible
        }
        if (!isScrolling || abs(delta) < 1) return visible
        val nextDirection = if (delta > 0) 1 else -1
        if (nextDirection != direction) {
            direction = nextDirection
            distance = 0
        }
        distance += abs(delta)
        if (direction > 0 && distance >= 32) {
            visible = false
            distance = 0
        } else if (direction < 0 && distance >= 14) {
            visible = true
            distance = 0
        }
        return visible
    }
}
