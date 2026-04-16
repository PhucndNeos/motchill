package com.motchill.androidcompose.feature.account

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
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
fun AccountScreen(
    onOpenAuth: () -> Unit,
    onBack: () -> Unit,
) {
    val viewModel: AccountViewModel = viewModel()
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(uiState.authState) {
        if (uiState.authState is com.motchill.androidcompose.core.supabase.AuthState.SignedOut) {
            onOpenAuth()
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
                    text = "Tài khoản",
                    style = MaterialTheme.typography.headlineSmall,
                    color = Color.White,
                )
                when (val state = uiState.authState) {
                    is com.motchill.androidcompose.core.supabase.AuthState.SignedIn -> {
                        Text(
                            text = state.user.email ?: state.user.displayTitle,
                            color = Color.White.copy(alpha = 0.85f),
                        )
                        AccountActionButton(
                            text = "Đăng xuất",
                            enabled = !uiState.isSigningOut,
                            onClick = viewModel::signOut,
                        )
                    }
                    is com.motchill.androidcompose.core.supabase.AuthState.Loading -> {
                        Text(text = "Đang kiểm tra phiên đăng nhập...", color = Color.White.copy(alpha = 0.8f))
                    }
                    else -> {
                        Text(
                            text = "Bạn chưa đăng nhập. Đăng nhập để đồng bộ liked movies và playback progress.",
                            color = Color.White.copy(alpha = 0.8f),
                        )
                        AccountActionButton(
                            text = "Đăng nhập",
                            enabled = true,
                            onClick = onOpenAuth,
                        )
                    }
                }
                AccountActionButton(
                    text = "Quay lại",
                    enabled = true,
                    onClick = onBack,
                )
            }
        }
    }
}

@Composable
private fun AccountActionButton(
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
            modifier = Modifier
                .background(
                    color = Color.White.copy(alpha = 0.04f),
                    shape = RoundedCornerShape(14.dp),
                )
                .padding(horizontal = 18.dp, vertical = 12.dp),
        ) {
            Text(
                text = text,
                color = Color.White,
            )
        }
    }
}
