package com.wristlink.wristlink_flutter

import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ShareIngressLifecycleInstrumentedTest {
    private lateinit var context: Context

    @Before
    fun clearIngressState() {
        context = ApplicationProvider.getApplicationContext()
        sharedContentPreferences().edit().clear().commit()
    }

    @After
    fun cleanUpIngressState() {
        sharedContentPreferences().edit().clear().commit()
    }

    @Test
    fun adapterPersistsBeforeFlutterAndHandlesMalformedDuplicateAndAcknowledgedContent() {
        val bridge = ShareIngressBridge(context)
        val coordinator =
            ShareIngressCoordinator(SharedPreferencesShareIngressStore(context))
        val sharedText = "Shared place\nhttps://www.google.com/maps/@52.5200,13.4050,15z"

        assertTrue(bridge.accept(shareIntent(sharedText)))
        assertEquals(sharedText, coordinator.pending().single().content)

        assertTrue(bridge.accept(shareIntent(sharedText)))
        assertEquals(1, coordinator.pending().size)

        val id = coordinator.pending().single().id
        assertTrue(coordinator.acknowledge(id))
        assertTrue(coordinator.pending().isEmpty())
        assertTrue(bridge.accept(shareIntent(sharedText)))
        assertTrue(coordinator.pending().isEmpty())

        assertTrue(bridge.accept(shareIntent("x".repeat(9000))))
        assertEquals(8192, coordinator.pending().single().content.length)

        assertFalse(bridge.accept(Intent(Intent.ACTION_SEND).setType("text/plain")))
        assertFalse(bridge.accept(Intent(Intent.ACTION_VIEW)))
        assertFalse(bridge.accept(shareIntent("point").setType("image/png")))
    }

    @Test
    fun coldStartConsumesAndClearsTheShareIntent() {
        val lifecycle = ShareIntentLifecycle(ShareIngressBridge(context)::accept, context.packageName)

        val replacement = lifecycle.replacementFor(shareIntent("geo:52.5200,13.4050"))

        assertEquals(Intent.ACTION_MAIN, replacement?.action)
        assertEquals(context.packageName, replacement?.`package`)
        assertEquals(
            "geo:52.5200,13.4050",
            ShareIngressCoordinator(SharedPreferencesShareIngressStore(context)).pending().single().content,
        )
    }

    @Test
    fun warmSingleTopDeliveryConsumesAndClearsTheNewShareIntent() {
        val lifecycle = ShareIntentLifecycle(ShareIngressBridge(context)::accept, context.packageName)

        assertEquals(null, lifecycle.replacementFor(Intent(Intent.ACTION_MAIN)))
        val replacement = lifecycle.replacementFor(shareIntent("geo:48.1372,11.5756"))

        assertEquals(Intent.ACTION_MAIN, replacement?.action)
        assertEquals(
            "geo:48.1372,11.5756",
            ShareIngressCoordinator(SharedPreferencesShareIngressStore(context)).pending().single().content,
        )
    }

    @Test
    fun nonShareLaunchKeepsNormalActivityIntentState() {
        val lifecycle = ShareIntentLifecycle(ShareIngressBridge(context)::accept, context.packageName)

        assertEquals(null, lifecycle.replacementFor(Intent(Intent.ACTION_VIEW)))
        assertTrue(ShareIngressCoordinator(SharedPreferencesShareIngressStore(context)).pending().isEmpty())
    }

    private fun shareIntent(content: String): Intent =
        Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_SEND
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, content)
        }

    private fun sharedContentPreferences() =
        context.getSharedPreferences("wristlink_shared_content", Context.MODE_PRIVATE)
}
