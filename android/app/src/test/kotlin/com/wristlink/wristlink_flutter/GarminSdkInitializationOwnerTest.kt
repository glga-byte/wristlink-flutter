package com.wristlink.wristlink_flutter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GarminSdkInitializationOwnerTest {
    @Test
    fun hydrationStartsSilentlyAndConcurrentHydrationJoins() {
        val owner = GarminSdkInitializationOwner()

        val start = owner.admit(GarminDeviceRequest.TRANSPORT_HYDRATION)
            as GarminSdkInitializationAdmission.Start

        assertFalse(start.initializeWithUserInterface)
        assertEquals(
            GarminSdkInitializationAdmission.Join,
            owner.admit(GarminDeviceRequest.TRANSPORT_HYDRATION),
        )
        assertTrue(owner.markReady(start.requestId))
        assertTrue(owner.isReady)
        assertEquals(
            GarminSdkInitializationAdmission.Ready,
            owner.admit(GarminDeviceRequest.TRANSPORT_HYDRATION),
        )
    }

    @Test
    fun hydrationNeverJoinsInteractiveDiscoveryInitialization() {
        val owner = GarminSdkInitializationOwner()
        val start = owner.admit(GarminDeviceRequest.DISCOVERY)
            as GarminSdkInitializationAdmission.Start

        assertTrue(start.initializeWithUserInterface)
        assertEquals(
            GarminSdkInitializationAdmission.Unavailable,
            owner.admit(GarminDeviceRequest.TRANSPORT_HYDRATION),
        )
    }

    @Test
    fun timeoutKeepsSingleInitOwnershipAndLateReadyReconciles() {
        val owner = GarminSdkInitializationOwner()
        val start = owner.admit(GarminDeviceRequest.TRANSPORT_HYDRATION)
            as GarminSdkInitializationAdmission.Start

        assertTrue(owner.markTimedOut(start.requestId))
        assertEquals(
            GarminSdkInitializationAdmission.Unavailable,
            owner.admit(GarminDeviceRequest.TRANSPORT_HYDRATION),
        )
        assertTrue(owner.markReady(start.requestId))
        assertTrue(owner.isReady)
        assertEquals(
            GarminSdkInitializationAdmission.Ready,
            owner.admit(GarminDeviceRequest.TRANSPORT_HYDRATION),
        )
    }

    @Test
    fun timedOutFailureAllowsOneFreshInitializationAndRejectsLateCallback() {
        val owner = GarminSdkInitializationOwner()
        val first = owner.admit(GarminDeviceRequest.TRANSPORT_HYDRATION)
            as GarminSdkInitializationAdmission.Start

        assertTrue(owner.markTimedOut(first.requestId))
        assertTrue(owner.markFailed(first.requestId))
        val second = owner.admit(GarminDeviceRequest.TRANSPORT_HYDRATION)
            as GarminSdkInitializationAdmission.Start

        assertFalse(owner.markReady(first.requestId))
        assertTrue(owner.markReady(second.requestId))
    }

    @Test
    fun staleShutdownCannotResetNewInitializationButCurrentShutdownCan() {
        val owner = GarminSdkInitializationOwner()
        val first = owner.admit(GarminDeviceRequest.TRANSPORT_HYDRATION)
            as GarminSdkInitializationAdmission.Start
        assertTrue(owner.markFailed(first.requestId))
        val second = owner.admit(GarminDeviceRequest.TRANSPORT_HYDRATION)
            as GarminSdkInitializationAdmission.Start

        assertFalse(owner.markShutDown(first.requestId))
        assertTrue(owner.markReady(second.requestId))
        assertTrue(owner.isReady)
        assertTrue(owner.markShutDown(second.requestId))
        assertFalse(owner.isReady)
        assertFalse(owner.markShutDown(second.requestId))
    }
}
