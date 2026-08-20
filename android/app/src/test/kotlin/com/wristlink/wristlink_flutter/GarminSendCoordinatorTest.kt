package com.wristlink.wristlink_flutter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class GarminSendCoordinatorTest {
    @Test
    fun validatesSendArgumentsBeforeAnySdkLookup() {
        val invalidArguments = listOf(
            null,
            "not-a-map",
            emptyMap<String, Any>(),
            mapOf("deviceId" to "watch-1"),
            mapOf("deviceId" to " ", "message" to emptyMap<String, Any>()),
            mapOf("deviceId" to "watch-1", "message" to "not-a-map"),
        )

        invalidArguments.forEach { arguments ->
            val harness = Harness()

            harness.execute(arguments)

            assertEquals("nativeFailure", harness.completions.single()?.code)
            assertEquals(0, harness.deviceLookupCount)
            assertEquals(0, harness.appLookupCount)
            assertFalse(harness.sendInvoked)
        }
    }

    @Test
    fun mapsSdkDeviceAndAppLookupFailuresWithoutSending() {
        val sdkUnavailable = Harness(sdkReady = false)
        sdkUnavailable.execute(validArguments())
        assertEquals("sdkUnavailable", sdkUnavailable.completions.single()?.code)
        assertEquals(0, sdkUnavailable.deviceLookupCount)

        val missingDevice = Harness(device = null)
        missingDevice.execute(validArguments())
        assertEquals("deviceUnavailable", missingDevice.completions.single()?.code)
        assertEquals(listOf("watch-1"), missingDevice.lookedUpDeviceIds)
        assertEquals(0, missingDevice.appLookupCount)

        val missingApp = Harness(app = null)
        missingApp.execute(validArguments())
        assertEquals("appNotInstalled", missingApp.completions.single()?.code)
        assertEquals(1, missingApp.deviceLookupCount)
        assertEquals(1, missingApp.appLookupCount)

        assertFalse(sdkUnavailable.sendInvoked)
        assertFalse(missingDevice.sendInvoked)
        assertFalse(missingApp.sendInvoked)
    }

    @Test
    fun successfulCallbackSendsNormalizedMapAndCompletesOnce() {
        val message = mapOf<String, Any>("v" to 1, "kind" to "point")
        val harness = Harness()

        harness.execute(validArguments(message))
        harness.callback(null)

        assertTrue(harness.sendInvoked)
        assertSame(message, harness.sentMessage)
        assertEquals(listOf<GarminTransportError?>(null), harness.completions)
        assertEquals(1, harness.timeout.cancelCount)
    }

    @Test
    fun deliversEveryMappedSdkFailureIncludingTooLarge() {
        ConnectIQStatusCases.all.forEach { (status, expectedCode) ->
            val harness = Harness()
            harness.execute(validArguments())

            harness.callback(GarminTransportMapping.errorFor(status))

            assertEquals(expectedCode, harness.completions.single()?.code)
        }

        val tooLarge = GarminTransportMapping.errorFor(
            com.garmin.android.connectiq.ConnectIQ.IQMessageStatus.FAILURE_MESSAGE_TOO_LARGE,
        )
        assertEquals("payloadTooLarge", tooLarge?.code)
    }

    @Test
    fun duplicateSdkCallbacksCompleteExactlyOnce() {
        val harness = Harness()
        harness.execute(validArguments())

        harness.callback(null)
        harness.callback(GarminTransportError("nativeFailure", "late failure"))

        assertEquals(listOf<GarminTransportError?>(null), harness.completions)
        assertEquals(1, harness.timeout.cancelCount)
    }

    @Test
    fun timeoutWinsRaceAndLateCallbackCannotCompleteAgain() {
        val harness = Harness()
        harness.execute(validArguments())

        harness.timeout.fire()
        harness.callback(null)

        assertEquals(1, harness.completions.size)
        assertEquals("transportTimeout", harness.completions.single()?.code)
        assertTrue(harness.completions.single()?.message?.contains("timed out") == true)
        assertEquals(0, harness.timeout.cancelCount)
    }

    @Test
    fun thrownSendFailureCancelsTimeoutAndCompletesExactlyOnce() {
        val harness = Harness(thrownError = IllegalStateException("boom"))

        harness.execute(validArguments())
        harness.timeout.fire()

        assertEquals("sdkUnavailable", harness.completions.single()?.code)
        assertEquals(1, harness.timeout.cancelCount)
    }

    @Test
    fun rawAcknowledgementsAreDeliveredUnparsedIncludingDuplicates() {
        val first = mapOf<Any, Any>("id" to "ack-1", 7 to "invalid-key-for-Dart")
        val duplicate = first
        val delivered = mutableListOf<Map<*, *>>()

        GarminTransportMapping.deliverRawMessageMaps(
            listOf("ignored", first, duplicate),
            delivered::add,
        )

        assertEquals(listOf(first, duplicate), delivered)
    }

    @Test
    fun androidDiscoveryIdResolvesTheMatchingNumericNativeCacheEntry() {
        val fixture = loadRoundTripFixture("android")
        val discoveryPayload = GarminBridgeMapping.devicePayload(
            id = fixture.rawDeviceId,
            name = "Forerunner 965",
            modelName = "Forerunner 965",
            family = "006-B4444-00",
            unitId = fixture.rawDeviceId,
            nativeStatus = "CONNECTED",
            companionInstallState = "installed",
        )
        assertEquals(fixture.discoveryDeviceId, discoveryPayload["id"])
        assertEquals("physical:${discoveryPayload["id"]}", fixture.canonicalDeviceId)

        val cachedDevice = Any()
        val cachedApp = Any()
        val deviceCache = mapOf(fixture.rawDeviceId.toLong() to cachedDevice)
        var sentDevice: Any? = null
        val coordinator = GarminSendCoordinator<Any, Any>(
            isSdkReady = { true },
            findDevice = { rawDeviceId ->
                GarminNativeDeviceLookup.byRawNumericId(rawDeviceId, deviceCache)
            },
            findApp = { cachedApp },
            scheduleTimeout = { GarminSendTimeout {} },
            send = { device, _, _, completion ->
                sentDevice = device
                completion(null)
            },
            mapThrownError = {
                GarminTransportError("nativeFailure", "unexpected")
            },
        )

        coordinator.execute(
            mapOf("deviceId" to fixture.rawDeviceId, "message" to mapOf("v" to 1)),
        ) { error -> assertNull(error) }

        assertSame(cachedDevice, sentDevice)
    }

    private fun validArguments(
        message: Map<String, Any> = mapOf("v" to 1),
    ): Map<String, Any> = mapOf("deviceId" to "watch-1", "message" to message)

    private class Harness(
        private val sdkReady: Boolean = true,
        private val device: String? = "device",
        private val app: String? = "app",
        private val thrownError: Throwable? = null,
    ) {
        val completions = mutableListOf<GarminTransportError?>()
        val lookedUpDeviceIds = mutableListOf<String>()
        val timeout = FakeTimeout()
        var deviceLookupCount = 0
        var appLookupCount = 0
        var sendInvoked = false
        var sentMessage: Map<*, *>? = null
        private var sendCallback: ((GarminTransportError?) -> Unit)? = null

        private val coordinator = GarminSendCoordinator<String, String>(
            isSdkReady = { sdkReady },
            findDevice = { deviceId ->
                deviceLookupCount += 1
                lookedUpDeviceIds += deviceId
                device
            },
            findApp = {
                appLookupCount += 1
                app
            },
            scheduleTimeout = { callback ->
                timeout.callback = callback
                timeout
            },
            send = { _, _, message, callback ->
                sendInvoked = true
                sentMessage = message
                sendCallback = callback
                thrownError?.let { throw it }
            },
            mapThrownError = {
                GarminTransportError("sdkUnavailable", "mapped exception")
            },
        )

        fun execute(arguments: Any?) {
            coordinator.execute(arguments, completions::add)
        }

        fun callback(error: GarminTransportError?) {
            sendCallback?.invoke(error)
        }
    }

    private class FakeTimeout : GarminSendTimeout {
        var callback: (() -> Unit)? = null
        var cancelCount = 0

        override fun cancel() {
            cancelCount += 1
        }

        fun fire() {
            callback?.invoke()
        }
    }
}

