package com.motchill.androidcompose.feature.player

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.view.WindowManager
import androidx.annotation.OptIn
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Audiotrack
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.ChevronLeft
import androidx.compose.material.icons.outlined.Forward10
import androidx.compose.material.icons.outlined.Pause
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material.icons.outlined.Replay10
import androidx.compose.material.icons.outlined.Subtitles
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.input.key.KeyEvent
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.media3.common.util.UnstableApi
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import com.motchill.androidcompose.app.di.MotchillAppContainer
import com.motchill.androidcompose.domain.model.PlaySource
import com.motchill.androidcompose.domain.model.PlayTrack
import java.util.Locale
import kotlin.math.max
import kotlinx.coroutines.launch

@OptIn(UnstableApi::class)
@Composable
fun PlayerScreen(
    movieId: Int,
    episodeId: Int,
    movieTitle: String,
    episodeLabel: String,
    onBack: () -> Unit,
) {
    val viewModel: PlayerViewModel = viewModel(
        factory = remember(movieId, episodeId, movieTitle, episodeLabel) {
            PlayerViewModel.factory(
                repository = MotchillAppContainer.repository,
                movieId = movieId,
                episodeId = episodeId,
                movieTitle = movieTitle,
                episodeLabel = episodeLabel,
            )
        },
    )
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val view = LocalView.current
    val activity = remember(context) { context.findActivity() }
    val engine = remember(movieId, episodeId) {
        PlayerPlaybackEngine(
            context = context,
            movieId = movieId,
            episodeId = episodeId,
            positionStore = MotchillAppContainer.playbackPositionStore,
        )
    }
    val runtimeState by engine.state.collectAsStateWithLifecycle()

    PlayerSystemUiEffect(
        activity = activity,
        view = view,
    )

    val coroutineScope = rememberCoroutineScope()
    var controlsVisible by remember { mutableStateOf(true) }
    var interactionNonce by remember { mutableStateOf(0L) }
    var controlFocusEpoch by remember { mutableStateOf(0L) }

    val exitPlayer: () -> Unit = {
        coroutineScope.launch {
            engine.flushPosition()
            onBack()
        }
    }

    BackHandler {
        exitPlayer()
    }

    DisposableEffect(activity) {
        val previousOrientation = activity?.requestedOrientation
        activity?.requestedOrientation = playerRequestedOrientation()
        onDispose {
            if (activity != null && previousOrientation != null) {
                activity.requestedOrientation = previousOrientation
            }
        }
    }

    DisposableEffect(engine) {
        onDispose {
            engine.stopForExit()
            coroutineScope.launch {
                engine.release()
            }
        }
    }

    LaunchedEffect(
        uiState.selectedSource?.sourceId,
        uiState.selectedAudioTrack?.file,
        uiState.selectedSubtitleTrack?.file,
    ) {
        val selectedSource = uiState.selectedSource ?: return@LaunchedEffect
        engine.load(
            source = selectedSource,
            audioTrack = uiState.selectedAudioTrack,
            subtitleTrack = uiState.selectedSubtitleTrack,
            playWhenReady = true,
        )
        controlsVisible = true
        controlFocusEpoch += 1
        interactionNonce += 1
    }

    LaunchedEffect(runtimeState.isPlaying, interactionNonce) {
        if (!runtimeState.isPlaying) return@LaunchedEffect
        val currentNonce = interactionNonce
        kotlinx.coroutines.delay(3000)
        if (interactionNonce == currentNonce) {
            controlsVisible = false
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFF0F0F0F),
                        Color(0xFF070707),
                        Color(0xFF050505),
                    ),
                ),
            ),
    ) {
        when {
            uiState.isLoading && uiState.sources.isEmpty() -> LoadingPlayerState(
                movieTitle = uiState.movieTitle,
                episodeLabel = uiState.episodeLabel,
            )

            uiState.errorMessage != null && uiState.sources.isEmpty() -> ErrorPlayerState(
                message = uiState.errorMessage,
                onRetry = viewModel::load,
                onBack = onBack,
            )

            uiState.selectedSource != null -> PlayerContent(
                uiState = uiState,
                runtimeState = runtimeState,
                engine = engine,
                controlsVisible = controlsVisible,
                controlFocusEpoch = controlFocusEpoch,
                onExit = exitPlayer,
                onSurfaceTapped = {
                    interactionNonce += 1
                    controlsVisible = !controlsVisible
                    if (controlsVisible) {
                        controlFocusEpoch += 1
                    }
                },
                onShowControls = {
                    interactionNonce += 1
                    controlsVisible = true
                    controlFocusEpoch += 1
                },
                onTouchControls = {
                    interactionNonce += 1
                },
                onBack = onBack,
                onSelectSource = viewModel::selectSource,
                onSelectAudioTrack = { track ->
                    viewModel.selectAudioTrack(track)
                    coroutineScope.launch {
                        engine.updateTrackSelection(
                            audioTrack = track,
                            subtitleTrack = uiState.selectedSubtitleTrack,
                        )
                    }
                },
                onSelectSubtitleTrack = { track ->
                    viewModel.selectSubtitleTrack(track)
                    coroutineScope.launch {
                        engine.updateTrackSelection(
                            audioTrack = uiState.selectedAudioTrack,
                            subtitleTrack = track,
                        )
                    }
                },
                onSeekBy = { deltaMs ->
                    val target = (runtimeState.positionMs + deltaMs).coerceAtLeast(0L)
                    val maxPosition = runtimeState.durationMs.takeIf { it > 0L } ?: target
                    engine.seekTo(target.coerceAtMost(maxPosition))
                },
                onTogglePlayback = {
                    if (runtimeState.isPlaying) {
                        engine.pause()
                    } else {
                        engine.play()
                    }
                },
                onSeekTo = { positionMs -> engine.seekTo(positionMs) },
            )
        }
    }
}

