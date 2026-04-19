package com.motchill.androidcompose.app

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.analytics.ktx.analytics
import com.google.firebase.analytics.logEvent
import com.google.firebase.ktx.Firebase
import com.motchill.androidcompose.BuildConfig
import com.motchill.androidcompose.core.designsystem.PhucTVTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Log app start events
        try {
            val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
            val isTv = uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
            val platform = if (isTv) "android_tv" else "android_mobile"
            val appVersion = BuildConfig.VERSION_NAME

            Firebase.analytics.setUserProperty("device_platform", platform)
            Firebase.analytics.logEvent(FirebaseAnalytics.Event.APP_OPEN, null)
            Firebase.analytics.logEvent("phuctv_app_start") {
                param("platform", platform)
                param("app_version", appVersion)
            }
            Log.d("PhucTV_Analytics", "Firebase events logged: platform=$platform, version=$appVersion")
        } catch (e: Exception) {
            Log.e("PhucTV_Analytics", "Failed to log Firebase events", e)
        }

        // Uncomment the line below to test Firebase Crashlytics
        // throw RuntimeException("Test Crashlytics from PhucTV App")

        setContent {
            PhucTVTheme {
                PhucTVApp()
            }
        }
    }
}

