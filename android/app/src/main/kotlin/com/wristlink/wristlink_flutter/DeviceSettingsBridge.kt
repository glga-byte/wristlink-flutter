package com.wristlink.wristlink_flutter

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal class DeviceSettingsBridge(private val context: Context) {
    fun register(binaryMessenger: BinaryMessenger) {
        MethodChannel(binaryMessenger, DEVICE_SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
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

    private fun settings() = context.getSharedPreferences(DEVICE_SETTINGS_NAME, Context.MODE_PRIVATE)

    private companion object {
        const val DEVICE_SETTINGS_CHANNEL = "wristlink/device_settings"
        const val DEVICE_SETTINGS_NAME = "wristlink_device_settings"
    }
}
