package com.wristlink.wristlink_flutter

import android.content.Context
import androidx.annotation.Keep
import io.flutter.plugin.common.BinaryMessenger
import java.util.Collections
import java.util.IdentityHashMap

/** Registers application-owned channels once for each Flutter engine. */
@Keep
class WristLinkEngineBridgeRegistrar private constructor() {
    companion object {
        private val registeredMessengers = Collections.newSetFromMap(
            IdentityHashMap<BinaryMessenger, Boolean>(),
        )

        @JvmStatic
        fun register(context: Context, binaryMessenger: BinaryMessenger) {
            synchronized(registeredMessengers) {
                if (!registeredMessengers.add(binaryMessenger)) return
            }
            GarminDeviceBridge.getInstance(context).register(binaryMessenger)
            DeviceSettingsBridge(context.applicationContext).register(binaryMessenger)
        }

        @JvmStatic
        fun unregister(context: Context, binaryMessenger: BinaryMessenger) {
            synchronized(registeredMessengers) {
                if (!registeredMessengers.remove(binaryMessenger)) return
            }
            GarminDeviceBridge.getInstance(context).unregister(binaryMessenger)
            DeviceSettingsBridge(context.applicationContext).unregister(binaryMessenger)
        }
    }
}
