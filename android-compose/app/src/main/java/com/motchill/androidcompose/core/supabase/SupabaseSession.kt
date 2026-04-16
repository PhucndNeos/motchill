package com.motchill.androidcompose.core.supabase

data class SupabaseSession(
    val accessToken: String,
    val refreshToken: String,
    val tokenType: String,
    val expiresAtEpochSeconds: Long,
    val user: UserSummary,
) {
    val isExpired: Boolean
        get() = expiresAtEpochSeconds > 0 && System.currentTimeMillis() / 1000L >= expiresAtEpochSeconds
}
