package com.motchill.androidcompose.core.supabase

import android.content.Context
import androidx.core.content.edit
import org.json.JSONObject

class SupabaseSessionStore(context: Context) : SupabaseSessionRepository {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun load(): SupabaseSession? {
        val raw = prefs.getString(KEY_SESSION, null).orEmpty()
        if (raw.isBlank()) return null
        return runCatching { raw.toSession() }.getOrNull()
    }

    override fun save(session: SupabaseSession) {
        prefs.edit {
            putString(KEY_SESSION, session.toJson())
        }
    }

    override fun clear() {
        prefs.edit { remove(KEY_SESSION) }
    }

    private companion object {
        const val PREFS_NAME = "motchill_supabase_session"
        const val KEY_SESSION = "session"
    }
}

private fun SupabaseSession.toJson(): String {
    return JSONObject()
        .put("accessToken", accessToken)
        .put("refreshToken", refreshToken)
        .put("tokenType", tokenType)
        .put("expiresAtEpochSeconds", expiresAtEpochSeconds)
        .put(
            "user",
            JSONObject()
                .put("id", user.id)
                .put("email", user.email),
        )
        .toString()
}

private fun String.toSession(): SupabaseSession {
    val obj = JSONObject(this)
    val userObj = obj.getJSONObject("user")
    return SupabaseSession(
        accessToken = obj.getString("accessToken"),
        refreshToken = obj.optString("refreshToken"),
        tokenType = obj.optString("tokenType", "bearer"),
        expiresAtEpochSeconds = obj.optLong("expiresAtEpochSeconds", 0L),
        user = UserSummary(
            id = userObj.optString("id"),
            email = userObj.optString("email").takeIf { it.isNotBlank() },
        ),
    )
}
