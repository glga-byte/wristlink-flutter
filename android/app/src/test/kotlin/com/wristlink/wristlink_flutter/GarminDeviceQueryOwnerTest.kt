package com.wristlink.wristlink_flutter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GarminDeviceQueryOwnerTest {
    @Test
    fun overlappingQueriesKeepPreviousCacheVisibleUntilNewestAtomicPublish() {
        val previous = mapOf(1L to "previous-app")
        val owner = GarminDeviceQueryOwner(previous)
        val first = owner.begin()
        val second = owner.begin()

        assertEquals(previous, owner.snapshot)
        assertEquals(
            GarminDeviceQueryPublication.SUPERSEDED,
            owner.publish(first, mapOf(1L to "stale-app")),
        )
        assertEquals(previous, owner.snapshot)
        assertEquals(
            GarminDeviceQueryPublication.PUBLISHED,
            owner.publish(second, mapOf(2L to "newest-app")),
        )
        assertEquals(mapOf(2L to "newest-app"), owner.snapshot)
    }

    @Test
    fun failedQueryLeavesLastValidSendLookupSnapshotIntact() {
        val previous = mapOf(1L to "sendable-app")
        val owner = GarminDeviceQueryOwner(previous)
        val generation = owner.begin()

        assertTrue(owner.fail(generation))
        assertEquals("sendable-app", owner.snapshot[1L])
        assertFalse(owner.fail(generation))
    }

    @Test
    fun invalidatedQueryCannotPublishAStaleResult() {
        val owner = GarminDeviceQueryOwner(mapOf(1L to "previous-app"))
        val generation = owner.begin()

        owner.invalidate(emptyMap())

        assertEquals(
            GarminDeviceQueryPublication.SUPERSEDED,
            owner.publish(generation, mapOf(1L to "late-app")),
        )
        assertTrue(owner.snapshot.isEmpty())
    }

    @Test
    fun authoritativeEmptyQueryAtomicallyClearsPreviousSendLookup() {
        val owner = GarminDeviceQueryOwner(mapOf(1L to "sendable-app"))
        val generation = owner.begin()

        assertEquals(
            GarminDeviceQueryPublication.PUBLISHED,
            owner.publish(generation, emptyMap()),
        )
        assertTrue(owner.snapshot.isEmpty())
    }

    @Test
    fun deviceCallbacksRequireCurrentGenerationAndObjectIdentity() {
        val currentDevice = Any()

        assertTrue(garminDeviceCallbackIsCurrent(3, 3, currentDevice, currentDevice))
        assertFalse(garminDeviceCallbackIsCurrent(3, 3, null, currentDevice))
        assertFalse(garminDeviceCallbackIsCurrent(4, 3, currentDevice, currentDevice))
        assertFalse(garminDeviceCallbackIsCurrent(3, 3, Any(), currentDevice))
    }

    @Test
    fun appCallbacksRequireCurrentDeviceAppAndSdkGeneration() {
        val device = Any()
        val app = Any()

        assertTrue(garminAppCallbackIsCurrent(5, 5, device, device, app, app))
        assertFalse(garminAppCallbackIsCurrent(6, 5, device, device, app, app))
        assertFalse(garminAppCallbackIsCurrent(5, 5, null, device, app, app))
        assertFalse(garminAppCallbackIsCurrent(5, 5, device, device, null, app))
    }
}
