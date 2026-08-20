package com.wristlink.wristlink_flutter

import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

internal class ShareIngressBridge(context: Context) {
    private val coordinator =
        ShareIngressCoordinator(SharedPreferencesShareIngressStore(context.applicationContext))
    private var eventSink: EventChannel.EventSink? = null

    fun register(binaryMessenger: BinaryMessenger) {
        MethodChannel(binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "drainPending" -> result.success(coordinator.pending().map { it.channelMap() })
                "acknowledge" -> {
                    val id = call.argument<String>("id")
                    if (id.isNullOrBlank()) {
                        result.error("invalidArguments", "A shared-content id is required.", null)
                    } else {
                        result.success(coordinator.acknowledge(id))
                    }
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
    }

    fun accept(intent: Intent?): Boolean {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") return false
        val raw = intent.getCharSequenceExtra(Intent.EXTRA_TEXT) ?: return false
        return try {
            val record = coordinator.ingest(raw) ?: return true
            eventSink?.success(record.channelMap())
            true
        } catch (error: Throwable) {
            Log.e(TAG, "Shared content could not be persisted.", error)
            false
        }
    }

    private companion object {
        const val METHOD_CHANNEL = "wristlink/shared_content"
        const val EVENT_CHANNEL = "wristlink/shared_content_events"
        const val TAG = "WristLinkShareIngress"
    }
}
