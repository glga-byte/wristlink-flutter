package com.wristlink.wristlink_flutter

import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

internal class ShareIngressCoordinator(
    private val store: ShareIngressStore,
    private val nowMillis: () -> Long = System::currentTimeMillis,
    private val idFactory: () -> String = { UUID.randomUUID().toString() },
) {
    fun ingest(rawContent: CharSequence?): SharedContentRecordData? {
        val content = rawContent?.toString()?.trim()?.take(MAX_CONTENT_CHARACTERS).orEmpty()
        if (content.isEmpty()) return null

        val fingerprint = fingerprint(content)
        val now = nowMillis()
        val recent = pruneRecent(store.recentAcknowledgements(), now)
        val current = store.records()
        if (current.any { it.fingerprint == fingerprint } || recent.containsKey(fingerprint)) {
            store.saveRecentAcknowledgements(recent)
            return null
        }

        val record =
            SharedContentRecordData(
                id = idFactory(),
                receivedAt = isoTimestamp(now),
                content = content,
                fingerprint = fingerprint,
            )
        check(store.save(current + record)) { "Shared content could not be persisted." }
        return record
    }

    fun pending(): List<SharedContentRecordData> = store.records()

    fun acknowledge(id: String): Boolean {
        val current = store.records()
        val record = current.firstOrNull { it.id == id } ?: return false
        val now = nowMillis()
        val recent = pruneRecent(store.recentAcknowledgements(), now).toMutableMap()
        recent[record.fingerprint] = now
        check(store.save(current.filterNot { it.id == id })) { "Acknowledgement cleanup failed." }
        check(store.saveRecentAcknowledgements(recent)) { "Acknowledgement history failed." }
        return true
    }

    private fun pruneRecent(values: Map<String, Long>, now: Long): Map<String, Long> =
        values
            .filterValues { now - it <= DUPLICATE_WINDOW_MILLIS }
            .entries
            .sortedByDescending { it.value }
            .take(MAX_RECENT_ACKNOWLEDGEMENTS)
            .associate { it.toPair() }

    private fun fingerprint(content: String): String {
        val bytes = MessageDigest.getInstance("SHA-256").digest(content.toByteArray(StandardCharsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }

    private fun isoTimestamp(milliseconds: Long): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(Date(milliseconds))

    private companion object {
        const val MAX_CONTENT_CHARACTERS = 8192
        const val DUPLICATE_WINDOW_MILLIS = 10 * 60 * 1000L
        const val MAX_RECENT_ACKNOWLEDGEMENTS = 32
    }
}
