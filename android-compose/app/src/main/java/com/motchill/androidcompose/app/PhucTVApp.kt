package com.motchill.androidcompose.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import com.motchill.androidcompose.core.navigation.AppNavHost
import com.motchill.androidcompose.app.di.PhucTVAppContainer

@Composable
fun PhucTVApp() {
    remember {
        PhucTVAppContainer.syncCoordinator
    }
    LaunchedEffect(Unit) {
        PhucTVAppContainer.authManager.refreshSession()
    }
    AppNavHost()
}
