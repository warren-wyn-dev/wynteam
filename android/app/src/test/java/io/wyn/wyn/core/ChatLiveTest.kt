package io.wyn.wyn.core

import io.wyn.wyn.core.data.applyPresenceDiff
import org.junit.Assert.assertEquals
import org.junit.Test

class ChatLiveTest {
    @Test fun joinsAndLeavesTrackEachSession() {
        var refs = applyPresenceDiff(emptyMap(), joins = mapOf("a" to "web", "b" to "phone"), leaves = emptyMap())
        assertEquals(setOf("a", "b"), refs.keys)
        // The same person on a second device, then the first one leaves: still online.
        refs = applyPresenceDiff(refs, joins = mapOf("a" to "phone"), leaves = emptyMap())
        refs = applyPresenceDiff(refs, joins = emptyMap(), leaves = mapOf("a" to "web"))
        assertEquals(setOf("a", "b"), refs.keys)
        // Their last session leaves: offline.
        refs = applyPresenceDiff(refs, joins = emptyMap(), leaves = mapOf("a" to "phone"))
        assertEquals(setOf("b"), refs.keys)
    }

    @Test fun leavingWithoutJoiningIsIgnored() {
        assertEquals(emptySet<String>(), applyPresenceDiff(emptyMap(), joins = emptyMap(), leaves = mapOf("x" to "r")).keys)
    }
}
