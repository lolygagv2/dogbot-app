import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/notification_service.dart';

void main() {
  // Catch all Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('FLUTTER ERROR: ${details.exception}');
    print('STACK: ${details.stack}');
  };

  // Catch async errors
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      print('App: WIM-Z app starting...');

      await NotificationService.instance.init();

      runApp(
        const ProviderScope(
          child: WimzApp(),
        ),
      );
    },
    (error, stackTrace) {
      print('ZONE ERROR: $error');
      print('STACK: $stackTrace');
    },
  );
}
