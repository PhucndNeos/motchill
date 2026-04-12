package com.motchill.androidcompose.core.config

import java.io.IOException
import org.junit.Assert.assertEquals
import org.junit.After
import org.junit.Assert.fail
import org.junit.Test
import kotlinx.coroutines.test.runTest

class RemoteConfigStoreTest {
    @After
    fun tearDown() {
        RemoteConfigStore.clear()
    }

    @Test
    fun parsesDomainAndKeyFromJson() {
        val config = RemoteConfigStore.parse(
            """
            {
              "domain": "https://motchilltv.date",
              "key": "secret-value"
            }
            """.trimIndent(),
        )

        assertEquals("https://motchilltv.date", config.domain)
        assertEquals("secret-value", config.key)
    }

    @Test
    fun parseRejectsMissingFields() {
        try {
            RemoteConfigStore.parse(
                """
                {
                  "domain": "https://motchilltv.date"
                }
                """.trimIndent(),
            )
            fail("Expected IllegalArgumentException")
        } catch (error: IllegalArgumentException) {
            assertEquals("Remote config is missing key", error.message)
        }
    }

    @Test
    fun refreshKeepsExistingConfigWhenFetcherFails() = runTest {
        val previous = RemoteConfig(
            domain = "https://old.example",
            key = "old-key",
        )
        RemoteConfigStore.setCurrentConfig(previous)

        try {
            RemoteConfigStore.refreshFromRemote {
                throw IOException("network down")
            }
            fail("Expected IOException")
        } catch (error: IOException) {
            assertEquals("network down", error.message)
        }

        assertEquals("https://old.example", RemoteConfigStore.requireBaseUrl())
        assertEquals("old-key", RemoteConfigStore.requireKey())
    }
}
