package com.wristlink.wristlink_flutter

import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import com.garmin.android.connectiq.ConnectIQ
import com.garmin.android.connectiq.IQApp
import com.garmin.android.connectiq.IQDevice
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var connectIq: ConnectIQ? = null
    private var sdkReady = false
    private var sdkInitializing = false
    private var sdkInitRequestId = 0
    private val pendingDiscoveryResults = mutableListOf<MethodChannel.Result>()
    private val companionStates = mutableMapOf<Long, String>()
    private val registeredDeviceEventIds = mutableSetOf<Long>()
    private var deviceEventSink: EventChannel.EventSink? = null
    private var sdkInitTimeout: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GARMIN_DEVICE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "discoverDevices" -> discoverDevices(result)
                else -> result.notImplemented()
            }
        }
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GARMIN_DEVICE_EVENTS_CHANNEL,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                deviceEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                deviceEventSink = null
            }
        })
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_SETTINGS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            val key = call.argument<String>("key")
            when (call.method) {
                "readString" -> result.success(settings().getString(key, null))
                "writeString" -> {
                    val value = call.argument<String>("value").orEmpty()
                    settings().edit().putString(key, value).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
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
            ConnectIQ.getInstance(applicationContext, ConnectIQ.IQConnectType.WIRELESS)
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

        val timeout = Runnable {
            if (sdkInitRequestId != requestId) return@Runnable
            sdkInitRequestId += 1
            sdkInitializing = false
            sdkReady = false
            connectIq = null
            drainPendingDiscoveryResults { pendingResult ->
                pendingResult.error(
                    "timeout",
                    "Garmin Connect IQ SDK initialization timed out.",
                    null,
                )
            }
        }
        sdkInitTimeout = timeout
        mainHandler.postDelayed(timeout, SDK_INIT_TIMEOUT_MS)

        currentConnectIq.initialize(applicationContext, true, object : ConnectIQ.ConnectIQListener {
            override fun onSdkReady() {
                mainHandler.post {
                    if (sdkInitRequestId != requestId) return@post
                    sdkInitTimeout?.let { mainHandler.removeCallbacks(it) }
                    sdkInitTimeout = null
                    sdkInitializing = false
                    sdkReady = true
                    val pendingResults = drainPendingDiscoveryResults()
                    pendingResults.forEach { pendingResult ->
                        queryDevices(currentConnectIq, pendingResult)
                    }
                }
            }

            override fun onInitializeError(status: ConnectIQ.IQSdkErrorStatus) {
                mainHandler.post {
                    if (sdkInitRequestId != requestId) return@post
                    sdkInitTimeout?.let { mainHandler.removeCallbacks(it) }
                    sdkInitTimeout = null
                    sdkInitializing = false
                    sdkReady = false
                    connectIq = null
                    val code = when (status) {
                        ConnectIQ.IQSdkErrorStatus.GCM_NOT_INSTALLED -> "garminConnectMissing"
                        else -> "sdkUnavailable"
                    }
                    drainPendingDiscoveryResults { pendingResult ->
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
                    connectIq = null
                    registeredDeviceEventIds.clear()
                }
            }
        })
    }

    private fun drainPendingDiscoveryResults(): List<MethodChannel.Result> {
        val pendingResults = pendingDiscoveryResults.toList()
        pendingDiscoveryResults.clear()
        return pendingResults
    }

    private fun drainPendingDiscoveryResults(complete: (MethodChannel.Result) -> Unit) {
        drainPendingDiscoveryResults().forEach(complete)
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
                result.success(knownDevices.map { device ->
                    registerForDeviceEvents(connectIq, device)
                    mapDevice(connectIq, device, "unknown")
                })
                return
            }

            queryCompanionStates(connectIq, knownDevices, appId, result)
        } catch (error: Throwable) {
            result.error(
                "nativeFailure",
                error.message ?: "Garmin device discovery failed.",
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
        var finished = false

        fun finish() {
            if (finished) return
            finished = true
            companionStates.putAll(states)
            result.success(devices.map { device ->
                registerForDeviceEvents(connectIq, device)
                mapDevice(connectIq, device, states[device.deviceIdentifier] ?: "unknown")
            })
        }

        val timeout = Runnable { finish() }
        mainHandler.postDelayed(timeout, COMPANION_STATUS_TIMEOUT_MS)

        devices.forEach { device ->
            try {
                connectIq.getApplicationInfo(
                    appId,
                    device,
                    object : ConnectIQ.IQApplicationInfoListener {
                        override fun onApplicationInfoReceived(app: IQApp) {
                            states[device.deviceIdentifier] = mapCompanionStatus(app.status?.name)
                            remaining -= 1
                            if (remaining == 0) {
                                mainHandler.removeCallbacks(timeout)
                                finish()
                            }
                        }

                        override fun onApplicationNotInstalled(applicationId: String) {
                            states[device.deviceIdentifier] = "missing"
                            remaining -= 1
                            if (remaining == 0) {
                                mainHandler.removeCallbacks(timeout)
                                finish()
                            }
                        }
                    },
                )
            } catch (_: Throwable) {
                states[device.deviceIdentifier] = "unknown"
                remaining -= 1
                if (remaining == 0) {
                    mainHandler.removeCallbacks(timeout)
                    finish()
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
        val partNumber = try {
            connectIq.getDevicePartNumber(device)
        } catch (_: Throwable) {
            null
        }

        return mapOf(
            "id" to device.deviceIdentifier.toString(),
            "name" to device.friendlyName,
            "modelName" to partNumber,
            "unitId" to device.deviceIdentifier.toString(),
            "reachability" to mapReachability(status),
            "companionInstallState" to companionInstallState,
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
        val companionInstallState = companionStates[device.deviceIdentifier] ?: "unknown"
        deviceEventSink?.success(
            mapDevice(
                connectIq,
                device,
                companionInstallState,
                statusOverride = status,
            ),
        )
    }

    private fun mapReachability(status: String?): String {
        val normalized = status?.lowercase().orEmpty()
        return when {
            "not_connected" in normalized || "not_paired" in normalized -> "offline"
            "connected" in normalized -> "reachable"
            normalized.isEmpty() || "unknown" in normalized -> "unknown"
            else -> "nearby"
        }
    }

    private fun mapCompanionStatus(status: String?): String {
        val normalized = status?.lowercase()?.substringAfterLast('.').orEmpty()
        return when {
            normalized == "not_installed" || normalized == "not_supported" -> "missing"
            normalized == "installed" -> "installed"
            else -> "unknown"
        }
    }

    private fun connectIqAppId(): String? {
        val metadata = packageManager.getApplicationInfo(
            packageName,
            PackageManager.GET_META_DATA,
        ).metaData
        val value = metadata?.getString(CONNECT_IQ_APP_ID_META_DATA)?.trim().orEmpty()
        return value.takeUnless {
            it.isEmpty() || it == CONNECT_IQ_APP_ID_PLACEHOLDER
        }
    }

    private fun settings() = getSharedPreferences(DEVICE_SETTINGS_NAME, MODE_PRIVATE)

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private companion object {
        const val GARMIN_DEVICE_CHANNEL = "wristlink/garmin_devices"
        const val GARMIN_DEVICE_EVENTS_CHANNEL = "wristlink/garmin_device_events"
        const val DEVICE_SETTINGS_CHANNEL = "wristlink/device_settings"
        const val DEVICE_SETTINGS_NAME = "wristlink_device_settings"
        const val GARMIN_CONNECT_PACKAGE = "com.garmin.android.apps.connectmobile"
        const val GARMIN_CONNECT_IQ_PACKAGE = "com.garmin.connectiq"
        const val CONNECT_IQ_APP_ID_META_DATA = "com.wristlink.CONNECT_IQ_APP_ID"
        const val CONNECT_IQ_APP_ID_PLACEHOLDER = "00000000-0000-0000-0000-000000000000"
        const val COMPANION_STATUS_TIMEOUT_MS = 3000L
        const val SDK_INIT_TIMEOUT_MS = 10000L
    }
}
