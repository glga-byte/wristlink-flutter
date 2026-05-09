package com.wristlink.wristlink_flutter

internal object GarminBridgeMapping {
    const val UNKNOWN_COMPANION_STATE = "unknown"
    const val NATIVE_DISCOVERY_FAILURE_MESSAGE = "Garmin device discovery failed."
    private const val UNKNOWN_DEVICE_NAME = "Garmin device"

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

    fun devicePayload(
        id: String,
        name: String?,
        modelName: String?,
        family: String?,
        unitId: String?,
        nativeStatus: String?,
        companionInstallState: String,
    ): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "name" to name?.takeUnless { it.isBlank() }.orDefaultDeviceName(),
            "modelName" to modelName?.takeUnless { it.isBlank() },
            "family" to family?.takeUnless { it.isBlank() },
            "unitId" to unitId?.takeUnless { it.isBlank() },
            "reachability" to mapReachability(nativeStatus),
            "companionInstallState" to companionInstallState,
        )
    }

    private fun normalizeNativeStatus(status: String?): String {
        return status
            ?.trim()
            ?.lowercase()
            ?.substringAfterLast('.')
            .orEmpty()
    }

    private fun String?.orDefaultDeviceName(): String {
        return this ?: UNKNOWN_DEVICE_NAME
    }
}
