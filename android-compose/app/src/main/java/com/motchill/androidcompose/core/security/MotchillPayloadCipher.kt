package com.motchill.androidcompose.core.security

import com.motchill.androidcompose.core.config.RemoteConfigStore
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

object MotchillPayloadCipher {
    fun decrypt(encryptedPayload: String): String {
        val data = Base64.getDecoder().decode(encryptedPayload.trim())
        require(data.size >= 17) { "Encrypted payload is too short" }

        val header = data.copyOfRange(0, 8).toString(Charsets.UTF_8)
        require(header == "Salted__") { "Encrypted payload is missing Salted__ header" }

        val salt = data.copyOfRange(8, 16)
        val ciphertext = data.copyOfRange(16, data.size)
        val keyIv = evpBytesToKey(
            passphrase = RemoteConfigStore.requireKey().toByteArray(Charsets.UTF_8),
            salt = salt,
            keyLength = 32,
            ivLength = 16,
        )

        val key = SecretKeySpec(keyIv.copyOfRange(0, 32), "AES")
        val iv = IvParameterSpec(keyIv.copyOfRange(32, 48))
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        cipher.init(Cipher.DECRYPT_MODE, key, iv)
        return cipher.doFinal(ciphertext).toString(Charsets.UTF_8)
    }

    fun decodeJsonObject(encryptedPayload: String): JSONObject {
        return JSONObject(decrypt(encryptedPayload))
    }

    fun decodeJsonArray(encryptedPayload: String): JSONArray {
        return JSONArray(decrypt(encryptedPayload))
    }

    inline fun <T> decodeList(
        encryptedPayload: String,
        mapper: (JSONObject) -> T,
    ): List<T> {
        val array = decodeJsonArray(encryptedPayload)
        return buildList(array.length()) {
            for (index in 0 until array.length()) {
                val item = array.opt(index)
                when (item) {
                    is JSONObject -> add(mapper(item))
                    is Map<*, *> -> {
                        @Suppress("UNCHECKED_CAST")
                        add(mapper(JSONObject(item as Map<String, Any?>)))
                    }
                }
            }
        }
    }

    private fun evpBytesToKey(
        passphrase: ByteArray,
        salt: ByteArray,
        keyLength: Int,
        ivLength: Int,
    ): ByteArray {
        val targetLength = keyLength + ivLength
        val output = ArrayList<Byte>(targetLength)
        var previous = ByteArray(0)

        while (output.size < targetLength) {
            val digest = MessageDigest.getInstance("MD5").digest(previous + passphrase + salt)
            output.addAll(digest.toList())
            previous = digest
        }

        return output.take(targetLength).toByteArray()
    }
}