@Composable
private fun PlayerSystemUiEffect(
    activity: Activity?,
    view: android.view.View,
) {
    DisposableEffect(activity, view) {
        val window = activity?.window
        if (window == null) {
            onDispose { }
        } else {
            val insetsController = WindowCompat.getInsetsController(window, view)
            val previousKeepScreenOn = window.attributes.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0

            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            WindowCompat.setDecorFitsSystemWindows(window, false)
            insetsController.systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            insetsController.hide(WindowInsetsCompat.Type.systemBars())

            onDispose {
                insetsController.show(WindowInsetsCompat.Type.systemBars())
                WindowCompat.setDecorFitsSystemWindows(window, true)
                if (previousKeepScreenOn) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
            }
        }
    }
}

@OptIn(UnstableApi::class)
@Composable
private fun PlayerContent(
    uiState: PlayerUiState,
    runtimeState: PlayerRuntimeState,
    engine: PlayerPlaybackEngine,
    controlsVisible: Boolean,
    controlFocusEpoch: Long,
    onExit: () -> Unit,
    onSurfaceTapped: () -> Unit,
    onShowControls: () -> Unit,
    onTouchControls: () -> Unit,
    onBack: () -> Unit,
    onSelectSource: (Int) -> Unit,
    onSelectAudioTrack: (PlayTrack?) -> Unit,
    onSelectSubtitleTrack: (PlayTrack?) -> Unit,
    onSeekBy: (Long) -> Unit,
    onTogglePlayback: () -> Unit,
    onSeekTo: (Long) -> Unit,
) {
    val hostFocusRequester = remember { FocusRequester() }
    var focusedControl by remember {
        mutableStateOf<PlayerFocusedControl>(playerFocusAfterShowingControls())
    }
    val selectedSource = uiState.selectedSource ?: return
    val sourceCount = uiState.playableSources.size
    val backgroundShape = RoundedCornerShape(28.dp)
    var playerSurfaceWidthPx by remember { mutableIntStateOf(0) }

    LaunchedEffect(controlsVisible, controlFocusEpoch, sourceCount, uiState.selectedSourceIndex) {
        focusedControl = if (controlsVisible) {
            playerFocusAfterShowingControls()
        } else {
            playerDefaultFocusedControl()
        }
        hostFocusRequester.requestFocus()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(12.dp)
            .clip(backgroundShape),
    ) {
        PlayerSurface(
            modifier = Modifier.fillMaxSize(),
            engine = engine,
        )

        Box(
            modifier = Modifier
                .fillMaxSize()
                .onSizeChanged { playerSurfaceWidthPx = it.width }
                .focusRequester(hostFocusRequester)
                .focusable()
                .onPreviewKeyEvent { event ->
                    if (event.nativeKeyEvent.action != android.view.KeyEvent.ACTION_DOWN) {
                        return@onPreviewKeyEvent false
                    }

                    val remoteKey = event.toPlayerRemoteKey()
                    if (!controlsVisible) {
                        val decision = playerHandleHiddenKey(remoteKey) ?: return@onPreviewKeyEvent false

                        when (val effect = decision.effect) {
                            PlayerRemoteEffect.NoOp -> {
                                onShowControls()
                                focusedControl = decision.nextFocus
                            }
                            is PlayerRemoteEffect.SeekBy -> {
                                onTouchControls()
                                onSeekBy(effect.deltaMs)
                            }
                            PlayerRemoteEffect.Back,
                            PlayerRemoteEffect.TogglePlayback,
                            is PlayerRemoteEffect.SelectSource,
                            -> Unit
                        }

                        true
                    }

                    val decision = playerHandleVisibleKey(
                        focusedControl = focusedControl,
                        key = remoteKey,
                        sourceCount = sourceCount,
                        selectedSourceIndex = uiState.selectedSourceIndex,
                        durationMs = runtimeState.durationMs,
                    ) ?: return@onPreviewKeyEvent false

                    onTouchControls()
                    focusedControl = decision.nextFocus
                    when (val effect = decision.effect) {
                        PlayerRemoteEffect.NoOp -> Unit
                        PlayerRemoteEffect.Back -> {
                            onExit()
                        }

                        is PlayerRemoteEffect.SeekBy -> onSeekBy(effect.deltaMs)
                        is PlayerRemoteEffect.SelectSource -> onSelectSource(effect.index)
                        PlayerRemoteEffect.TogglePlayback -> onTogglePlayback()
                    }
                    true
                }
                .pointerInput(playerSurfaceWidthPx) {
                    detectTapGestures(
                        onTap = { onSurfaceTapped() },
                        onDoubleTap = { offset ->
                            val deltaMs = playerDoubleTapSeekDelta(
                                tapX = offset.x,
                                surfaceWidthPx = playerSurfaceWidthPx,
                            ) ?: return@detectTapGestures
                            onTouchControls()
                            onSeekBy(deltaMs)
                        },
                    )
                },
        )

        PlayerChrome(
            uiState = uiState,
            runtimeState = runtimeState,
            selectedSource = selectedSource,
            controlsVisible = controlsVisible,
            focusedControl = focusedControl,
            onFocusControl = { control ->
                focusedControl = control
                onTouchControls()
                hostFocusRequester.requestFocus()
            },
            onBack = {
                onExit()
            },
            onSelectSource = { index ->
                focusedControl = PlayerFocusedControl.Source(index)
                onTouchControls()
                onSelectSource(index)
                hostFocusRequester.requestFocus()
            },
            onSelectAudioTrack = {
                onTouchControls()
                onSelectAudioTrack(it)
            },
            onSelectSubtitleTrack = {
                onTouchControls()
                onSelectSubtitleTrack(it)
            },
            onSeekBy = {
                onTouchControls()
                onSeekBy(it)
                hostFocusRequester.requestFocus()
            },
            onTogglePlayback = {
                focusedControl = PlayerFocusedControl.Transport(index = 1)
                onTouchControls()
                onTogglePlayback()
                hostFocusRequester.requestFocus()
            },
            onSeekTo = {
                focusedControl = PlayerFocusedControl.Progress
                onTouchControls()
                onSeekTo(it)
                hostFocusRequester.requestFocus()
            },
        )

        if (runtimeState.errorMessage != null) {
            Surface(
                color = Color(0xAA000000),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(16.dp),
            ) {
                Text(
                    text = runtimeState.errorMessage,
                    color = Color.White,
                    fontSize = 12.sp,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                )
            }
        }
    }
}

