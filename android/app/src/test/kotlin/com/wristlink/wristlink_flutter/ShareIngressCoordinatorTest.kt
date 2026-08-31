package com.wristlink.wristlink_flutter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ShareIngressCoordinatorTest {
    @Test
    fun persistsBeforeReturningAndAcknowledgesCleanup() {
        val store = FakeShareIngressStore()
        val coordinator = ShareIngressCoordinator(store, { 1_700_000_000_000L }, { "record-1" })

        val record = coordinator.ingest("https://maps.app.goo.gl/redacted")

        assertEquals("record-1", record?.id)
        assertEquals("https://maps.app.goo.gl/redacted", store.records().single().content)
        assertTrue(store.saveCalls > 0)
        assertTrue(coordinator.acknowledge("record-1"))
        assertTrue(store.records().isEmpty())
        assertFalse(coordinator.acknowledge("record-1"))
    }

    @Test
    fun ignoresMalformedAndBoundsLargeExtras() {
        val store = FakeShareIngressStore()
        val coordinator = ShareIngressCoordinator(store, { 1L }, { "id" })

        assertNull(coordinator.ingest(null))
        assertNull(coordinator.ingest("   "))
        assertEquals(8192, coordinator.ingest("x".repeat(9000))?.content?.length)
    }

    @Test
    fun suppressesPendingAndRecentlyAcknowledgedDuplicates() {
        var now = 1000L
        var id = 0
        val store = FakeShareIngressStore()
        val coordinator = ShareIngressCoordinator(store, { now }, { "id-${++id}" })

        assertEquals("id-1", coordinator.ingest("same")?.id)
        assertNull(coordinator.ingest("same"))
        assertTrue(coordinator.acknowledge("id-1"))
        assertNull(coordinator.ingest("same"))

        now += 11 * 60 * 1000L
        assertEquals("id-2", coordinator.ingest("same")?.id)
    }

    @Test(expected = IllegalStateException::class)
    fun surfacesPersistenceFailureBeforeDelivery() {
        val store = FakeShareIngressStore(saveSucceeds = false)
        ShareIngressCoordinator(store).ingest("point")
    }
}

private class FakeShareIngressStore(
    private val saveSucceeds: Boolean = true,
) : ShareIngressStore {
    private var storedRecords = emptyList<SharedContentRecordData>()
    private var storedAcknowledgements = emptyMap<String, Long>()
    var saveCalls = 0

    override fun records(): List<SharedContentRecordData> = storedRecords

    override fun save(records: List<SharedContentRecordData>): Boolean {
        saveCalls += 1
        if (saveSucceeds) storedRecords = records
        return saveSucceeds
    }

    override fun recentAcknowledgements(): Map<String, Long> = storedAcknowledgements

    override fun saveRecentAcknowledgements(values: Map<String, Long>): Boolean {
        if (saveSucceeds) storedAcknowledgements = values
        return saveSucceeds
    }
}
