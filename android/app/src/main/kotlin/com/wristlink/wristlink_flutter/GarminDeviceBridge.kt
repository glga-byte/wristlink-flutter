package com.wristlink.wristlink_flutter

import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.garmin.android.connectiq.ConnectIQ
import com.garmin.android.connectiq.IQApp
import com.garmin.android.connectiq.IQDevice
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

internal class GarminDeviceBridge(
    private val context: Context,
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
) {
    private var connectIq: ConnectIQ? = null
    private var sdkReady = false
    private var sdkInitializing = false
    private var sdkInitRequestId = 0
    private val pendingDiscoveryResults = mutableListOf<MethodChannel.Result>()
    private val companionStates = mutableMapOf<Long, String>()
    private val registeredDeviceEventIds = mutableSetOf<Long>()
    private var deviceEventSink: EventChannel.EventSink? = null
    private var sdkInitTimeout: Runnable? = null
    private var sdkInitCompletion: BridgeCompletion? = null

    fun register(binaryMessenger: BinaryMessenger) {
        MethodChannel(binaryMessenger, GARMIN_DEVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "discoverDevices" -> discoverDevices(result)
                else -> result.notImplemented()
            }
        }
        EventChannel(binaryMessenger, GARMIN_DEVICE_EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    deviceEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    deviceEventSink = null
                }
            },
        )
    }

    private fun discoverDevices(result: MethodChannel.Result) {
        if (!isPackageInstalled(GARMIN_CONNECT_PACKAGE) && !isPackageInstalled(GARMIN_CONNECT_IQ_PACKAGE)) {
            result.error(
                "garminConnectMissing",
                "Garmin Connect or Connect IQ is not installed.",
                null,
            )
            return
        }

        val currentConnectIq = connectIq ?: try {
            ConnectIQ.getInstance(context.applicationContext, ConnectIQ.IQConnectType.WIRELESS)
        } catch (_: Throwable) {
            null
        }

        if (currentConnectIq == null) {
            result.error(
                "sdkUnavailable",
                "Garmin Connect IQ Mobile SDK is unavailable.",
                null,
            )
            return
        }
        connectIq = currentConnectIq

        if (sdkReady) {
            queryDevices(currentConnectIq, result)
            return
        }

        pendingDiscoveryResults.add(result)
        if (sdkInitializing) {
            return
        }
        sdkInitializing = true
        sdkInitRequestId += 1
        val requestId = sdkInitRequestId
        sdkInitCompletion = BridgeCompletion(requestId)

        val timeout = Runnable {
            completeSdkInitialization(requestId, ready = false) { pendingResult ->
                connectIq = null
                pendingResult.error(
                    "timeout",
                    "Garmin Connect IQ SDK initialization timed out.",
                    null,
                )
            }
        }
        sdkInitTimeout = timeout
        mainHandler.postDelayed(timeout, SDK_INIT_TIMEOUT_MS)

        currentConnectIq.initialize(context.applicationContext, true, object : ConnectIQ.ConnectIQListener {
            override fun onSdkReady() {
                mainHandler.post {
                    val pendingResults = completeSdkInitialization(requestId, ready = true) {
                        // Results are completed below after SDK state is updated.
                    }
                    pendingResults.forEach { pendingResult ->
                        queryDevices(currentConnectIq, pendingResult)
                    }
                }
            }

            override fun onInitializeError(status: ConnectIQ.IQSdkErrorStatus) {
                mainHandler.post {
                    val code = when (status) {
                        ConnectIQ.IQSdkErrorStatus.GCM_NOT_INSTALLED -> "garminConnectMissing"
                        else -> "sdkUnavailable"
                    }
                    completeSdkInitialization(requestId, ready = false) { pendingResult ->
                        connectIq = null
                        pendingResult.error(
                            code,
                            "Garmin Connect IQ SDK initialization failed: $status",
                            null,
                        )
                    }
                }
            }

            override fun onSdkShutDown() {
                mainHandler.post {
                    sdkReady = false
                    sdkInitializing = false
                    sdkInitRequestId += 1
                    sdkInitCompletion = null
                    connectIq = null
                    registeredDeviceEventIds.clear()
                }
            }
        })
    }

    private fun completeSdkInitialization(
        requestId: Int,
        ready: Boolean,
        complete: (MethodChannel.Result) -> Unit,
    ): List<MethodChannel.Result> {
        val sdkCompletion = sdkInitCompletion ?: return emptyList()
        var pendingResults = emptyList<MethodChannel.Result>()
        val completed = sdkCompletion.run(requestId) {
            sdkInitCompletion = null
            sdkInitRequestId += 1
            sdkInitTimeout?.let { mainHandler.removeCallbacks(it) }
            sdkInitTimeout = null
            sdkInitializing = false
            sdkReady = ready
            pendingResults = drainPendingDiscoveryResults()
            pendingResults.forEach(complete)
        }
        return if (completed) pendingResults else emptyList()
    }

    private fun drainPendingDiscoveryResults(): List<MethodChannel.Result> {
        val pendingResults = pendingDiscoveryResults.toList()
        pendingDiscoveryResults.clear()
        return pendingResults
    }

    private fun queryDevices(connectIq: ConnectIQ, result: MethodChannel.Result) {
        try {
            val knownDevices = connectIq.getKnownDevices()
            if (knownDevices.isEmpty()) {
                result.error(
                    "noAuthorizedDevices",
                    "No authorized Garmin devices were returned.",
                    null,
                )
                return
            }

            val appId = connectIqAppId()
            if (appId == null) {
                val latestStates = GarminBridgeMapping.completeCompanionStates(
                    knownDevices.map { it.deviceIdentifier },
                    emptyMap(),
                )
                replaceCompanionStates(latestStates)
                result.success(knownDevices.map { device ->
                    registerForDeviceEvents(connectIq, device)
                    mapDevice(
                        connectIq,
                        device,
                        latestStates[device.deviceIdentifier]
                            ?: GarminBridgeMapping.UNKNOWN_COMPANION_STATE,
                    )
                })
                return
            }

            queryCompanionStates(connectIq, knownDevices, appId, result)
        } catch (error: Throwable) {
            Log.w(TAG, "Garmin device discovery failed.", error)
            result.error(
                "nativeFailure",
                GarminBridgeMapping.NATIVE_DISCOVERY_FAILURE_MESSAGE,
                null,
            )
        }
    }

    private fun queryCompanionStates(
        connectIq: ConnectIQ,
        devices: List<IQDevice>,
        appId: String,
        result: MethodChannel.Result,
    ) {
        val states = mutableMapOf<Long, String>()
        var remaining = devices.size
        val completion = BridgeCompletion()

        fun finish() {
            completion.run {
                val latestStates = GarminBridgeMapping.completeCompanionStates(
                    devices.map { it.deviceIdentifier },
                    states,
                )
                replaceCompanionStates(latestStates)
                result.success(devices.map { device ->
                    registerForDeviceEvents(connectIq, device)
                    mapDevice(
                        connectIq,
                        device,
                        latestStates[device.deviceIdentifier]
                            ?: GarminBridgeMapping.UNKNOWN_COMPANION_STATE,
                    )
                })
            }
        }

        lateinit var timeout: Runnable

        fun recordState(device: IQDevice, companionState: String) {
            if (completion.isCompleted) return
            states[device.deviceIdentifier] = companionState
            remaining -= 1
            if (remaining == 0) {
                mainHandler.removeCallbacks(timeout)
                finish()
            }
        }

        timeout = Runnable { finish() }
        mainHandler.postDelayed(timeout, COMPANION_STATUS_TIMEOUT_MS)

        devices.forEach { device ->
            try {
                connectIq.getApplicationInfo(
                    appId,
                    device,
                    object : ConnectIQ.IQApplicationInfoListener {
                        override fun onApplicationInfoReceived(app: IQApp) {
                            mainHandler.post {
                                recordState(
                                    device,
                                    GarminBridgeMapping.mapCompanionStatus(app.status?.name),
                                )
                            }
                        }

                        override fun onApplicationNotInstalled(applicationId: String) {
                            mainHandler.post {
                                recordState(device, "missing")
                            }
                        }
                    },
                )
            } catch (_: Throwable) {
                mainHandler.post {
                    recordState(device, GarminBridgeMapping.UNKNOWN_COMPANION_STATE)
                }
            }
        }
    }

    private fun mapDevice(
        connectIq: ConnectIQ,
        device: IQDevice,
        companionInstallState: String,
        statusOverride: String? = null,
    ): Map<String, Any?> {
        val status = statusOverride ?: try {
            connectIq.getDeviceStatus(device).toString()
        } catch (_: Throwable) {
            device.status?.toString()
        }
        val family = try {
            connectIq.getDevicePartNumber(device)
        } catch (_: Throwable) {
            null
        }

        return GarminBridgeMapping.devicePayload(
            id = device.deviceIdentifier.toString(),
            name = device.friendlyName,
            modelName = null,
            family = family,
            unitId = device.deviceIdentifier.toString(),
            nativeStatus = status,
            companionInstallState = companionInstallState,
        )
    }

    private fun registerForDeviceEvents(connectIq: ConnectIQ, device: IQDevice) {
        if (device.deviceIdentifier in registeredDeviceEventIds) {
            return
        }
        try {
            connectIq.registerForDeviceEvents(
                device,
                object : ConnectIQ.IQDeviceEventListener {
                    override fun onDeviceStatusChanged(
                        device: IQDevice,
                        status: IQDevice.IQDeviceStatus,
                    ) {
                        mainHandler.post {
                            emitDeviceUpdate(connectIq, device, status.toString())
                        }
                    }
                },
            )
            registeredDeviceEventIds.add(device.deviceIdentifier)
        } catch (_: Throwable) {
            // Discovery still succeeds if live status events are unavailable.
        }
    }

    private fun emitDeviceUpdate(connectIq: ConnectIQ, device: IQDevice, status: String) {
        val companionInstallState =
            companionStates[device.deviceIdentifier]
                ?: GarminBridgeMapping.UNKNOWN_COMPANION_STATE
        deviceEventSink?.success(
            mapDevice(
                connectIq,
                device,
                companionInstallState,
                statusOverride = status,
            ),
        )
    }

    private fun replaceCompanionStates(latestStates: Map<Long, String>) {
        companionStates.keys.retainAll(latestStates.keys)
        companionStates.putAll(latestStates)
    }

    private fun connectIqAppId(): String? {
        val metadata = context.packageManager.getApplicationInfo(
            context.packageName,
            PackageManager.GET_META_DATA,
        ).metaData
        val value = metadata?.getString(CONNECT_IQ_APP_ID_META_DATA)?.trim().orEmpty()
        return value.takeUnless {
            it.isEmpty() || it == CONNECT_IQ_APP_ID_PLACEHOLDER
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            context.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private companion object {
        const val GARMIN_DEVICE_CHANNEL = "wristlink/garmin_devices"
        const val GARMIN_DEVICE_EVENTS_CHANNEL = "wristlink/garmin_device_events"
        const val GARMIN_CONNECT_PACKAGE = "com.garmin.android.apps.connectmobile"
        const val GARMIN_CONNECT_IQ_PACKAGE = "com.garmin.connectiq"
        const val TAG = "WristLinkGarminBridge"
        const val CONNECT_IQ_APP_ID_META_DATA = "com.wristlink.CONNECT_IQ_APP_ID"
        const val CONNECT_IQ_APP_ID_PLACEHOLDER = "00000000-0000-0000-0000-000000000000"
        const val COMPANION_STATUS_TIMEOUT_MS = 3000L
        const val SDK_INIT_TIMEOUT_MS = 10000L
    }
}
