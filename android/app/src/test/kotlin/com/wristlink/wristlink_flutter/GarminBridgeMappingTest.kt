package com.wristlink.wristlink_flutter

import org.junit.Assert.assertEquals
import org.junit.Test

class GarminBridgeMappingTest {
    @Test
    fun mapsCompanionStatusFromExactEnumTokens() {
        val cases = mapOf(
            "INSTALLED" to "installed",
            "NOT_INSTALLED" to "missing",
            "NOT_SUPPORTED" to "missing",
            "UNKNOWN" to "unknown",
            null to "unknown",
            "com.garmin.android.connectiq.IQApp.IQAppStatus.NOT_INSTALLED" to "missing",
        )

        cases.forEach { (status, expected) ->
            assertEquals(expected, GarminBridgeMapping.mapCompanionStatus(status))
        }
    }

    @Test
    fun mapsReachabilityFromExactEnumTokens() {
        val cases = mapOf(
            "CONNECTED" to "reachable",
            "NOT_CONNECTED" to "offline",
            "NOT_PAIRED" to "offline",
            "UNKNOWN" to "unknown",
            null to "unknown",
            "com.garmin.android.connectiq.IQDevice.IQDeviceStatus.NOT_CONNECTED" to "offline",
        )

        cases.forEach { (status, expected) ->
            assertEquals(expected, GarminBridgeMapping.mapReachability(status))
        }
    }

    @Test
    fun completesCompanionStatesForEveryLatestDevice() {
        val latestStates = GarminBridgeMapping.completeCompanionStates(
            deviceIds = listOf(1L, 2L, 3L),
            resolvedStates = mapOf(
                1L to "installed",
                3L to "missing",
                99L to "installed",
            ),
        )

        assertEquals(
            mapOf(
                1L to "installed",
                2L to "unknown",
                3L to "missing",
            ),
            latestStates,
        )
    }

    @Test
    fun buildsDevicePayloadWithSharedMetadataKeys() {
        val payload = GarminBridgeMapping.devicePayload(
            id = "123",
            name = "Forerunner",
            modelName = "Forerunner 965",
            family = "006-B1234-00",
            unitId = "123",
            nativeStatus = "CONNECTED",
            companionInstallState = "installed",
        )

        assertEquals("123", payload["id"])
        assertEquals("Forerunner", payload["name"])
        assertEquals("Forerunner 965", payload["modelName"])
        assertEquals("006-B1234-00", payload["family"])
        assertEquals("123", payload["unitId"])
        assertEquals("reachable", payload["reachability"])
        assertEquals("installed", payload["companionInstallState"])
    }

    @Test
    fun buildsDevicePayloadWithStableFallbackName() {
        val payload = GarminBridgeMapping.devicePayload(
            id = "123",
            name = " ",
            modelName = null,
            family = null,
            unitId = "123",
            nativeStatus = "UNKNOWN",
            companionInstallState = "unknown",
        )

        assertEquals("Garmin device", payload["name"])
        assertEquals(null, payload["modelName"])
        assertEquals(null, payload["family"])
        assertEquals("unknown", payload["reachability"])
    }

    @Test
    fun exposesStableNativeDiscoveryFailureMessage() {
        assertEquals(
            "Garmin device discovery failed.",
            GarminBridgeMapping.NATIVE_DISCOVERY_FAILURE_MESSAGE,
        )
    }
}
