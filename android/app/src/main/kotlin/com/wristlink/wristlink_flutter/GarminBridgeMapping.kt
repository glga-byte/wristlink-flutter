package com.wristlink.wristlink_flutter

internal object GarminBridgeMapping {
    const val UNKNOWN_COMPANION_STATE = "unknown"
    const val NATIVE_DISCOVERY_FAILURE_MESSAGE = "Garmin device discovery failed."

    fun mapReachability(status: String?): String {
        return when (normalizeNativeStatus(status)) {
            "not_connected", "not_paired" -> "offline"
            "connected" -> "reachable"
            "", "unknown" -> "unknown"
            else -> "nearby"
        }
    }

    fun mapCompanionStatus(status: String?): String {
        return when (normalizeNativeStatus(status)) {
            "not_installed", "not_supported" -> "missing"
            "installed" -> "installed"
            else -> UNKNOWN_COMPANION_STATE
        }
    }

    fun completeCompanionStates(
        deviceIds: Iterable<Long>,
        resolvedStates: Map<Long, String>,
    ): Map<Long, String> {
        return deviceIds.associateWith { deviceId ->
            resolvedStates[deviceId] ?: UNKNOWN_COMPANION_STATE
        }
    }

    private fun normalizeNativeStatus(status: String?): String {
        return status
            ?.trim()
            ?.lowercase()
            ?.substringAfterLast('.')
            .orEmpty()
    }
}
