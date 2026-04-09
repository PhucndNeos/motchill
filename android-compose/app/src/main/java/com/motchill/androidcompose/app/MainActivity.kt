package com.motchill.androidcompose.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.motchill.androidcompose.core.designsystem.MotchillTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MotchillTheme {
                MotchillAndroidApp()
            }
        }
    }
}