private data class RoundTripFixture(
    val rawDeviceId: String,
    val canonicalDeviceId: String,
    val discoveryDeviceId: String,
)

private fun loadRoundTripFixture(platform: String): RoundTripFixture {
    val workingDirectory = System.getProperty("user.dir")
        ?: error("Missing JVM working directory while loading Garmin fixture.")
    val fixtureFile = generateSequence(File(workingDirectory)) { it.parentFile }
        .map { File(it, "test/fixtures/garmin_device_id_round_trip.json") }
        .firstOrNull(File::isFile)
        ?: error("Could not locate the shared Garmin device-id round-trip fixture.")
    val fixtureText = fixtureFile.readText()
    val caseText = fixtureText.substringAfter("\"platform\": \"$platform\"")
        .substringBefore("\"platform\": \"")

    fun field(name: String): String = Regex("\"$name\"\\s*:\\s*\"([^\"]+)\"")
        .find(caseText)
        ?.groupValues
        ?.get(1)
        ?: error("Missing $name in $platform round-trip fixture.")

    return RoundTripFixture(
        rawDeviceId = field("rawDeviceId"),
        canonicalDeviceId = field("canonicalDeviceId"),
        discoveryDeviceId = field("id"),
    )
}

private object ConnectIQStatusCases {
    val all = com.garmin.android.connectiq.ConnectIQ.IQMessageStatus.values().associateWith {
        GarminTransportMapping.errorFor(it)?.code
    }
}
