package com.motchill.androidcompose.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.motchill.androidcompose.app.di.PhucTVAppContainer
import com.motchill.androidcompose.core.supabase.AuthState
import com.motchill.androidcompose.core.supabase.SupabaseAuthManager
import com.motchill.androidcompose.core.supabase.UserSummary
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class AuthUiState(
    val email: String = "",
    val otp: String = "",
    val isOtpStep: Boolean = false,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val authState: AuthState = AuthState.Loading,
) {
    val currentUser: UserSummary?
        get() = (authState as? AuthState.SignedIn)?.user
}

class AuthViewModel(
    private val authManager: SupabaseAuthManager = PhucTVAppContainer.authManager,
) : ViewModel() {
    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            authManager.state.collect { state ->
                _uiState.value = _uiState.value.copy(
                    authState = state,
                    isLoading = false,
                    errorMessage = when (state) {
                        is AuthState.Error -> state.message
                        else -> _uiState.value.errorMessage
                    },
                )
            }
        }
    }

    fun onEmailChanged(value: String) {
        _uiState.value = _uiState.value.copy(email = value, errorMessage = null)
    }

    fun onOtpChanged(value: String) {
        _uiState.value = _uiState.value.copy(otp = value, errorMessage = null)
    }

    fun editEmail() {
        _uiState.value = _uiState.value.copy(
            isOtpStep = false,
            otp = "",
            errorMessage = null,
        )
    }

    fun sendOtp() {
        val email = _uiState.value.email.trim()
        if (email.isBlank()) {
            _uiState.value = _uiState.value.copy(errorMessage = "Enter your email address")
            return
        }
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            runCatching {
                authManager.sendOTP(email)
            }.onSuccess {
                _uiState.value = _uiState.value.copy(isLoading = false, isOtpStep = true)
            }.onFailure { error ->
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = error.message ?: error::class.java.simpleName,
                )
            }
        }
    }

    fun verifyOtp() {
        val email = _uiState.value.email.trim()
        val otp = _uiState.value.otp.trim()
        if (email.isBlank() || otp.length < 6) {
            _uiState.value = _uiState.value.copy(errorMessage = "Enter at least 6 characters")
            return
        }
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            runCatching {
                authManager.verifyOTP(email, otp)
            }.onSuccess {
                _uiState.value = _uiState.value.copy(isLoading = false)
            }.onFailure { error ->
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = error.message ?: error::class.java.simpleName,
                )
            }
        }
    }
}