@OptIn(UnstableApi::class)
@Composable
private fun PlayerSurface(
    modifier: Modifier = Modifier,
    engine: PlayerPlaybackEngine,
) {
    AndroidView(
        modifier = modifier,
        factory = {
            PlayerView(it).apply {
                useController = false
                resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
                setBackgroundColor(android.graphics.Color.parseColor("#050505"))
                player = engine.player
                descendantFocusability = android.view.ViewGroup.FOCUS_BLOCK_DESCENDANTS
                isFocusable = false
                isFocusableInTouchMode = false
            }
        },
        update = { playerView ->
            if (playerView.player != engine.player) {
                playerView.player = engine.player
            }
            playerView.descendantFocusability = android.view.ViewGroup.FOCUS_BLOCK_DESCENDANTS
            playerView.isFocusable = false
            playerView.isFocusableInTouchMode = false
        },
    )
}

@Composable
private fun PlayerChrome(
    uiState: PlayerUiState,
    runtimeState: PlayerRuntimeState,
    selectedSource: PlaySource,
    controlsVisible: Boolean,
    focusedControl: PlayerFocusedControl,
    onFocusControl: (PlayerFocusedControl) -> Unit,
    onBack: () -> Unit,
    onSelectSource: (Int) -> Unit,
    onSelectAudioTrack: (PlayTrack?) -> Unit,
    onSelectSubtitleTrack: (PlayTrack?) -> Unit,
    onSeekBy: (Long) -> Unit,
    onTogglePlayback: () -> Unit,
    onSeekTo: (Long) -> Unit,
) {
    AnimatedVisibility(
        visible = controlsVisible,
        enter = fadeIn(),
        exit = fadeOut(),
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            PlayerBackButton(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(12.dp),
                isFocused = focusedControl == PlayerFocusedControl.Back,
                onClick = onBack,
                onFocused = { onFocusControl(PlayerFocusedControl.Back) },
            )

            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                if (uiState.canShowSourceRail) {
                    PlayerSourceRail(
                        sources = uiState.playableSources,
                        selectedIndex = uiState.selectedSourceIndex,
                        focusedControl = focusedControl,
                        onFocusControl = onFocusControl,
                        onSelectSource = onSelectSource,
                    )
                }

                PlayerProgressCard(
                    positionMs = runtimeState.positionMs,
                    durationMs = runtimeState.durationMs,
                    isFocused = focusedControl == PlayerFocusedControl.Progress,
                    onFocused = { onFocusControl(PlayerFocusedControl.Progress) },
                    onSeekTo = onSeekTo,
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (selectedSource.hasAudioTracks) {
                            PlayerTrackMenuButton(
                                icon = Icons.Outlined.Audiotrack,
                                active = uiState.selectedAudioTrack != null,
                                tooltip = "Audio",
                                defaultLabel = "Auto",
                                options = selectedSource.audioTracks,
                                selectedTrack = uiState.selectedAudioTrack,
                                onSelect = onSelectAudioTrack,
                            )
                        }
                        if (selectedSource.hasSubtitleTracks) {
                            PlayerTrackMenuButton(
                                icon = Icons.Outlined.Subtitles,
                                active = uiState.selectedSubtitleTrack != null,
                                tooltip = "Subtitle",
                                defaultLabel = "Off",
                                options = selectedSource.subtitleTracks,
                                selectedTrack = uiState.selectedSubtitleTrack,
                                onSelect = onSelectSubtitleTrack,
                            )
                        }
                    }

                    Spacer(modifier = Modifier.weight(1f))

                    Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        PlayerTransportButton(
                            icon = Icons.Outlined.Replay10,
                            isFocused = focusedControl == PlayerFocusedControl.Transport(index = 0),
                            onClick = { onSeekBy(-10_000L) },
                            onFocused = { onFocusControl(PlayerFocusedControl.Transport(index = 0)) },
                        )
                        PlayerTransportButton(
                            icon = if (runtimeState.isPlaying) {
                                Icons.Outlined.Pause
                            } else {
                                Icons.Outlined.PlayArrow
                            },
                            isFocused = focusedControl == PlayerFocusedControl.Transport(index = 1),
                            onClick = onTogglePlayback,
                            onFocused = { onFocusControl(PlayerFocusedControl.Transport(index = 1)) },
                            primary = true,
                            size = 56.dp,
                        )
                        PlayerTransportButton(
                            icon = Icons.Outlined.Forward10,
                            isFocused = focusedControl == PlayerFocusedControl.Transport(index = 2),
                            onClick = { onSeekBy(10_000L) },
                            onFocused = { onFocusControl(PlayerFocusedControl.Transport(index = 2)) },
                        )
                    }
                }
            }

            PlayerHeader(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 18.dp),
                movieTitle = uiState.movieTitle,
                episodeLabel = uiState.episodeLabel,
                sourceName = selectedSource.serverName,
            )
        }
    }
}

