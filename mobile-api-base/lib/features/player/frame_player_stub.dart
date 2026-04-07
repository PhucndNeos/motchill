import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../data/models/motchill_play_models.dart';

Widget buildFramePlayer(PlaySource source) {
  return _FramePlayerSurface(source: source);
}

class _FramePlayerSurface extends StatefulWidget {
  const _FramePlayerSurface({required this.source});

  final PlaySource source;

  @override
  State<_FramePlayerSurface> createState() => _FramePlayerSurfaceState();
}

class _FramePlayerSurfaceState extends State<_FramePlayerSurface> {
  late final WebViewController _controller = _createController(widget.source);

  @override
  void didUpdateWidget(covariant _FramePlayerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.link != widget.source.link) {
      _loadSource(_controller, widget.source);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}

WebViewController _createController(PlaySource source) {
  late final PlatformWebViewControllerCreationParams creationParams;
  if (WebViewPlatform.instance is WebKitWebViewPlatform) {
    creationParams = WebKitWebViewControllerCreationParams(
      allowsInlineMediaPlayback: true,
      mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
    );
  } else {
    creationParams = const PlatformWebViewControllerCreationParams();
  }

  final controller =
      WebViewController.fromPlatformCreationParams(creationParams)
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setUserAgent(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 '
          'Mobile/15E148 Safari/604.1',
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              developer.log(
                'webview navigation request',
                name: 'Motchill.player',
                error: {'url': request.url, 'isMainFrame': request.isMainFrame},
              );
              return NavigationDecision.navigate;
            },
            onPageStarted: (url) {
              developer.log(
                'webview page started',
                name: 'Motchill.player',
                error: {'url': url},
              );
            },
            onPageFinished: (url) {
              developer.log(
                'webview page finished',
                name: 'Motchill.player',
                error: {'url': url},
              );
            },
            onHttpError: (error) {
              developer.log(
                'webview http error',
                name: 'Motchill.player',
                error: {
                  'url': error.request?.uri.toString(),
                  'statusCode': error.response?.statusCode,
                },
              );
            },
            onWebResourceError: (error) {
              developer.log(
                'webview resource error',
                name: 'Motchill.player',
                error: {
                  'url': error.url,
                  'description': error.description,
                  'errorCode': error.errorCode,
                  'isForMainFrame': error.isForMainFrame,
                },
              );
            },
          ),
        );

  if (controller.platform is AndroidWebViewController) {
    AndroidWebViewController.enableDebugging(true);
    (controller.platform as AndroidWebViewController)
        .setMediaPlaybackRequiresUserGesture(false);
  }

  _loadSource(controller, source);
  return controller;
}

void _loadSource(WebViewController controller, PlaySource source) {
  developer.log(
    'webview loading source',
    name: 'Motchill.player',
    error: {
      'url': source.link,
      'serverName': source.serverName,
      'quality': source.quality,
      'isFrame': source.isFrame,
    },
  );

  controller.loadRequest(
    Uri.parse(source.link),
    headers: const {
      'Referer': 'https://motchilltv.taxi/',
      'Origin': 'https://motchilltv.taxi/',
    },
  );
}
