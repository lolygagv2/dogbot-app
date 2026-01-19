import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'presentation/screens/connect/connect_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/drive/drive_screen.dart';
import 'presentation/screens/missions/missions_screen.dart';
import 'presentation/screens/missions/mission_detail_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/theme/app_theme.dart';

final _router = GoRouter(
  initialLocation: '/connect',
  routes: [
    GoRoute(
      path: '/connect',
      builder: (context, state) => const ConnectScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/drive',
      builder: (context, state) => const DriveScreen(),
    ),
    GoRoute(
      path: '/missions',
      builder: (context, state) => const MissionsScreen(),
    ),
    GoRoute(
      path: '/missions/:id',
      builder: (context, state) => MissionDetailScreen(
        missionId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

class WimzApp extends ConsumerWidget {
  const WimzApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'WIM-Z',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
