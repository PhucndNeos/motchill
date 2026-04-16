package com.motchill.androidcompose.feature.account

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.motchill.androidcompose.app.di.PhucTVAppContainer
import com.motchill.androidcompose.core.supabase.AuthState
import com.motchill.androidcompose.core.supabase.SupabaseAuthManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class AccountUiState(
    val authState: AuthState = AuthState.Loading,
    val isSigningOut: Boolean = false,
) {
    val signedInEmail: String?
        get() = (authState as? AuthState.SignedIn)?.user?.email
}

class AccountViewModel(
    private val authManager: SupabaseAuthManager = PhucTVAppContainer.authManager,
) : ViewModel() {
    private val _uiState = MutableStateFlow(AccountUiState())
    val uiState: StateFlow<AccountUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            authManager.state.collect { state ->
                _uiState.value = _uiState.value.copy(authState = state, isSigningOut = false)
            }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSigningOut = true)
            runCatching { authManager.signOut() }
                .onFailure {
                    _uiState.value = _uiState.value.copy(isSigningOut = false)
                }
        }
    }
}
