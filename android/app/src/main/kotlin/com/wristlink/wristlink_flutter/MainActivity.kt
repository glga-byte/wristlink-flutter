package com.wristlink.wristlink_flutter

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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

        val connectIq = connectIqInstance()
        if (connectIq == null) {
            result.error(
                "sdkUnavailable",
                "Garmin Connect IQ Mobile SDK is unavailable.",
                null,
            )
            return
        }

        try {
            val knownDevices = callNoArg(connectIq, "getKnownDevices") as? Iterable<*>
            if (knownDevices == null) {
                result.error(
                    "noAuthorizedDevices",
                    "No authorized Garmin devices were returned.",
                    null,
                )
                return
            }

            val devices = knownDevices.mapNotNull { device ->
                device?.let { mapDevice(connectIq, it) }
            }
            if (devices.isEmpty()) {
                result.error(
                    "noAuthorizedDevices",
                    "No authorized Garmin devices were returned.",
                    null,
                )
            } else {
                result.success(devices)
            }
        } catch (error: Throwable) {
            result.error(
                "nativeFailure",
                error.message ?: "Garmin device discovery failed.",
                null,
            )
        }
    }

    private fun connectIqInstance(): Any? {
        return try {
            val connectIqClass = Class.forName("com.garmin.android.connectiq.ConnectIQ")
            val connectTypeClass = Class.forName("com.garmin.android.connectiq.ConnectIQ\$IQConnectType")
            val wirelessType = connectTypeClass.enumConstants?.firstOrNull {
                it.toString().equals("WIRELESS", ignoreCase = true)
            } ?: connectTypeClass.enumConstants?.firstOrNull()

            connectIqClass.methods.firstOrNull { method ->
                method.name == "getInstance" && method.parameterTypes.size >= 2
            }?.invoke(null, applicationContext, wirelessType)
        } catch (_: Throwable) {
            null
        }
    }

    private fun mapDevice(connectIq: Any, device: Any): Map<String, Any?> {
        val id = callNoArg(device, "getDeviceIdentifier")?.toString()
            ?: callNoArg(device, "getId")?.toString()
            ?: device.hashCode().toString()
        val name = callNoArg(device, "getFriendlyName")?.toString()
            ?: callNoArg(device, "getName")?.toString()
            ?: "Garmin device"
        val status = try {
            connectIq.javaClass.methods.firstOrNull { method ->
                method.name == "getStatus" && method.parameterTypes.size == 1
            }?.invoke(connectIq, device)?.toString()
        } catch (_: Throwable) {
            null
        }

        return mapOf(
            "id" to id,
            "name" to name,
            "modelName" to callNoArg(device, "getModelName")?.toString(),
            "unitId" to id,
            "reachability" to mapReachability(status),
            "companionInstallState" to "unknown",
        )
    }

    private fun callNoArg(target: Any, methodName: String): Any? {
        return target.javaClass.methods.firstOrNull { method ->
            method.name == methodName && method.parameterTypes.isEmpty()
        }?.invoke(target)
    }

    private fun mapReachability(status: String?): String {
        val normalized = status?.lowercase().orEmpty()
        return when {
            "connected" in normalized || "available" in normalized -> "reachable"
            "not_connected" in normalized || "unavailable" in normalized -> "offline"
            normalized.isEmpty() -> "unknown"
            else -> "nearby"
        }
    }

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
        const val GARMIN_CONNECT_PACKAGE = "com.garmin.android.apps.connectmobile"
        const val GARMIN_CONNECT_IQ_PACKAGE = "com.garmin.connectiq"
    }
}
