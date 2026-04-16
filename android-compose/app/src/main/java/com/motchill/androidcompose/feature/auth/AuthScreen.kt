package com.motchill.androidcompose.feature.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.motchill.androidcompose.core.designsystem.PhucTVFocusCard
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun AuthScreen(
    onDone: () -> Unit,
    onBack: () -> Unit,
) {
    val viewModel: AuthViewModel = viewModel()
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(uiState.authState) {
        if (uiState.authState is com.motchill.androidcompose.core.supabase.AuthState.SignedIn) {
            onDone()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(Color(0xFF111111), Color(0xFF060606)),
                ),
            )
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .widthIn(max = 560.dp),
            colors = CardDefaults.cardColors(containerColor = Color.White.copy(alpha = 0.04f)),
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text(
                    text = "Đăng nhập để đồng bộ",
                    style = MaterialTheme.typography.headlineSmall,
                    color = Color.White,
                )
                if (uiState.isOtpStep) {
                    Text(
                        text = "Mã OTP đã được gửi tới ${uiState.email}. Nhập mã bạn nhận được để hoàn tất đăng nhập.",
                        color = Color.White.copy(alpha = 0.75f),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    OutlinedTextField(
                        value = uiState.otp,
                        onValueChange = viewModel::onOtpChanged,
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Mã OTP") },
                        singleLine = true,
                        colors = authTextFieldColors(),
                    )
                } else {
                    Text(
                        text = "Nhập email để nhận mã OTP. Sau khi đăng nhập, liked movies và tiến trình xem sẽ đồng bộ lên Supabase.",
                        color = Color.White.copy(alpha = 0.75f),
                        style = MaterialTheme.typography.bodyMedium,
                    )

                    OutlinedTextField(
                        value = uiState.email,
                        onValueChange = viewModel::onEmailChanged,
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Email") },
                        singleLine = true,
                        colors = authTextFieldColors(),
                    )
                }

                uiState.errorMessage?.let { message ->
                    Text(text = message, color = Color(0xFFFFB4A9))
                }

                if (uiState.isOtpStep) {
                    AuthActionButton(
                        text = "Xác nhận",
                        enabled = !uiState.isLoading,
                        onClick = viewModel::verifyOtp,
                    )
                    AuthActionButton(
                        text = "Đổi email",
                        enabled = !uiState.isLoading,
                        onClick = viewModel::editEmail,
                    )
                } else {
                    AuthActionButton(
                        text = "Gửi mã OTP",
                        enabled = !uiState.isLoading,
                        onClick = viewModel::sendOtp,
                    )
                }

                AuthActionButton(
                    text = "Quay lại",
                    enabled = !uiState.isLoading,
                    onClick = onBack,
                )
            }
        }
    }
}

@Composable
private fun AuthActionButton(
    text: String,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    PhucTVFocusCard(
        onClick = onClick,
        enabled = enabled,
        borderRadius = RoundedCornerShape(14.dp),
        focusedBorderColor = Color(0xFFFFD15C),
        focusScale = 1.02f,
    ) {
        Box(
            modifier = Modifier.background(
                color = Color.White.copy(alpha = 0.04f),
                shape = RoundedCornerShape(14.dp),
            ),
        ) {
            Text(
                text = text,
                modifier = Modifier.padding(horizontal = 18.dp, vertical = 12.dp),
                color = Color.White,
            )
        }
    }
}

@Composable
private fun authTextFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = Color(0xFFFFD15C),
    unfocusedBorderColor = Color.White.copy(alpha = 0.18f),
    focusedLabelColor = Color(0xFFFFD15C),
    unfocusedLabelColor = Color.White.copy(alpha = 0.72f),
    cursorColor = Color(0xFFFFD15C),
    focusedTextColor = Color.White,
    unfocusedTextColor = Color.White,
)
