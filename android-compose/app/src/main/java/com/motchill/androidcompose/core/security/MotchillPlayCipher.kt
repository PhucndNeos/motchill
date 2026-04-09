package com.motchill.androidcompose.core.security

import com.motchill.androidcompose.data.remote.toPlaySource
import com.motchill.androidcompose.domain.model.PlaySource

object MotchillPlayCipher {
    fun decodeSources(encryptedPayload: String): List<PlaySource> {
        return MotchillPayloadCipher.decodeList(encryptedPayload) { it.toPlaySource() }
    }
}