@Composable
private fun PlayerHeader(
    modifier: Modifier = Modifier,
    movieTitle: String,
    episodeLabel: String,
    sourceName: String,
) {
    Column(
        modifier = modifier.widthIn(max = 420.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = movieTitle.ifBlank { "Motchill" },
            color = Color.White,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        val subtitle = listOfNotNull(
            episodeLabel.takeIf { it.isNotBlank() },
            sourceName.takeIf { it.isNotBlank() },
        ).joinToString(" • ")
        if (subtitle.isNotBlank()) {
            Text(
                text = subtitle,
                color = Color.White.copy(alpha = 0.72f),
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun PlayerBackButton(
    modifier: Modifier = Modifier,
    isFocused: Boolean,
    onClick: () -> Unit,
    onFocused: () -> Unit,
) {
    PlayerFocusSurface(
        modifier = modifier.size(46.dp),
        isFocused = isFocused,
        shape = RoundedCornerShape(16.dp),
        onClick = onClick,
        onFocused = onFocused,
        focusedBorderColor = Color(0xFFE8A7A7),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.48f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Outlined.ChevronLeft,
                contentDescription = "Back",
                tint = Color.White,
            )
        }
    }
}

@Composable
private fun PlayerSourceRail(
    sources: List<PlaySource>,
    selectedIndex: Int,
    focusedControl: PlayerFocusedControl,
    onFocusControl: (PlayerFocusedControl) -> Unit,
    onSelectSource: (Int) -> Unit,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        sources.forEachIndexed { index, source ->
            PlayerSourceChip(
                source = source,
                selected = index == selectedIndex,
                isFocused = focusedControl == PlayerFocusedControl.Source(index),
                onFocused = { onFocusControl(PlayerFocusedControl.Source(index)) },
                onClick = { onSelectSource(index) },
            )
        }
    }
}

@Composable
private fun PlayerSourceChip(
    source: PlaySource,
    selected: Boolean,
    isFocused: Boolean,
    onFocused: () -> Unit,
    onClick: () -> Unit,
) {
    PlayerFocusSurface(
        modifier = Modifier.height(44.dp),
        isFocused = isFocused,
        shape = RoundedCornerShape(16.dp),
        onClick = onClick,
        onFocused = onFocused,
        focusedBorderColor = Color(0xFFE8A7A7),
    ) {
        Row(
            modifier = Modifier
                .background(
                    color = if (selected) {
                        Color(0xFF19437A).copy(alpha = 0.82f)
                    } else {
                        Color.Black.copy(alpha = 0.44f)
                    },
                )
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = source.serverName.ifBlank { "Source" },
                color = Color.White,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun PlayerProgressCard(
    positionMs: Long,
    durationMs: Long,
    isFocused: Boolean,
    onFocused: () -> Unit,
    onSeekTo: (Long) -> Unit,
) {
    val total = durationMs.coerceAtLeast(0L)
    val progress = if (total > 0L) {
        (positionMs.toDouble() / total.toDouble()).coerceIn(0.0, 1.0)
    } else {
        0.0
    }

    PlayerFocusSurface(
        modifier = Modifier.fillMaxWidth(),
        isFocused = isFocused,
        shape = RoundedCornerShape(18.dp),
        onClick = onFocused,
        onFocused = onFocused,
        focusedBorderColor = Color(0xFFFFD15C),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.Black.copy(alpha = 0.52f))
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = formatTime(positionMs),
                color = Color.White.copy(alpha = 0.72f),
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(modifier = Modifier.width(10.dp))
            Slider(
                modifier = Modifier.weight(1f),
                value = progress.toFloat(),
                onValueChange = { value ->
                    if (total <= 0L) return@Slider
                    onSeekTo((total * value).toLong())
                },
            )
            Spacer(modifier = Modifier.width(10.dp))
            Text(
                text = formatTime(durationMs),
                color = Color.White.copy(alpha = 0.72f),
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun PlayerTrackMenuButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    active: Boolean,
    tooltip: String,
    defaultLabel: String,
    options: List<PlayTrack>,
    selectedTrack: PlayTrack?,
    onSelect: (PlayTrack?) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        PlayerFocusSurface(
            modifier = Modifier.size(42.dp),
            isFocused = false,
            shape = RoundedCornerShape(14.dp),
            onClick = { expanded = true },
            onFocused = {},
            focusedBorderColor = Color(0xFFE8A7A7),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        color = if (active) {
                            Color.White.copy(alpha = 0.10f)
                        } else {
                            Color.Black.copy(alpha = 0.42f)
                        },
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = tooltip,
                    tint = if (active) Color(0xFFFFD15C) else Color.White,
                )
            }
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            DropdownMenuItem(
                text = { Text(defaultLabel) },
                onClick = {
                    onSelect(null)
                    expanded = false
                },
            )
            options.forEach { track ->
                DropdownMenuItem(
                    text = { Text(track.displayLabel) },
                    trailingIcon = if (track == selectedTrack) {
                        {
                            Icon(
                                imageVector = Icons.Outlined.Check,
                                contentDescription = null,
                            )
                        }
                    } else {
                        null
                    },
                    onClick = {
                        onSelect(track)
                        expanded = false
                    },
                )
            }
        }
    }
}

@Composable
private fun PlayerTransportButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    isFocused: Boolean,
    onClick: () -> Unit,
    onFocused: () -> Unit,
    primary: Boolean = false,
    size: Dp = 42.dp,
) {
    PlayerFocusSurface(
        modifier = Modifier.size(size),
        isFocused = isFocused,
        shape = RoundedCornerShape(999.dp),
        onClick = onClick,
        onFocused = onFocused,
        focusedBorderColor = Color(0xFFFFD15C),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    color = if (primary) {
                        Color(0xFFE8A7A7)
                    } else {
                        Color.Black.copy(alpha = 0.42f)
                    },
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (primary) Color.Black else Color.White,
                modifier = Modifier.size(if (primary) 28.dp else 22.dp),
            )
        }
    }
}

