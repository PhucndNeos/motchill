package com.motchill.androidcompose.domain.model

data class PlayTrack(
    val kind: String,
    val file: String,
    val label: String,
    val isDefault: Boolean,
) {
    val displayLabel: String
        get() {
            val trimmedLabel = label.trim()
            if (trimmedLabel.isNotEmpty()) return trimmedLabel
            val trimmedFile = file.trim()
            if (trimmedFile.isNotEmpty()) return trimmedFile
            val trimmedKind = kind.trim()
            return if (trimmedKind.isNotEmpty()) trimmedKind else "Track"
        }

    val isAudio: Boolean
        get() = matchesTrackKind(kind, "audio")

    val isSubtitle: Boolean
        get() = matchesTrackKind(kind, "subtitle") || matchesTrackKind(kind, "sub")
}

data class PlaySource(
    val sourceId: Int,
    val serverName: String,
    val link: String,
    val subtitle: String,
    val type: Int,
    val isFrame: Boolean,
    val quality: String,
    val tracks: List<PlayTrack>,
) {
    val displayName: String
        get() = buildList {
            if (serverName.trim().isNotEmpty()) add(serverName.trim())
            if (quality.trim().isNotEmpty()) add(quality.trim())
            add(if (isFrame) "iframe" else "stream")
        }.joinToString(" • ")

    val audioTracks: List<PlayTrack>
        get() = tracks.filter { it.isAudio }

    val subtitleTracks: List<PlayTrack>
        get() = tracks.filter { it.isSubtitle }

    val hasAudioTracks: Boolean
        get() = audioTracks.isNotEmpty()

    val hasSubtitleTracks: Boolean
        get() = subtitleTracks.isNotEmpty()

    val defaultAudioTrack: PlayTrack?
        get() = audioTracks.firstOrNull { it.isDefault }

    val defaultSubtitleTrack: PlayTrack?
        get() = subtitleTracks.firstOrNull { it.isDefault }

    val isStream: Boolean
        get() = !isFrame
}

private fun matchesTrackKind(kind: String, expected: String): Boolean {
    val normalizedKind = kind.trim().lowercase()
    val normalizedExpected = expected.trim().lowercase()
    return normalizedKind.contains(normalizedExpected)
}

