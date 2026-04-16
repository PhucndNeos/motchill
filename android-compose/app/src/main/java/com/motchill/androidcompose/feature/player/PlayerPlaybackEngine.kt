package com.motchill.androidcompose.feature.player

import android.util.Log
import android.content.Context
import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.Player
import androidx.media3.common.PlaybackException
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.source.MergingMediaSource
import com.motchill.androidcompose.core.storage.PlaybackPositionStore
import com.motchill.androidcompose.domain.model.PlaySource
import com.motchill.androidcompose.domain.model.PlayTrack
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import java.util.Locale
import kotlin.math.abs

data class PlayerRuntimeState(
    val positionMs: Long = 0L,
    val durationMs: Long = 0L,
    val bufferedPositionMs: Long = 0L,
    val isPlaying: Boolean = false,
    val isBuffering: Boolean = true,
    val isReady: Boolean = false,
    val errorMessage: String? = null,
)

@UnstableApi
class PlayerPlaybackEngine(
    context: Context,
    private val movieId: Int,
    private val episodeId: Int,
    private val positionStore: PlaybackPositionStore,
) : Player.Listener {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val mediaSourceFactory = DefaultMediaSourceFactory(playbackDataSourceFactory())
    private val _state = MutableStateFlow(PlayerRuntimeState())
    private var observationJob: Job? = null
    private var lastPersistedPositionMs: Long = 0L
    private var lastPersistedDurationMs: Long = 0L

    val player: ExoPlayer = ExoPlayer.Builder(context)
        .setMediaSourceFactory(mediaSourceFactory)
        .build()
        .apply {
            addListener(this@PlayerPlaybackEngine)
        }

    val state: StateFlow<PlayerRuntimeState> = _state.asStateFlow()

    private var currentSource: PlaySource? = null
    private var currentAudioTrack: PlayTrack? = null
    private var currentSubtitleTrack: PlayTrack? = null
    private var exitPositionSnapshotMs: Long? = null

    suspend fun load(
        source: PlaySource,
        audioTrack: PlayTrack?,
        subtitleTrack: PlayTrack?,
        startPositionMs: Long? = null,
        playWhenReady: Boolean = true,
    ) {
        Log.d(
            TAG,
            buildString {
                append("load movieId=")
                append(movieId)
                append(" episodeId=")
                append(episodeId)
                append(" source=")
                append(source.debugSummary())
                append(" audioTrack=")
                append(audioTrack?.debugSummary().orEmpty())
                append(" subtitleTrack=")
                append(subtitleTrack?.debugSummary().orEmpty())
                append(" startPositionMs=")
                append(startPositionMs)
                append(" playWhenReady=")
                append(playWhenReady)
            },
        )
        persistPosition()
        currentSource = source
        currentAudioTrack = audioTrack
        currentSubtitleTrack = subtitleTrack
        exitPositionSnapshotMs = null

        val resumePosition = when {
            startPositionMs != null -> startPositionMs
            else -> positionStore.load(movieId, episodeId)?.positionMillis ?: 0L
        }.coerceAtLeast(0L)

        val mediaSource = buildMediaSource(
            source = source,
            audioTrack = audioTrack,
            subtitleTrack = subtitleTrack,
        )

        player.stop()
        player.setMediaSource(mediaSource)
        player.prepare()
        if (resumePosition > 0L) {
            player.seekTo(resumePosition)
        }
        player.playWhenReady = playWhenReady
        Log.d(
            TAG,
            "prepared mediaItem=${player.currentMediaItem?.localConfiguration?.uri} resumePositionMs=$resumePosition playWhenReady=$playWhenReady",
        )
        startObservation()
        syncState()
    }

    fun play() {
        player.play()
        syncState()
    }

    fun pause() {
        player.pause()
        syncState()
        scope.launch { persistPosition() }
    }

    fun stopForExit() {
        scope.launch {
            flushPosition()
            stopPlaybackCore()
        }
    }

    suspend fun flushPosition() {
        val positionMs = player.currentPosition.coerceAtLeast(0L)
        exitPositionSnapshotMs = positionMs
        if (positionMs > 0L) {
            persistPosition(positionMs, player.duration.takeIf { duration -> duration > 0L } ?: 0L)
        }
    }

    fun seekTo(positionMs: Long) {
        player.seekTo(positionMs.coerceAtLeast(0L))
        syncState()
    }

    suspend fun updateTrackSelection(
        audioTrack: PlayTrack?,
        subtitleTrack: PlayTrack?,
    ) {
        val source = currentSource ?: return
        load(
            source = source,
            audioTrack = audioTrack,
            subtitleTrack = subtitleTrack,
            startPositionMs = player.currentPosition,
            playWhenReady = player.isPlaying,
        )
    }

    suspend fun release() {
        val positionMs = exitPositionSnapshotMs ?: player.currentPosition.coerceAtLeast(0L)
        persistPosition(positionMs, player.duration.takeIf { duration -> duration > 0L } ?: 0L)
        stopPlaybackCore()
        player.removeListener(this)
        player.release()
        scope.coroutineContext[Job]?.cancel()
    }

    override fun onPlayerError(error: PlaybackException) {
        Log.e(TAG, "playerError message=${error.message} code=${error.errorCode}", error)
        _state.update {
            it.copy(errorMessage = error.message ?: error::class.java.simpleName)
        }
    }

    override fun onTracksChanged(tracks: Tracks) {
        Log.d(TAG, "onTracksChanged ${tracks.debugSummary()}")
        syncState()
    }

    override fun onEvents(player: Player, events: Player.Events) {
        Log.d(
            TAG,
            buildString {
                append("onEvents playbackState=")
                append(player.playbackState)
                append(" isPlaying=")
                append(player.isPlaying)
                append(" playWhenReady=")
                append(player.playWhenReady)
                append(" mediaItem=")
                append(player.currentMediaItem?.localConfiguration?.uri)
                append(" currentTracks=")
                append(player.currentTracks.debugSummary())
            },
        )
        syncState()
    }

    private fun startObservation() {
        observationJob?.cancel()
        observationJob = scope.launch {
            while (isActive) {
                syncState()
                maybePersistPosition()
                delay(500)
            }
        }
    }

    private fun stopPlaybackCore() {
        observationJob?.cancel()
        player.playWhenReady = false
        player.pause()
        player.stop()
        syncState()
    }

    private fun syncState() {
        _state.update {
            it.copy(
                positionMs = player.currentPosition.coerceAtLeast(0L),
                durationMs = player.duration.takeIf { duration -> duration > 0L } ?: 0L,
                bufferedPositionMs = player.bufferedPosition.coerceAtLeast(0L),
                isPlaying = player.isPlaying,
                isBuffering = player.playbackState == Player.STATE_BUFFERING,
                isReady = player.playbackState == Player.STATE_READY,
                errorMessage = when (val error = player.playerError) {
                    null -> it.errorMessage
                    else -> error.message ?: error::class.java.simpleName
                },
            )
        }
    }

    private suspend fun persistPosition() {
        persistPosition(
            positionMs = player.currentPosition.coerceAtLeast(0L),
            durationMs = player.duration.takeIf { duration -> duration > 0L } ?: 0L,
        )
    }

    private suspend fun persistPosition(
        positionMs: Long,
        durationMs: Long,
    ) {
        if (positionMs <= 0L) return
        positionStore.save(movieId, episodeId, positionMs, durationMs)
        lastPersistedPositionMs = positionMs
        lastPersistedDurationMs = durationMs
    }

    private suspend fun maybePersistPosition() {
        val positionMs = player.currentPosition.coerceAtLeast(0L)
        val durationMs = player.duration.takeIf { duration -> duration > 0L } ?: 0L
        if (positionMs <= 0L && durationMs <= 0L) return
        val positionChanged = abs(positionMs - lastPersistedPositionMs) >= 15_000L
        val durationChanged = durationMs != lastPersistedDurationMs
        if (!positionChanged && !durationChanged) return
        persistPosition(positionMs, durationMs)
    }

    private fun buildMediaSource(
        source: PlaySource,
        audioTrack: PlayTrack?,
        subtitleTrack: PlayTrack?,
    ) = buildList {
        Log.d(
            TAG,
            buildString {
                append("buildMediaSource sourceId=")
                append(source.sourceId)
                append(" link=")
                append(source.link)
                append(" subtitleField=")
                append(source.subtitle)
                append(" audioTrack=")
                append(audioTrack?.debugSummary().orEmpty())
                append(" subtitleTrack=")
                append(subtitleTrack?.debugSummary().orEmpty())
            },
        )
        add(mediaSourceFactory.createMediaSource(buildVideoItem(source, subtitleTrack)))
        audioTrack?.file?.trim()?.takeIf { it.isNotEmpty() }?.let { audioUri ->
            Log.d(TAG, "merging alternate audio source uri=$audioUri")
            add(mediaSourceFactory.createMediaSource(MediaItem.fromUri(audioUri)))
        }
    }.let { sources ->
        if (sources.size == 1) sources.first() else MergingMediaSource(*sources.toTypedArray())
    }

    private fun buildVideoItem(
        source: PlaySource,
        subtitleTrack: PlayTrack?,
    ): MediaItem {
        val builder = MediaItem.Builder().setUri(Uri.parse(source.link))
        subtitleTrack?.file?.trim()?.takeIf { it.isNotEmpty() }?.let { subtitleUri ->
            builder.setSubtitleConfigurations(
                listOf(buildSubtitleConfiguration(subtitleTrack, subtitleUri)),
            )
            Log.d(TAG, "attached subtitle uri=$subtitleUri label=${subtitleTrack.displayLabel}")
        }
        return builder.build()
    }

    private fun buildSubtitleConfiguration(
        subtitleTrack: PlayTrack,
        subtitleUri: String,
    ): MediaItem.SubtitleConfiguration {
        val mimeType = when (subtitleUri.substringAfterLast('.', "").lowercase(Locale.US)) {
            "srt" -> MimeTypes.APPLICATION_SUBRIP
            "vtt" -> MimeTypes.TEXT_VTT
            else -> MimeTypes.TEXT_VTT
        }
        return MediaItem.SubtitleConfiguration.Builder(Uri.parse(subtitleUri))
            .setMimeType(mimeType)
            .setLanguage(subtitleTrack.displayLabel)
            .setSelectionFlags(if (subtitleTrack.isDefault) C.SELECTION_FLAG_DEFAULT else 0)
            .build()
    }

    private fun PlayTrack.debugSummary(): String {
        return buildString {
            append("kind=")
            append(kind)
            append(",label=")
            append(displayLabel)
            append(",default=")
            append(isDefault)
            append(",file=")
            append(file)
        }
    }

    private fun PlaySource.debugSummary(): String {
        return buildString {
            append("sourceId=")
            append(sourceId)
            append(",server=")
            append(serverName)
            append(",isFrame=")
            append(isFrame)
            append(",quality=")
            append(quality)
            append(",type=")
            append(type)
            append(",link=")
            append(link)
            append(",subtitleField=")
            append(subtitle)
            append(",tracks=")
            append(tracks.size)
            append(",audioTracks=")
            append(audioTracks.size)
            append(",subtitleTracks=")
            append(subtitleTracks.size)
            append(",defaultAudio=")
            append(defaultAudioTrack?.displayLabel.orEmpty())
            append(",defaultSubtitle=")
            append(defaultSubtitleTrack?.displayLabel.orEmpty())
        }
    }

    private fun Tracks.debugSummary(): String {
        return "groups=${groups.size}"
    }

    companion object {
        private const val TAG = "PhucTV.player"
    }
}
