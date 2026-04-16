package com.motchill.androidcompose.core.supabase

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertNotEquals
import org.junit.Test
import java.util.concurrent.Executors

@OptIn(ExperimentalCoroutinesApi::class)
class SupabaseAuthManagerTest {
    private val mainExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "main")
    }
    private val mainDispatcher = mainExecutor.asCoroutineDispatcher()

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        mainDispatcher.close()
        mainExecutor.shutdownNow()
    }

    @Test
    fun sendOtpRunsNetworkOffMainThread() = runBlocking {
        Dispatchers.setMain(mainDispatcher)
        val sessionStore = FakeSessionStore()
        val client = RecordingNetworkClient()
        val manager = SupabaseAuthManager(
            sessionStore = sessionStore,
            client = client,
        )

        runBlocking(Dispatchers.Main) {
            manager.sendOTP("test@example.com")
        }

        assertNotEquals("main", client.sendOtpThreadName)
    }

    private class FakeSessionStore : SupabaseSessionRepository {
        override fun load(): SupabaseSession? = null
        override fun save(session: SupabaseSession) = Unit
        override fun clear() = Unit
    }

    private class RecordingNetworkClient : SupabaseNetworkClient {
        var sendOtpThreadName: String = ""

        override suspend fun sendOtp(email: String) {
            sendOtpThreadName = Thread.currentThread().name
        }

        override suspend fun verifyOtp(email: String, token: String): SupabaseSession {
            error("Not used")
        }

        override suspend fun fetchCurrentUser(accessToken: String): UserSummary? {
            error("Not used")
        }
    }
}
