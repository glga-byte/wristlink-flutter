package com.wristlink.wristlink_flutter

import com.garmin.android.connectiq.ConnectIQ

internal data class GarminTransportError(
    val code: String,
    val message: String,
)

internal object GarminTransportMapping {
    fun rawMessageMaps(messages: List<Any>): List<Map<*, *>> {
        return messages.filterIsInstance<Map<*, *>>()
    }

    fun deliverRawMessageMaps(
        messages: List<Any>,
        deliver: (Map<*, *>) -> Unit,
    ) {
        rawMessageMaps(messages).forEach(deliver)
    }

    fun errorFor(status: ConnectIQ.IQMessageStatus): GarminTransportError? {
        return when (status) {
            ConnectIQ.IQMessageStatus.SUCCESS -> null
            ConnectIQ.IQMessageStatus.FAILURE_MESSAGE_TOO_LARGE -> GarminTransportError(
                code = "payloadTooLarge",
                message = "The Garmin app-message payload is too large.",
            )
            ConnectIQ.IQMessageStatus.FAILURE_INVALID_DEVICE,
            ConnectIQ.IQMessageStatus.FAILURE_DEVICE_NOT_CONNECTED,
            -> GarminTransportError(
                code = "deviceUnavailable",
                message = "The selected Garmin device is unavailable.",
            )
            ConnectIQ.IQMessageStatus.FAILURE_INVALID_FORMAT,
            ConnectIQ.IQMessageStatus.FAILURE_UNSUPPORTED_TYPE,
            ConnectIQ.IQMessageStatus.FAILURE_DURING_TRANSFER,
            ConnectIQ.IQMessageStatus.FAILURE_UNKNOWN,
            -> GarminTransportError(
                code = "nativeFailure",
                message = "Garmin message transport failed: $status",
            )
        }
    }
}

internal data class GarminSendArguments(
    val deviceId: String,
    val message: Map<*, *>,
) {
    companion object {
        fun from(arguments: Any?): GarminSendArguments? {
            val argumentMap = arguments as? Map<*, *> ?: return null
            val deviceId = (argumentMap["deviceId"] as? String)?.trim()
            val message = argumentMap["message"] as? Map<*, *>
            if (deviceId.isNullOrEmpty() || message == null) {
                return null
            }
            return GarminSendArguments(deviceId = deviceId, message = message)
        }
    }
}

internal object GarminNativeDeviceLookup {
    fun <Device> byRawNumericId(
        rawDeviceId: String,
        devices: Map<Long, Device>,
    ): Device? = rawDeviceId.toLongOrNull()?.let(devices::get)
}

internal fun interface GarminSendTimeout {
    fun cancel()
}

/**
 * Pure transport orchestration used by the Android bridge.
 *
 * Device/app values remain SDK-owned and opaque here. Dart still owns contract
 * validation, acknowledgement parsing, correlation, and queue policy.
 */
internal class GarminSendCoordinator<Device, App>(
    private val isSdkReady: () -> Boolean,
    private val findDevice: (String) -> Device?,
    private val findApp: (Device) -> App?,
    private val scheduleTimeout: (() -> Unit) -> GarminSendTimeout,
    private val send: (
        device: Device,
        app: App,
        message: Map<*, *>,
        completion: (GarminTransportError?) -> Unit,
    ) -> Unit,
    private val mapThrownError: (Throwable) -> GarminTransportError,
) {
    fun execute(arguments: Any?, completion: (GarminTransportError?) -> Unit) {
        val sendArguments = GarminSendArguments.from(arguments)
        if (sendArguments == null) {
            completion(
                GarminTransportError(
                    code = "nativeFailure",
                    message = "Garmin send requires a deviceId and normalized message map.",
                ),
            )
            return
        }
        if (!isSdkReady()) {
            completion(
                GarminTransportError(
                    code = "sdkUnavailable",
                    message = "Garmin Connect IQ Mobile SDK is not ready.",
                ),
            )
            return
        }
        val device = findDevice(sendArguments.deviceId)
        if (device == null) {
            completion(
                GarminTransportError(
                    code = "deviceUnavailable",
                    message = "The selected Garmin device is no longer available.",
                ),
            )
            return
        }
        val app = findApp(device)
        if (app == null) {
            completion(
                GarminTransportError(
                    code = "appNotInstalled",
                    message = "The WristLink companion app is not installed on the selected Garmin device.",
                ),
            )
            return
        }

        val oneShot = BridgeCompletion()
        val timeout = scheduleTimeout {
            oneShot.run {
                completion(
                    GarminTransportError(
                        code = "transportTimeout",
                        message = "Garmin message transport timed out.",
                    ),
                )
            }
        }
        try {
            send(device, app, sendArguments.message) { error ->
                oneShot.run {
                    timeout.cancel()
                    completion(error)
                }
            }
        } catch (error: Throwable) {
            oneShot.run {
                timeout.cancel()
                completion(mapThrownError(error))
            }
        }
    }
}
