package com.wristlink.wristlink_flutter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GarminBridgeCompletionTest {
    @Test
    fun runsCompletionOnlyOnce() {
        val completion = BridgeCompletion()
        var count = 0

        assertTrue(completion.run { count += 1 })
        assertFalse(completion.run { count += 1 })

        assertEquals(1, count)
        assertTrue(completion.isCompleted)
    }

    @Test
    fun ignoresStaleRequestIdWithoutCompleting() {
        val completion = BridgeCompletion(requestId = 7)
        var count = 0

        assertFalse(completion.run(requestId = 6) { count += 1 })
        assertEquals(0, count)
        assertFalse(completion.isCompleted)

        assertTrue(completion.run(requestId = 7) { count += 1 })
        assertEquals(1, count)
        assertTrue(completion.isCompleted)
    }

    @Test
    fun ignoresDuplicateMatchingRequestIdAfterCompletion() {
        val completion = BridgeCompletion(requestId = 7)
        var count = 0

        assertTrue(completion.run(requestId = 7) { count += 1 })
        assertFalse(completion.run(requestId = 7) { count += 1 })

        assertEquals(1, count)
    }
}
