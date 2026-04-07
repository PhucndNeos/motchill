import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/motchill_repository.dart';
import 'models.dart';
import 'screens/home_screen.dart';
import 'screens/player_screen.dart';

class _DebugAutoplayLaunch {
  const _DebugAutoplayLaunch({
    required this.detail,
    required this.index,
  });

  final MovieDetail detail;
  final int index;
}

class MotchillApp extends StatelessWidget {
  const MotchillApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Motchill',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF32D6B7),
          brightness: Brightness.dark,
          surface: const Color(0xFF111827),
        ),
        scaffoldBackgroundColor: const Color(0xFF08111F),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(fontSize: 14, height: 1.4),
        ),
      ),
      home: const AppBootstrap(),
    );
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<MotchillRepository> _repositoryFuture;
  Future<_DebugAutoplayLaunch>? _debugAutoplayFuture;

  static bool _shouldAutoplay() {
    final value = Platform.environment['MOTCHILL_TEST_AUTOPLAY'];
    return value != null && value.trim().isNotEmpty && value != '0';
  }

  static String _autoplaySlug() {
    final value = Platform.environment['MOTCHILL_TEST_SLUG'];
    if (value != null && value.trim().isNotEmpty) return value.trim();
    return 'sirens-kiss';
  }

  Future<_DebugAutoplayLaunch> _buildAutoplayLaunch(MotchillRepository repository) async {
    final detail = await repository.loadDetail(_autoplaySlug());
    return _DebugAutoplayLaunch(detail: detail, index: 0);
  }

  @override
  void initState() {
    super.initState();
    _repositoryFuture = MotchillRepository.create();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    if (_shouldAutoplay()) {
      _debugAutoplayFuture = _repositoryFuture.then(_buildAutoplayLaunch);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MotchillRepository>(
      future: _repositoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            body: Center(child: Text('Failed to initialize API: ${snapshot.error}')),
          );
        }

        if (_debugAutoplayFuture != null) {
          return FutureBuilder<_DebugAutoplayLaunch>(
            future: _debugAutoplayFuture,
            builder: (context, autoplaySnapshot) {
              if (autoplaySnapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (autoplaySnapshot.hasError || !autoplaySnapshot.hasData) {
                return Scaffold(
                  body: Center(
                    child: Text('Failed to auto launch player: ${autoplaySnapshot.error}'),
                  ),
                );
              }

              final launch = autoplaySnapshot.data!;
              return PlayerScreen(
                repository: snapshot.data!,
                detail: launch.detail,
                initialIndex: launch.index,
              );
            },
          );
        }

        return HomeScreen(repository: snapshot.data!);
      },
    );
  }
}
