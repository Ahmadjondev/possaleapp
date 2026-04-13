import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/di/injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('[${record.level.name}] ${record.loggerName}: ${record.message}');
  });

  // Dependency injection
  await setupDependencies();

  // Window configuration
  await windowManager.ensureInitialized();

  final windowOptions = WindowOptions(
    minimumSize: const Size(1024, 600),
    center: true,
    title: 'Digitex POS Terminal',
    // Solid background avoids DWM alpha-compositing for the entire window,
    // which is a measurable GPU/CPU saving on low-end hardware (HD 3000, etc.).
    backgroundColor: Colors.white,
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (Platform.isWindows || Platform.isMacOS) {
      await windowManager.maximize();
    }
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const PosTerminalApp());
}
