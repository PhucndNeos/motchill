package com.motchill.androidcompose.core.supabase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class SupabaseAuthManager(
    private val sessionStore: SupabaseSessionRepository,
    private val client: SupabaseNetworkClient,
) : AuthSessionProvider {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val _state = MutableStateFlow<AuthState>(AuthState.Loading)
    private var syncCoordinator: SyncCoordinator? = null
    private var session: SupabaseSession? = sessionStore.load()

    val state: StateFlow<AuthState> = _state.asStateFlow()

    init {
        scope.launch { refreshSession() }
    }

    fun attachSyncCoordinator(syncCoordinator: SyncCoordinator) {
        this.syncCoordinator = syncCoordinator
    }

    suspend fun sendOTP(email: String) {
        withContext(Dispatchers.IO) {
            client.sendOtp(email.trim())
        }
    }

    suspend fun verifyOTP(email: String, token: String) {
        val newSession = withContext(Dispatchers.IO) {
            client.verifyOtp(email.trim(), token.trim())
        }
        persistSession(newSession)
        emitSignedIn(newSession.user)
        syncCoordinator?.runMigrationIfNeeded()
    }

    suspend fun refreshSession() {
        val current = session ?: sessionStore.load()
        if (current == null) {
            emitSignedOut()
            return
        }

        if (current.isExpired) {
            sessionStore.clear()
            session = null
            emitSignedOut()
            return
        }

        val user = withContext(Dispatchers.IO) {
            client.fetchCurrentUser(current.accessToken)
        }
        if (user == null) {
            sessionStore.clear()
            session = null
            emitSignedOut()
            return
        }

        val refreshed = current.copy(user = user)
        persistSession(refreshed)
        emitSignedIn(refreshed.user)
        syncCoordinator?.runMigrationIfNeeded()
    }

    suspend fun signOut() {
        sessionStore.clear()
        session = null
        emitSignedOut()
    }

    override val isAuthenticated: Boolean
        get() = currentUser != null

    override val userId: String?
        get() = currentUser?.id

    override val accessToken: String?
        get() = session?.accessToken

    override val currentUser: UserSummary?
        get() = when (val state = _state.value) {
            is AuthState.SignedIn -> state.user
            else -> session?.user
        }

    private fun persistSession(newSession: SupabaseSession) {
        session = newSession
        sessionStore.save(newSession)
    }

    private fun emitSignedIn(user: UserSummary) {
        _state.value = AuthState.SignedIn(user)
    }

    private fun emitSignedOut() {
        _state.value = AuthState.SignedOut
    }
}
