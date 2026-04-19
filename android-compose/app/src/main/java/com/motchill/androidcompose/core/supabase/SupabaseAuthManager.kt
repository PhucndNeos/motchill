package com.motchill.androidcompose.core.supabase
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.auth.user.UserSession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.datetime.Instant
import kotlin.time.Duration.Companion.seconds
import kotlin.time.ExperimentalTime

class SupabaseAuthManager(
    private val networkClient: SupabaseNetworkClient,
    private val sessionStore: SupabaseSessionRepository,
) : AuthSessionProvider {
    private val client: SupabaseClient get() = networkClient.supabaseClient
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val _state = MutableStateFlow<AuthState>(AuthState.Loading)
    private var syncCoordinator: SyncCoordinator? = null

    val state: StateFlow<AuthState> = _state.asStateFlow()

    init {
        scope.launch {
            // Restore session from store
            val savedSession = withContext(Dispatchers.IO) { sessionStore.load() }
            if (savedSession != null) {
                try {
                    @OptIn(ExperimentalTime::class)
                    val userSession = UserSession(
                        accessToken = savedSession.accessToken,
                        refreshToken = savedSession.refreshToken,
                        expiresIn = (savedSession.expiresAtEpochSeconds - System.currentTimeMillis() / 1000L).coerceAtLeast(0L),
                        tokenType = savedSession.tokenType,
                        user = null, 
                        expiresAt = Instant.fromEpochSeconds(savedSession.expiresAtEpochSeconds),
                    )
                    client.auth.importSession(userSession)
                    
                    // Chủ động refresh nếu session sắp hết hạn hoặc để đảm bảo tính ổn định
                    if (savedSession.isExpired || (savedSession.expiresAtEpochSeconds - System.currentTimeMillis() / 1000L) < 300) {
                        client.auth.refreshCurrentSession()
                    }

                    _state.value = AuthState.SignedIn(savedSession.user)
                } catch (e: Exception) {
                    _state.value = AuthState.SignedOut
                }
            } else {
                _state.value = AuthState.SignedOut
            }

            observeSessionStatus()
        }
    }

    @OptIn(ExperimentalTime::class)
    private suspend fun observeSessionStatus() {
        client.auth.sessionStatus.collectLatest { status ->
            when (status) {
                is SessionStatus.Authenticated -> {
                    val session = status.session
                    val user = session.user
                    if (user != null) {
                        val userSummary = UserSummary(user.id, user.email)
                        
                        // Persist session
                        withContext(Dispatchers.IO) {
                            sessionStore.save(
                                SupabaseSession(
                                    accessToken = session.accessToken,
                                    refreshToken = session.refreshToken ?: "",
                                    tokenType = session.tokenType,
                                    expiresAtEpochSeconds = session.expiresAt.epochSeconds,
                                    user = userSummary,
                                )
                            )
                        }

                        emitSignedIn(userSummary)
                        syncCoordinator?.runMigrationIfNeeded()
                    }
                }
                is SessionStatus.NotAuthenticated -> {
                    withContext(Dispatchers.IO) { sessionStore.clear() }
                    emitSignedOut()
                }
                else -> {
                    // Other states: LoadingFromStorage, NetworkError, etc.
                }
            }
        }
    }

    fun attachSyncCoordinator(syncCoordinator: SyncCoordinator) {
        this.syncCoordinator = syncCoordinator
    }

    suspend fun sendOTP(email: String) {
        withContext(Dispatchers.IO) {
            networkClient.sendOtp(email)
        }
    }

    fun saveEmail(email: String) {
        sessionStore.saveEmail(email)
    }

    fun getLastEmail(): String? {
        return sessionStore.loadEmail()
    }

    suspend fun verifyOTP(email: String, token: String) {
        withContext(Dispatchers.IO) {
            networkClient.verifyOtp(email, token)
        }
    }

    suspend fun signOut() {
        withContext(Dispatchers.IO) {
            client.auth.signOut()
        }
    }

    suspend fun refreshSession() {
        withContext(Dispatchers.IO) {
            try {
                val session = client.auth.currentSessionOrNull()
                if (session?.user != null) {
                    client.auth.refreshCurrentSession()
                    _state.value = AuthState.SignedIn(session.user!!.toUserSummary())
                    syncCoordinator?.runMigrationIfNeeded()
                } else {
                    _state.value = AuthState.SignedOut
                }
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    override val isAuthenticated: Boolean
        get() = currentUser != null

    override val userId: String?
        get() = currentUser?.id

    override val accessToken: String?
        get() = client.auth.currentSessionOrNull()?.accessToken

    override val currentUser: UserSummary?
        get() = when (val s = _state.value) {
            is AuthState.SignedIn -> s.user
            else -> {
                client.auth.currentUserOrNull()?.let {
                    UserSummary(it.id, it.email)
                }
            }
        }

    private fun emitSignedIn(user: UserSummary) {
        _state.value = AuthState.SignedIn(user)
    }

    private fun emitSignedOut() {
        _state.value = AuthState.SignedOut
    }

    private fun io.github.jan.supabase.auth.user.UserInfo.toUserSummary(): UserSummary {
        return UserSummary(id = this.id, email = this.email)
    }
}
