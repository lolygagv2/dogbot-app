import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/utils/remote_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize remote logging (sends debug logs to relay server)
  RemoteLogger.init();
  rprint('App: WIM-Z app starting...');

  runApp(
    const ProviderScope(
      child: WimzApp(),
    ),
  );
}
