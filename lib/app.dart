import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'domain/providers/notifications_provider.dart';
import 'presentation/screens/connect/connect_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/drive/drive_screen.dart';
import 'presentation/screens/missions/missions_screen.dart';
import 'presentation/screens/missions/mission_detail_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/notifications/notifications_screen.dart';
import 'presentation/screens/dog_profile/dog_profile_screen.dart';
import 'presentation/theme/app_theme.dart';

/// Navigation tab enum
enum NavTab {
  home,
  dogs,
  missions,
  gallery,
  activity,
}

/// Key for the navigator in the shell
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/connect',
  routes: [
    // Connect screen (no bottom nav)
    GoRoute(
      path: '/connect',
      builder: (context, state) => const ConnectScreen(),
    ),

    // Main app shell with bottom navigation
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        // Home tab
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),

        // Dogs tab
        GoRoute(
          path: '/dogs',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DogsListScreen(),
          ),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => DogProfileScreen(
                dogId: state.pathParameters['id'],
              ),
            ),
          ],
        ),

        // Missions tab
        GoRoute(
          path: '/missions',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MissionsScreen(),
          ),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => MissionDetailScreen(
                missionId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),

        // Gallery tab (placeholder for now)
        GoRoute(
          path: '/gallery',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: _VideoGalleryPlaceholder(),
          ),
        ),

        // Activity/Notifications tab
        GoRoute(
          path: '/activity',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: NotificationsScreen(),
          ),
        ),
      ],
    ),

    // Drive screen (full screen, no bottom nav)
    GoRoute(
      path: '/drive',
      builder: (context, state) => const DriveScreen(),
    ),

    // Settings screen (full screen, no bottom nav)
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),

    // Dog profile detail (can also be accessed directly)
    GoRoute(
      path: '/dog/:id',
      builder: (context, state) => DogProfileScreen(
        dogId: state.pathParameters['id'],
      ),
    ),
  ],
);

/// Main shell with bottom navigation
class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider);
    final location = GoRouterState.of(context).uri.path;

    // Determine current tab index from location
    final currentIndex = _getTabIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(
            top: BorderSide(
              color: AppTheme.glassBorder,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavBarItem(
                  icon: Icons.home,
                  label: 'Home',
                  isSelected: currentIndex == 0,
                  onTap: () => context.go('/home'),
                ),
                _NavBarItem(
                  icon: Icons.pets,
                  label: 'Dogs',
                  isSelected: currentIndex == 1,
                  onTap: () => context.go('/dogs'),
                ),
                _NavBarItem(
                  icon: Icons.flag,
                  label: 'Missions',
                  isSelected: currentIndex == 2,
                  onTap: () => context.go('/missions'),
                ),
                _NavBarItem(
                  icon: Icons.video_library,
                  label: 'Gallery',
                  isSelected: currentIndex == 3,
                  onTap: () => context.go('/gallery'),
                ),
                _NavBarItem(
                  icon: Icons.notifications,
                  label: 'Activity',
                  isSelected: currentIndex == 4,
                  badgeCount: unreadCount,
                  onTap: () => context.go('/activity'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _getTabIndex(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/dogs')) return 1;
    if (location.startsWith('/missions')) return 2;
    if (location.startsWith('/gallery')) return 3;
    if (location.startsWith('/activity')) return 4;
    return 0;
  }
}

/// Bottom navigation bar item
class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.primary : AppTheme.textTertiary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 24),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder for video gallery screen
class _VideoGalleryPlaceholder extends StatelessWidget {
  const _VideoGalleryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Gallery')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Video Gallery',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
