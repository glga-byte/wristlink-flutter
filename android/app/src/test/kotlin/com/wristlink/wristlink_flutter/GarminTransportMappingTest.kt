package com.wristlink.wristlink_flutter

import com.garmin.android.connectiq.ConnectIQ
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class GarminTransportMappingTest {
    @Test
    fun preservesRawAcknowledgementMapsWithoutParsingContractFields() {
        val validShape = mapOf("messageId" to "not-validated-natively")
        val invalidKeyShape = mapOf(1 to "preserved-for-Dart-diagnostics")

        assertEquals(
            listOf(validShape, invalidKeyShape),
            GarminTransportMapping.rawMessageMaps(
                listOf("not-a-map", validShape, invalidKeyShape),
            ),
        )
    }

    @Test
    fun mapsEverySdkMessageStatusToTheDartTransportContract() {
        val expectedCodes = mapOf(
            ConnectIQ.IQMessageStatus.SUCCESS to null,
            ConnectIQ.IQMessageStatus.FAILURE_UNKNOWN to "nativeFailure",
            ConnectIQ.IQMessageStatus.FAILURE_INVALID_FORMAT to "nativeFailure",
            ConnectIQ.IQMessageStatus.FAILURE_MESSAGE_TOO_LARGE to "payloadTooLarge",
            ConnectIQ.IQMessageStatus.FAILURE_UNSUPPORTED_TYPE to "nativeFailure",
            ConnectIQ.IQMessageStatus.FAILURE_DURING_TRANSFER to "nativeFailure",
            ConnectIQ.IQMessageStatus.FAILURE_INVALID_DEVICE to "deviceUnavailable",
            ConnectIQ.IQMessageStatus.FAILURE_DEVICE_NOT_CONNECTED to "deviceUnavailable",
        )

        assertEquals(ConnectIQ.IQMessageStatus.values().toSet(), expectedCodes.keys)
        expectedCodes.forEach { (status, expectedCode) ->
            val error = GarminTransportMapping.errorFor(status)
            if (expectedCode == null) {
                assertNull(error)
            } else {
                assertEquals(expectedCode, error?.code)
            }
        }
    }
}
