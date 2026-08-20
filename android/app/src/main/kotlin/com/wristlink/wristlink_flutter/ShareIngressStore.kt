package com.wristlink.wristlink_flutter

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

internal data class SharedContentRecordData(
    val id: String,
    val receivedAt: String,
    val content: String,
    val fingerprint: String,
) {
    fun channelMap(): Map<String, Any> =
        mapOf(
            "id" to id,
            "receivedAt" to receivedAt,
            "platform" to "android",
            "content" to content,
        )
}

internal interface ShareIngressStore {
    fun records(): List<SharedContentRecordData>

    fun save(records: List<SharedContentRecordData>): Boolean

    fun recentAcknowledgements(): Map<String, Long>

    fun saveRecentAcknowledgements(values: Map<String, Long>): Boolean
}

internal class SharedPreferencesShareIngressStore(context: Context) : ShareIngressStore {
    private val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    override fun records(): List<SharedContentRecordData> {
        val encoded = preferences.getString(RECORDS_KEY, null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(encoded)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    val id = item.optString("id")
                    val receivedAt = item.optString("receivedAt")
                    val content = item.optString("content")
                    val fingerprint = item.optString("fingerprint")
                    if (id.isNotBlank() && receivedAt.isNotBlank() && content.isNotBlank() && fingerprint.isNotBlank()) {
                        add(SharedContentRecordData(id, receivedAt, content, fingerprint))
                    }
                }
            }
        }.getOrDefault(emptyList())
    }

    override fun save(records: List<SharedContentRecordData>): Boolean {
        val array = JSONArray()
        records.forEach { record ->
            array.put(
                JSONObject()
                    .put("id", record.id)
                    .put("receivedAt", record.receivedAt)
                    .put("content", record.content)
                    .put("fingerprint", record.fingerprint),
            )
        }
        return preferences.edit().putString(RECORDS_KEY, array.toString()).commit()
    }

    override fun recentAcknowledgements(): Map<String, Long> {
        val encoded = preferences.getString(ACKNOWLEDGEMENTS_KEY, null) ?: return emptyMap()
        return runCatching {
            val objectValue = JSONObject(encoded)
            buildMap {
                objectValue.keys().forEach { key -> put(key, objectValue.getLong(key)) }
            }
        }.getOrDefault(emptyMap())
    }

    override fun saveRecentAcknowledgements(values: Map<String, Long>): Boolean {
        val objectValue = JSONObject()
        values.forEach { (fingerprint, timestamp) -> objectValue.put(fingerprint, timestamp) }
        return preferences.edit().putString(ACKNOWLEDGEMENTS_KEY, objectValue.toString()).commit()
    }

    private companion object {
        const val PREFERENCES_NAME = "wristlink_shared_content"
        const val RECORDS_KEY = "records"
        const val ACKNOWLEDGEMENTS_KEY = "recent_acknowledgements"
    }
}
