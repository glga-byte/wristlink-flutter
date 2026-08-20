package com.wristlink.wristlink_flutter

internal enum class GarminDeviceRequest(
    val initializeWithUserInterface: Boolean,
) {
    DISCOVERY(initializeWithUserInterface = true),
    TRANSPORT_HYDRATION(initializeWithUserInterface = false),
    ;

    fun canJoin(activeRequest: GarminDeviceRequest): Boolean {
        return this != TRANSPORT_HYDRATION ||
            !activeRequest.initializeWithUserInterface
    }
}

internal sealed interface GarminSdkInitializationAdmission {
    data object Ready : GarminSdkInitializationAdmission

    data class Start(
        val requestId: Int,
        val initializeWithUserInterface: Boolean,
    ) : GarminSdkInitializationAdmission

    data object Join : GarminSdkInitializationAdmission

    data object Unavailable : GarminSdkInitializationAdmission
}

/** Owns one Connect IQ initialize call until its callback or SDK shutdown. */
internal class GarminSdkInitializationOwner {
    private enum class Phase { IDLE, INITIALIZING, READY }

    private var phase = Phase.IDLE
    private var activeRequest: GarminDeviceRequest? = null
    private var activeRequestId = 0
    private var timedOut = false

    val isReady: Boolean
        @Synchronized get() = phase == Phase.READY

    @Synchronized
    fun admit(request: GarminDeviceRequest): GarminSdkInitializationAdmission {
        return when (phase) {
            Phase.READY -> GarminSdkInitializationAdmission.Ready
            Phase.IDLE -> {
                activeRequestId += 1
                activeRequest = request
                timedOut = false
                phase = Phase.INITIALIZING
                GarminSdkInitializationAdmission.Start(
                    requestId = activeRequestId,
                    initializeWithUserInterface = request.initializeWithUserInterface,
                )
            }
            Phase.INITIALIZING -> {
                val currentRequest = activeRequest
                if (timedOut || currentRequest == null || !request.canJoin(currentRequest)) {
                    GarminSdkInitializationAdmission.Unavailable
                } else {
                    GarminSdkInitializationAdmission.Join
                }
            }
        }
    }

    @Synchronized
    fun markTimedOut(requestId: Int): Boolean {
        if (phase != Phase.INITIALIZING || activeRequestId != requestId || timedOut) {
            return false
        }
        timedOut = true
        return true
    }

    @Synchronized
    fun markReady(requestId: Int): Boolean {
        if (phase != Phase.INITIALIZING || activeRequestId != requestId) {
            return false
        }
        phase = Phase.READY
        activeRequest = null
        timedOut = false
        return true
    }

    @Synchronized
    fun markFailed(requestId: Int): Boolean {
        if (phase != Phase.INITIALIZING || activeRequestId != requestId) {
            return false
        }
        phase = Phase.IDLE
        activeRequest = null
        timedOut = false
        return true
    }

    @Synchronized
    fun markShutDown(requestId: Int): Boolean {
        if (activeRequestId != requestId || phase == Phase.IDLE) {
            return false
        }
        activeRequestId += 1
        phase = Phase.IDLE
        activeRequest = null
        timedOut = false
        return true
    }
}
