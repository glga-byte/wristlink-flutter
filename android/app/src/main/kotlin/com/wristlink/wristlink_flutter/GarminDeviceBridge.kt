package com.wristlink.wristlink_flutter

import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.garmin.android.connectiq.ConnectIQ
import com.garmin.android.connectiq.IQApp
import com.garmin.android.connectiq.IQDevice
import com.garmin.android.connectiq.exception.InvalidStateException
import com.garmin.android.connectiq.exception.ServiceUnavailableException
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Collections
import java.util.IdentityHashMap

internal class GarminDeviceBridge(
    context: Context,
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
) {
    private val context = context.applicationContext
    private var connectIq: ConnectIQ? = null
    private val sdkInitialization = GarminSdkInitializationOwner()
    private val deviceQueries = GarminDeviceQueryOwner(GarminTransportSnapshot())
    private val pendingDeviceRequests = mutableListOf<PendingDeviceRequest>()
    private val registeredDeviceEvents = mutableMapOf<Long, RegisteredDeviceEvent>()
    private val registeredAppEvents = mutableMapOf<AppEventKey, RegisteredAppEvent>()
    private val registeredMessengers = Collections.newSetFromMap(
        IdentityHashMap<BinaryMessenger, Boolean>(),
    )
    private val deviceEventSinks = IdentityHashMap<BinaryMessenger, EventChannel.EventSink>()
    private val acknowledgementEventSinks =
        IdentityHashMap<BinaryMessenger, EventChannel.EventSink>()
    private var sdkInitTimeout: Runnable? = null

    fun register(binaryMessenger: BinaryMessenger) {
        if (!registeredMessengers.add(binaryMessenger)) {
            return
        }
        MethodChannel(binaryMessenger, GARMIN_DEVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "discoverDevices" -> requestDevices(
                    result,
                    GarminDeviceRequest.DISCOVERY,
                )
                "hydrateTransport" -> requestDevices(
                    result,
                    GarminDeviceRequest.TRANSPORT_HYDRATION,
                )
                else -> result.notImplemented()
            }
        }
        EventChannel(binaryMessenger, GARMIN_DEVICE_EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (events != null) {
                        deviceEventSinks[binaryMessenger] = events
                    }
                }

                override fun onCancel(arguments: Any?) {
                    deviceEventSinks.remove(binaryMessenger)
                }
            },
        )
        MethodChannel(binaryMessenger, GARMIN_SEND_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendMessage" -> sendMessage(call.arguments, result)
                else -> result.notImplemented()
            }
        }
        EventChannel(binaryMessenger, GARMIN_ACKNOWLEDGEMENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (events != null) {
                        acknowledgementEventSinks[binaryMessenger] = events
                    }
                }

                override fun onCancel(arguments: Any?) {
                    acknowledgementEventSinks.remove(binaryMessenger)
                }
            },
        )
    }

    fun unregister(binaryMessenger: BinaryMessenger) {
        if (!registeredMessengers.remove(binaryMessenger)) return
        deviceEventSinks.remove(binaryMessenger)
        acknowledgementEventSinks.remove(binaryMessenger)
        MethodChannel(binaryMessenger, GARMIN_DEVICE_CHANNEL).setMethodCallHandler(null)
        EventChannel(binaryMessenger, GARMIN_DEVICE_EVENTS_CHANNEL).setStreamHandler(null)
        MethodChannel(binaryMessenger, GARMIN_SEND_CHANNEL).setMethodCallHandler(null)
        EventChannel(binaryMessenger, GARMIN_ACKNOWLEDGEMENTS_CHANNEL).setStreamHandler(null)
    }

    private fun sendMessage(arguments: Any?, result: MethodChannel.Result) {
        val coordinator = GarminSendCoordinator<IQDevice, IQApp>(
            isSdkReady = { sdkInitialization.isReady && connectIq != null },
            findDevice = { deviceId ->
                GarminNativeDeviceLookup.byRawNumericId(
                    deviceId,
                    deviceQueries.snapshot.devices,
                )
            },
            findApp = { device -> deviceQueries.snapshot.apps[device.deviceIdentifier] },
            scheduleTimeout = { onTimeout ->
                val timeout = Runnable(onTimeout)
                mainHandler.postDelayed(timeout, SEND_TIMEOUT_MS)
                GarminSendTimeout { mainHandler.removeCallbacks(timeout) }
            },
            send = { device, app, message, completion ->
                connectIq!!.sendMessage(
                    device,
                    app,
                    message,
                    object : ConnectIQ.IQSendMessageListener {
                        override fun onMessageStatus(
                            device: IQDevice,
                            app: IQApp,
                            status: ConnectIQ.IQMessageStatus,
                        ) {
                            mainHandler.post {
                                completion(GarminTransportMapping.errorFor(status))
                            }
                        }
                    },
                )
            },
            mapThrownError = { error ->
                Log.w(TAG, "Garmin message send failed.", error)
                GarminTransportError(
                    code = when (error) {
                        is InvalidStateException,
                        is ServiceUnavailableException,
                        -> "sdkUnavailable"
                        else -> "nativeFailure"
                    },
                    message = "Garmin message send failed.",
                )
            },
        )
        coordinator.execute(arguments) { error ->
            if (error == null) {
                result.success(null)
            } else {
                result.error(error.code, error.message, null)
            }
        }
    }

    private fun requestDevices(
        result: MethodChannel.Result,
        request: GarminDeviceRequest,
    ) {
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

        when (val admission = sdkInitialization.admit(request)) {
            GarminSdkInitializationAdmission.Ready -> {
                queryDevices(currentConnectIq, result)
                return
            }
            GarminSdkInitializationAdmission.Join -> {
                pendingDeviceRequests.add(PendingDeviceRequest(result, request))
                return
            }
            GarminSdkInitializationAdmission.Unavailable -> {
                result.error(
                    "sdkUnavailable",
                    "Garmin Connect IQ SDK initialization is already unavailable or interactive.",
                    null,
                )
                return
            }
            is GarminSdkInitializationAdmission.Start -> {
                pendingDeviceRequests.add(PendingDeviceRequest(result, request))
                startSdkInitialization(currentConnectIq, admission)
            }
        }
    }

    private fun startSdkInitialization(
        currentConnectIq: ConnectIQ,
        admission: GarminSdkInitializationAdmission.Start,
    ) {
        val requestId = admission.requestId

        val timeout = Runnable {
            if (!sdkInitialization.markTimedOut(requestId)) return@Runnable
            sdkInitTimeout = null
            drainPendingDeviceRequests().forEach { pendingRequest ->
                pendingRequest.result.error(
                    "timeout",
                    "Garmin Connect IQ SDK initialization timed out.",
                    null,
                )
            }
        }
        sdkInitTimeout = timeout
        mainHandler.postDelayed(timeout, SDK_INIT_TIMEOUT_MS)

        try {
            currentConnectIq.initialize(
                context.applicationContext,
                admission.initializeWithUserInterface,
                object : ConnectIQ.ConnectIQListener {
                    override fun onSdkReady() {
                        mainHandler.post {
                            if (!sdkInitialization.markReady(requestId)) return@post
                            clearSdkInitTimeout()
                            drainPendingDeviceRequests().forEach { pendingRequest ->
                                queryDevices(currentConnectIq, pendingRequest.result)
                            }
                        }
                    }

                    override fun onInitializeError(status: ConnectIQ.IQSdkErrorStatus) {
                        mainHandler.post {
                            val code = when (status) {
                                ConnectIQ.IQSdkErrorStatus.GCM_NOT_INSTALLED -> "garminConnectMissing"
                                else -> "sdkUnavailable"
                            }
                            if (!sdkInitialization.markFailed(requestId)) return@post
                            clearSdkInitTimeout()
                            connectIq = null
                            drainPendingDeviceRequests().forEach { pendingRequest ->
                                pendingRequest.result.error(
                                    code,
                                    "Garmin Connect IQ SDK initialization failed: $status",
                                    null,
                                )
                            }
                        }
                    }

                    override fun onSdkShutDown() {
                        mainHandler.post {
                            if (!sdkInitialization.markShutDown(requestId)) return@post
                            clearSdkInitTimeout()
                            deviceQueries.invalidate(GarminTransportSnapshot())
                            connectIq = null
                            registeredDeviceEvents.clear()
                            registeredAppEvents.clear()
                            drainPendingDeviceRequests().forEach { pendingRequest ->
                                pendingRequest.result.error(
                                    "sdkUnavailable",
                                    "Garmin Connect IQ SDK shut down during initialization.",
                                    null,
                                )
                            }
                        }
                    }
                },
            )
        } catch (error: Throwable) {
            Log.w(TAG, "Garmin Connect IQ SDK initialization failed.", error)
            if (sdkInitialization.markFailed(requestId)) {
                clearSdkInitTimeout()
                connectIq = null
                drainPendingDeviceRequests().forEach { pendingRequest ->
                    pendingRequest.result.error(
                        "sdkUnavailable",
                        "Garmin Connect IQ SDK initialization failed.",
                        null,
                    )
                }
            }
        }
    }

    private fun clearSdkInitTimeout() {
        sdkInitTimeout?.let { mainHandler.removeCallbacks(it) }
        sdkInitTimeout = null
    }

    private fun drainPendingDeviceRequests(): List<PendingDeviceRequest> {
        val pendingRequests = pendingDeviceRequests.toList()
        pendingDeviceRequests.clear()
        return pendingRequests
    }

    private fun queryDevices(connectIq: ConnectIQ, result: MethodChannel.Result) {
        val queryGeneration = deviceQueries.begin()
        try {
            val knownDevices = connectIq.getKnownDevices()
            if (knownDevices.isEmpty()) {
                val emptySnapshot = GarminTransportSnapshot(
                    generation = queryGeneration,
                )
                if (deviceQueries.publish(queryGeneration, emptySnapshot) ==
                    GarminDeviceQueryPublication.PUBLISHED
                ) {
                    reconcileEventRegistrations(connectIq, emptySnapshot)
                    result.error(
                        "noAuthorizedDevices",
                        "No authorized Garmin devices were returned.",
                        null,
                    )
                } else {
                    completeSupersededQuery(result)
                }
                return
            }

            val appId = connectIqAppId()
            if (appId == null) {
                val latestStates = GarminBridgeMapping.completeCompanionStates(
                    knownDevices.map { it.deviceIdentifier },
                    emptyMap(),
                )
                publishQuerySnapshot(
                    connectIq = connectIq,
                    generation = queryGeneration,
                    devices = knownDevices,
                    apps = emptyMap(),
                    companionStates = latestStates,
                    result = result,
                )
                return
            }

            queryCompanionStates(
                connectIq,
                knownDevices,
                appId,
                queryGeneration,
                result,
            )
        } catch (error: Throwable) {
            Log.w(TAG, "Garmin device discovery failed.", error)
            if (deviceQueries.fail(queryGeneration)) {
                result.error(
                    "nativeFailure",
                    GarminBridgeMapping.NATIVE_DISCOVERY_FAILURE_MESSAGE,
                    null,
                )
            } else {
                completeSupersededQuery(result)
            }
        }
    }

    private fun queryCompanionStates(
        connectIq: ConnectIQ,
        devices: List<IQDevice>,
        appId: String,
        queryGeneration: Int,
        result: MethodChannel.Result,
    ) {
        val states = mutableMapOf<Long, String>()
        val apps = mutableMapOf<Long, IQApp>()
        var remaining = devices.size
        val completion = BridgeCompletion()

        fun finish() {
            completion.run {
                val latestStates = GarminBridgeMapping.completeCompanionStates(
                    devices.map { it.deviceIdentifier },
                    states,
                )
                publishQuerySnapshot(
                    connectIq = connectIq,
                    generation = queryGeneration,
                    devices = devices,
                    apps = apps,
                    companionStates = latestStates,
                    result = result,
                )
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
                                if (completion.isCompleted) return@post
                                val companionState =
                                    GarminBridgeMapping.mapCompanionStatus(app.status?.name)
                                if (companionState == "installed") {
                                    apps[device.deviceIdentifier] = app
                                } else {
                                    apps.remove(device.deviceIdentifier)
                                }
                                recordState(
                                    device,
                                    companionState,
                                )
                            }
                        }

                        override fun onApplicationNotInstalled(applicationId: String) {
                            mainHandler.post {
                                if (completion.isCompleted) return@post
                                apps.remove(device.deviceIdentifier)
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

    private fun publishQuerySnapshot(
        connectIq: ConnectIQ,
        generation: Int,
        devices: List<IQDevice>,
        apps: Map<Long, IQApp>,
        companionStates: Map<Long, String>,
        result: MethodChannel.Result,
    ) {
        val payload = devices.map { device ->
            mapDevice(
                connectIq,
                device,
                companionStates[device.deviceIdentifier]
                    ?: GarminBridgeMapping.UNKNOWN_COMPANION_STATE,
            )
        }
        val snapshot = GarminTransportSnapshot(
            generation = generation,
            devices = devices.associateBy { it.deviceIdentifier },
            apps = apps.toMap(),
            companionStates = companionStates.toMap(),
        )
        if (deviceQueries.publish(generation, snapshot) ==
            GarminDeviceQueryPublication.SUPERSEDED
        ) {
            completeSupersededQuery(result)
            return
        }
        reconcileEventRegistrations(connectIq, snapshot)
        result.success(payload)
    }

    private fun completeSupersededQuery(result: MethodChannel.Result) {
        result.error(
            "sdkUnavailable",
            "Garmin device readiness query was superseded.",
            null,
        )
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

    private fun reconcileEventRegistrations(
        connectIq: ConnectIQ,
        snapshot: GarminTransportSnapshot,
    ) {
        registeredAppEvents.values.forEach { registration ->
            try {
                connectIq.unregisterForApplicationEvents(
                    registration.device,
                    registration.app,
                )
            } catch (_: Throwable) {
                // Generation checks keep any already-queued callback harmless.
            }
        }
        registeredDeviceEvents.values.forEach { registration ->
            try {
                connectIq.unregisterForDeviceEvents(registration.device)
            } catch (_: Throwable) {
                // Generation checks keep any already-queued callback harmless.
            }
        }
        registeredAppEvents.clear()
        registeredDeviceEvents.clear()

        snapshot.devices.values.forEach { device ->
            registerForDeviceEvents(connectIq, device, snapshot.generation)
        }
        snapshot.apps.forEach { (deviceId, app) ->
            snapshot.devices[deviceId]?.let { device ->
                registerForAppEvents(connectIq, device, app, snapshot.generation)
            }
        }
    }

    private fun registerForDeviceEvents(
        connectIq: ConnectIQ,
        device: IQDevice,
        generation: Int,
    ) {
        try {
            connectIq.registerForDeviceEvents(
                device,
                object : ConnectIQ.IQDeviceEventListener {
                    override fun onDeviceStatusChanged(
                        device: IQDevice,
                        status: IQDevice.IQDeviceStatus,
                    ) {
                        mainHandler.post {
                            val snapshot = deviceQueries.snapshot
                            if (!garminDeviceCallbackIsCurrent(
                                    snapshotGeneration = snapshot.generation,
                                    callbackGeneration = generation,
                                    currentDevice = snapshot.devices[device.deviceIdentifier],
                                    callbackDevice = device,
                                )
                            ) {
                                return@post
                            }
                            emitDeviceUpdate(connectIq, device, status.toString())
                        }
                    }
                },
            )
            registeredDeviceEvents[device.deviceIdentifier] = RegisteredDeviceEvent(
                device = device,
                generation = generation,
            )
        } catch (_: Throwable) {
            // Discovery still succeeds if live status events are unavailable.
        }
    }

    private fun registerForAppEvents(
        connectIq: ConnectIQ,
        device: IQDevice,
        app: IQApp,
        generation: Int,
    ) {
        val key = AppEventKey(device.deviceIdentifier, app.applicationId)
        try {
            connectIq.registerForAppEvents(
                device,
                app,
                object : ConnectIQ.IQApplicationEventListener {
                    override fun onMessageReceived(
                        device: IQDevice,
                        app: IQApp,
                        messages: List<Any>,
                        status: ConnectIQ.IQMessageStatus,
                    ) {
                        mainHandler.post {
                            val snapshot = deviceQueries.snapshot
                            if (!garminAppCallbackIsCurrent(
                                    snapshotGeneration = snapshot.generation,
                                    callbackGeneration = generation,
                                    currentDevice = snapshot.devices[device.deviceIdentifier],
                                    callbackDevice = device,
                                    currentApp = snapshot.apps[device.deviceIdentifier],
                                    callbackApp = app,
                                )
                            ) {
                                return@post
                            }
                            GarminTransportMapping.deliverRawMessageMaps(
                                messages,
                                ::emitAcknowledgement,
                            )
                        }
                    }
                },
            )
            registeredAppEvents[key] = RegisteredAppEvent(
                device = device,
                app = app,
                generation = generation,
            )
        } catch (error: Throwable) {
            Log.w(TAG, "Garmin acknowledgement registration failed.", error)
        }
    }

    private fun emitDeviceUpdate(connectIq: ConnectIQ, device: IQDevice, status: String) {
        val snapshot = deviceQueries.snapshot
        val companionInstallState = snapshot.companionStates[device.deviceIdentifier]
            ?: GarminBridgeMapping.UNKNOWN_COMPANION_STATE
        deviceQueries.updateSnapshot { current ->
            current.copy(
                devices = current.devices + (device.deviceIdentifier to device),
            )
        }
        val payload = mapDevice(
            connectIq,
            device,
            companionInstallState,
            statusOverride = status,
        )
        deviceEventSinks.values.toList().forEach { it.success(payload) }
    }

    private fun emitAcknowledgement(message: Map<*, *>) {
        acknowledgementEventSinks.values.toList().forEach { it.success(message) }
    }

    private fun connectIqAppId(): String? {
        val metadata = context.packageManager.getApplicationInfo(
            context.packageName,
            PackageManager.GET_META_DATA,
        ).metaData
        val value = metadata?.getString(CONNECT_IQ_APP_ID_META_DATA)?.trim().orEmpty()
        return value.takeUnless { it.isEmpty() }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            context.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private data class AppEventKey(val deviceId: Long, val appId: String)

    private data class RegisteredDeviceEvent(
        val device: IQDevice,
        val generation: Int,
    )

    private data class RegisteredAppEvent(
        val device: IQDevice,
        val app: IQApp,
        val generation: Int,
    )

    private data class PendingDeviceRequest(
        val result: MethodChannel.Result,
        val request: GarminDeviceRequest,
    )

    private data class GarminTransportSnapshot(
        val generation: Int = 0,
        val devices: Map<Long, IQDevice> = emptyMap(),
        val apps: Map<Long, IQApp> = emptyMap(),
        val companionStates: Map<Long, String> = emptyMap(),
    )

    companion object {
        @Volatile
        private var instance: GarminDeviceBridge? = null

        fun getInstance(context: Context): GarminDeviceBridge {
            return instance ?: synchronized(this) {
                instance ?: GarminDeviceBridge(context.applicationContext).also { instance = it }
            }
        }

        const val GARMIN_DEVICE_CHANNEL = "wristlink/garmin_devices"
        const val GARMIN_DEVICE_EVENTS_CHANNEL = "wristlink/garmin_device_events"
        const val GARMIN_SEND_CHANNEL = "wristlink/garmin_send"
        const val GARMIN_ACKNOWLEDGEMENTS_CHANNEL = "wristlink/garmin_acknowledgements"
        const val GARMIN_CONNECT_PACKAGE = "com.garmin.android.apps.connectmobile"
        const val GARMIN_CONNECT_IQ_PACKAGE = "com.garmin.connectiq"
        const val TAG = "WristLinkGarminBridge"
        const val CONNECT_IQ_APP_ID_META_DATA = "com.wristlink.CONNECT_IQ_APP_ID"
        const val COMPANION_STATUS_TIMEOUT_MS = 3000L
        const val SDK_INIT_TIMEOUT_MS = 10000L
        const val SEND_TIMEOUT_MS = 30000L
    }
}
