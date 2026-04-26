import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/network/websocket_client.dart';
import 'domain/providers/connection_provider.dart';
import 'domain/providers/notifications_provider.dart';
import 'domain/providers/settings_provider.dart';
import 'domain/providers/webrtc_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/drive/drive_screen.dart';
import 'presentation/screens/missions/missions_screen.dart';
import 'presentation/screens/missions/mission_detail_screen.dart';
import 'presentation/screens/programs/program_detail_screen.dart';
import 'presentation/screens/coach/coach_screen.dart';
import 'presentation/screens/history/history_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/settings/device_pairing_screen.dart';
import 'presentation/screens/settings/notification_preferences_screen.dart';
import 'presentation/screens/notifications/notifications_screen.dart';
import 'presentation/screens/dog_profile/dog_profile_screen.dart';
import 'presentation/screens/dog_profile/add_dog_screen.dart';
import 'presentation/screens/gallery/photo_gallery_screen.dart';
import 'presentation/screens/voice/voice_setup_screen.dart';
import 'presentation/screens/scheduler/scheduler_screen.dart';
import 'presentation/screens/scheduler/schedule_edit_screen.dart';
import 'presentation/theme/app_theme.dart';

/// Navigation tab enum
enum NavTab {
  home,
  dogs,
  missions,
  gallery,
  activity,
  settings,
}

