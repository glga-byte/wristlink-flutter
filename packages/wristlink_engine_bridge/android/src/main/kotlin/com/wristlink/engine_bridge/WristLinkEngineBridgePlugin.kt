package com.wristlink.engine_bridge

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger

/**
 * GeneratedPluginRegistrant attaches this plugin to foreground and WorkManager
 * engines. The application owns the bridge implementation; reflection keeps
 * this small registrar module independent of app-only Garmin SDK classes.
 */
class WristLinkEngineBridgePlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        invokeRegistrar("register", binding)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        invokeRegistrar("unregister", binding)
    }

    private fun invokeRegistrar(
        methodName: String,
        binding: FlutterPlugin.FlutterPluginBinding,
    ) {
        val registrar = Class.forName(APP_REGISTRAR_CLASS)
        val register = registrar.getMethod(
            methodName,
            Context::class.java,
            BinaryMessenger::class.java,
        )
        register.invoke(null, binding.applicationContext, binding.binaryMessenger)
    }

    private companion object {
        const val APP_REGISTRAR_CLASS =
            "com.wristlink.wristlink_flutter.WristLinkEngineBridgeRegistrar"
    }
}
