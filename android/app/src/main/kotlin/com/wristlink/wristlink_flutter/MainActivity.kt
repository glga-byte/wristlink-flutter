package com.wristlink.wristlink_flutter

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var shareIngressBridge: ShareIngressBridge
    private lateinit var shareIntentLifecycle: ShareIntentLifecycle

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WristLinkEngineBridgeRegistrar.register(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        shareIngressBridge = ShareIngressBridge(applicationContext)
        shareIngressBridge.register(flutterEngine.dartExecutor.binaryMessenger)
        shareIntentLifecycle = ShareIntentLifecycle(shareIngressBridge::accept, packageName)
        consumeShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeShareIntent(intent)
    }

    private fun consumeShareIntent(candidate: Intent?) {
        if (!::shareIntentLifecycle.isInitialized) return
        shareIntentLifecycle.replacementFor(candidate)?.let(::setIntent)
    }
}

internal class ShareIntentLifecycle(
    private val accept: (Intent?) -> Boolean,
    private val packageName: String,
) {
    fun replacementFor(candidate: Intent?): Intent? =
        if (accept(candidate)) {
            Intent(Intent.ACTION_MAIN).setPackage(packageName)
        } else {
            null
        }
}