@Composable
private fun PlayerFocusSurface(
    modifier: Modifier = Modifier,
    isFocused: Boolean,
    shape: Shape,
    onClick: () -> Unit,
    onFocused: () -> Unit,
    focusedBorderColor: Color,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = modifier
            .clip(shape)
            .background(
                color = if (isFocused) {
                    Color.White.copy(alpha = 0.06f)
                } else {
                    Color.Transparent
                },
                shape = shape,
            )
            .border(
                width = if (isFocused) 2.dp else 1.dp,
                color = if (isFocused) {
                    focusedBorderColor
                } else {
                    Color.White.copy(alpha = 0.10f)
                },
                shape = shape,
            )
            .clickable(
                indication = null,
                interactionSource = remember { MutableInteractionSource() },
            ) {
                onFocused()
                onClick()
            },
    ) {
        content()
    }
}

@Composable
private fun LoadingPlayerState(
    movieTitle: String,
    episodeLabel: String,
) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        CircularProgressIndicator(color = Color(0xFFE8A7A7))
        Spacer(modifier = Modifier.height(14.dp))
        Text(
            text = movieTitle.ifBlank { "Loading player" },
            color = Color.White,
            fontWeight = FontWeight.Bold,
        )
        if (episodeLabel.isNotBlank()) {
            Text(
                text = episodeLabel,
                color = Color.White.copy(alpha = 0.62f),
                fontSize = 12.sp,
            )
        }
    }
}

