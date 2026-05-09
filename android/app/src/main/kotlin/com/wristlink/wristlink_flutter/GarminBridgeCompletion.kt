package com.wristlink.wristlink_flutter

internal class BridgeCompletion(private val requestId: Int? = null) {
    private var completed = false

    val isCompleted: Boolean
        get() = completed

    @Synchronized
    fun run(requestId: Int? = null, completion: () -> Unit): Boolean {
        if (completed || (this.requestId != null && this.requestId != requestId)) {
            return false
        }
        completed = true
        completion()
        return true
    }
}
