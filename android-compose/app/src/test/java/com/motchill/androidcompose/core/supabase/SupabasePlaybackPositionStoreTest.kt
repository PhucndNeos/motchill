package com.motchill.androidcompose.core.supabase

import com.motchill.androidcompose.core.storage.PlaybackProgressSnapshot
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SupabasePlaybackPositionStoreTest {
    @Test
    fun `remote ahead or equal skips write`() {
        val local = PlaybackProgressSnapshot(positionMillis = 30_000, durationMillis = 120_000)
        val remote = PlaybackProgressSnapshot(positionMillis = 45_000, durationMillis = 120_000)

        assertFalse(SupabasePlaybackPositionStore.shouldWriteRemote(local, remote))
    }

    @Test
    fun `local ahead writes remote`() {
        val local = PlaybackProgressSnapshot(positionMillis = 50_000, durationMillis = 120_000)
        val remote = PlaybackProgressSnapshot(positionMillis = 45_000, durationMillis = 120_000)

        assertTrue(SupabasePlaybackPositionStore.shouldWriteRemote(local, remote))
    }
}
