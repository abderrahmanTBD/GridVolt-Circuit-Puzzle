import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'presentation/effects/sound_effects.dart';

/// Sentry project key, supplied at build time:
///   flutter build appbundle --dart-define=SENTRY_DSN=https://...
/// When absent (local runs, tests, forks), crash reporting is off entirely.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  if (_sentryDsn.isEmpty) {
    await _run();
    return;
  }
  await SentryFlutter.init((options) {
    options
      ..dsn = _sentryDsn
      ..environment = kReleaseMode ? 'production' : 'development'
      // Privacy: crashes only. No IP/user data, screenshots, view
      // hierarchy or performance tracing. Matches docs/privacy-policy.md.
      ..sendDefaultPii = false
      ..attachScreenshot = false
      ..attachViewHierarchy = false
      ..tracesSampleRate = null;
  }, appRunner: _run);
}

Future<void> _run() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status and navigation bars; SafeArea keeps the UI clear
  // of them. Without this, Android 15 shows opaque system bars.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorageDirectory.web
        : HydratedStorageDirectory(
            (await getApplicationDocumentsDirectory()).path,
          ),
  );
  // Sounds load in the background so the first frame isn't delayed.
  final soundEffects = DeferredSoundEffects(AudioPlayersSoundEffects.create());

  runApp(GridVoltApp(soundEffects: soundEffects));
}
