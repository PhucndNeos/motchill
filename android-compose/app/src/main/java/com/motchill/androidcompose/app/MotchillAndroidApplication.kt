package com.motchill.androidcompose.app

import android.app.Application
import com.motchill.androidcompose.app.di.MotchillAppContainer

class MotchillAndroidApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        MotchillAppContainer.initialize(this)
    }
}