@Composable
private fun ErrorPlayerState(
    message: String?,
    onRetry: () -> Unit,
    onBack: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = message ?: "Unable to load player",
            color = Color.White,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 24.dp),
        )
        Spacer(modifier = Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            PlayerTransportButton(
                icon = Icons.Outlined.ChevronLeft,
                isFocused = false,
                onClick = onBack,
                onFocused = {},
            )
            TextButton(onClick = onRetry) {
                Text("Retry")
            }
        }
    }
}

private fun formatTime(positionMs: Long): String {
    val totalSeconds = max(0L, positionMs) / 1000L
    val hours = totalSeconds / 3600L
    val minutes = (totalSeconds % 3600L) / 60L
    val seconds = totalSeconds % 60L
    return if (hours > 0L) {
        String.format(Locale.US, "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        String.format(Locale.US, "%02d:%02d", minutes, seconds)
    }
}

private fun KeyEvent.toPlayerRemoteKey(): PlayerRemoteKey {
    return when (nativeKeyEvent.keyCode) {
        android.view.KeyEvent.KEYCODE_DPAD_LEFT -> PlayerRemoteKey.Left
        android.view.KeyEvent.KEYCODE_DPAD_RIGHT -> PlayerRemoteKey.Right
        android.view.KeyEvent.KEYCODE_DPAD_UP -> PlayerRemoteKey.Up
        android.view.KeyEvent.KEYCODE_DPAD_DOWN -> PlayerRemoteKey.Down
        android.view.KeyEvent.KEYCODE_DPAD_CENTER,
        android.view.KeyEvent.KEYCODE_ENTER,
        android.view.KeyEvent.KEYCODE_NUMPAD_ENTER,
        android.view.KeyEvent.KEYCODE_SPACE,
        -> PlayerRemoteKey.Activate

        else -> PlayerRemoteKey.Other
    }
}

private tailrec fun Context.findActivity(): Activity? {
    return when (this) {
        is Activity -> this
        is ContextWrapper -> baseContext.findActivity()
        else -> null
    }
}
