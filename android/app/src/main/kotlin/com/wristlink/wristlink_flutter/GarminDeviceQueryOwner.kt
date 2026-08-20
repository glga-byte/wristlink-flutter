package com.wristlink.wristlink_flutter

internal enum class GarminDeviceQueryPublication { PUBLISHED, SUPERSEDED }

internal fun <Device> garminDeviceCallbackIsCurrent(
    snapshotGeneration: Int,
    callbackGeneration: Int,
    currentDevice: Device?,
    callbackDevice: Device,
): Boolean =
    snapshotGeneration == callbackGeneration && currentDevice === callbackDevice

internal fun <Device, App> garminAppCallbackIsCurrent(
    snapshotGeneration: Int,
    callbackGeneration: Int,
    currentDevice: Device?,
    callbackDevice: Device,
    currentApp: App?,
    callbackApp: App,
): Boolean =
    snapshotGeneration == callbackGeneration &&
        currentDevice === callbackDevice &&
        currentApp === callbackApp

/** Keeps the last valid cache visible until the newest query publishes atomically. */
internal class GarminDeviceQueryOwner<Snapshot>(initialSnapshot: Snapshot) {
    private var nextGeneration = 0
    private var currentGeneration: Int? = null
    private var publishedSnapshot = initialSnapshot

    val snapshot: Snapshot
        @Synchronized get() = publishedSnapshot

    @Synchronized
    fun begin(): Int {
        nextGeneration += 1
        currentGeneration = nextGeneration
        return nextGeneration
    }

    @Synchronized
    fun publish(
        generation: Int,
        snapshot: Snapshot,
    ): GarminDeviceQueryPublication {
        if (currentGeneration != generation) {
            return GarminDeviceQueryPublication.SUPERSEDED
        }
        publishedSnapshot = snapshot
        currentGeneration = null
        return GarminDeviceQueryPublication.PUBLISHED
    }

    @Synchronized
    fun fail(generation: Int): Boolean {
        if (currentGeneration != generation) return false
        currentGeneration = null
        return true
    }

    @Synchronized
    fun updateSnapshot(transform: (Snapshot) -> Snapshot) {
        publishedSnapshot = transform(publishedSnapshot)
    }

    @Synchronized
    fun invalidate(replacement: Snapshot) {
        currentGeneration = null
        publishedSnapshot = replacement
    }
}