/// Key for the navigator in the shell
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    // Login screen (no bottom nav)
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    // Demo mode entry point
    GoRoute(
      path: '/demo',
      builder: (context, state) => const _DemoModeEntry(),
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
            // Add dog route - must be before :id to avoid conflict
            GoRoute(
              path: 'add',
              builder: (context, state) {
                final arucoId = int.tryParse(
                  state.uri.queryParameters['arucoId'] ?? '',
                );
                return AddDogScreen(initialArucoId: arucoId);
              },
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) => DogProfileScreen(
                dogId: state.pathParameters['id'],
              ),
              routes: [
                // Voice setup for this dog
                GoRoute(
                  path: 'voice',
                  builder: (context, state) => VoiceSetupScreen(
                    dogId: state.pathParameters['id'],
                  ),
                ),
              ],
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

        // Programs (multi-mission sequences)
        GoRoute(
          path: '/programs',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MissionsScreen(), // Programs shown in missions screen
          ),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => ProgramDetailScreen(
                programId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),

        // Photo Gallery tab
        GoRoute(
          path: '/gallery',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: PhotoGalleryScreen(),
          ),
        ),

        // Activity/Notifications tab
        GoRoute(
          path: '/activity',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: NotificationsScreen(),
          ),
        ),

        // Settings tab (v1.3: moved to bottom nav)
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
          routes: [
            GoRoute(
              path: 'notifications',
              builder: (context, state) =>
                  const NotificationPreferencesScreen(),
            ),
          ],
        ),
      ],
    ),

    // Drive screen (full screen, no bottom nav)
    GoRoute(
      path: '/drive',
      builder: (context, state) => const DriveScreen(),
    ),

    // Coach mode screen (full screen, no bottom nav)
    GoRoute(
      path: '/coach',
      builder: (context, state) => const CoachScreen(),
    ),

    // Training history screen
    GoRoute(
      path: '/history',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final dogId = extra?['dogId'] as String?;
        return HistoryScreen(dogId: dogId);
      },
    ),

    // Scheduler screens
    GoRoute(
      path: '/scheduler',
      builder: (context, state) => const SchedulerScreen(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) => const ScheduleEditScreen(),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) => ScheduleEditScreen(
            scheduleId: state.pathParameters['id'],
          ),
        ),
      ],
    ),

    // Device pairing screen
    GoRoute(
      path: '/device-pairing',
      builder: (context, state) => const DevicePairingScreen(),
    ),

    // Voice commands setup (standalone route from settings or dog profile)
    GoRoute(
      path: '/voice-setup',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final dogId = extra?['dogId'] as String?;
        return VoiceSetupScreen(dogId: dogId);
      },
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
    final connState = ref.watch(connectionProvider);
    final location = GoRouterState.of(context).uri.path;

    // Show snackbar when rate-limited by relay
    ref.listen(rateLimitProvider, (previous, next) {
      next.whenData((message) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Too many commands, slow down'),
              backgroundColor: Colors.orange.shade800,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    });

    // Determine current tab index from location
    final currentIndex = _getTabIndex(location);

    // Show reconnecting banner when connection lost with saved host (not demo mode)
    final showReconnecting = !connState.isDemoMode &&
        connState.host != null &&
        (connState.status == ConnectionStatus.connecting ||
         connState.status == ConnectionStatus.error);

    return Scaffold(
      body: Stack(
        children: [
          child,
          if (showReconnecting)
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.orange.shade800,
                child: InkWell(
                  onTap: () => ref.read(connectionProvider.notifier).reconnect(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Reconnecting...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Tap to retry',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
                  icon: Icons.photo_library,
                  label: 'Photos',
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
                _NavBarItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  isSelected: currentIndex == 5,
                  onTap: () => context.go('/settings'),
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
    if (location.startsWith('/settings')) return 5;
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

/// Demo mode entry - enables demo mode and navigates to home
class _DemoModeEntry extends ConsumerWidget {
  const _DemoModeEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Enable demo mode and navigate to home
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(connectionProvider.notifier).enableDemoMode();
      context.go('/home');
    });

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class WimzApp extends ConsumerStatefulWidget {
  const WimzApp({super.key});

  @override
  ConsumerState<WimzApp> createState() => _WimzAppState();
}

class _WimzAppState extends ConsumerState<WimzApp> with WidgetsBindingObserver {
  /// B4: After this long in background, escalate from video-only pause (or
  /// any preserved state) to a full WebRTC teardown so we don't return to a
  /// half-dead PeerConnection on foreground.
  static const Duration _backgroundTeardownDelay = Duration(seconds: 30);
  Timer? _backgroundTeardownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _backgroundTeardownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        final bgAudio = ref.read(settingsProvider).backgroundAudioEnabled;
        if (bgAudio) {
          print('App: Lifecycle → $state — pausing video only (background audio ON)');
          ref.read(webrtcProvider.notifier).pauseVideoOnly();
        } else {
          print('App: Lifecycle → $state — pausing WebRTC');
          ref.read(webrtcProvider.notifier).pause();
        }
        // B4: schedule a deterministic teardown if we stay backgrounded long
        // enough that iOS will suspend us. Avoids the "video is broken until
        // sign out and back in" failure mode after a long background.
        _backgroundTeardownTimer?.cancel();
        _backgroundTeardownTimer = Timer(_backgroundTeardownDelay, () {
          print('App: Background teardown timer fired — forcing hard teardown');
          ref.read(webrtcProvider.notifier).hardTeardown();
        });
        break;
      case AppLifecycleState.resumed:
        print('App: Lifecycle → resumed — resuming WebRTC');
        _backgroundTeardownTimer?.cancel();
        // B4: if WS is dead by the time we foreground (iOS suspended us, or
        // the relay heartbeat-timed-out at 4002), tear down WebRTC hard so
        // the next reconnect builds a fresh PeerConnection rather than
        // layering an offer onto stale ICE state.
        final ws = ref.read(websocketClientProvider);
        if (ws.state != WsConnectionState.connected) {
          print('App: WS not connected on resume — hard teardown before reconnect');
          ref.read(webrtcProvider.notifier).hardTeardown();
        } else {
          ref.read(webrtcProvider.notifier).resume();
        }
        ref.read(connectionProvider.notifier).onAppResumed();
        break;
      case AppLifecycleState.detached:
        // Build 89: don't send client_closing — that frame is part of the
        // disabled session_hello protocol and the relay logs a warning on
        // unknown frames. Just hard-teardown WebRTC and close the WS.
        print('App: Lifecycle → detached — disconnecting');
        try {
          ref.read(webrtcProvider.notifier).hardTeardown();
        } catch (_) {/* best-effort */}
        try {
          ref.read(websocketClientProvider).disconnect();
        } catch (_) {/* best-effort */}
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
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
