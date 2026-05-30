import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/network/dio_client.dart';
import 'core/network/websocket_client.dart';
import 'data/models/night_mode_state.dart';
import 'domain/providers/auth_provider.dart';
import 'domain/providers/connection_provider.dart';
import 'domain/providers/control_provider.dart';
import 'domain/providers/night_mode_provider.dart';
import 'domain/providers/notifications_provider.dart';
import 'domain/providers/settings_provider.dart';
import 'domain/providers/voice_commands_provider.dart';
import 'domain/providers/webrtc_provider.dart';
import 'presentation/screens/auth/forgot_password_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/drive/drive_screen.dart';
import 'presentation/screens/missions/missions_screen.dart';
import 'presentation/screens/missions/mission_detail_screen.dart';
import 'presentation/screens/programs/program_detail_screen.dart';
import 'presentation/screens/coach/coach_screen.dart';
import 'presentation/screens/history/history_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/settings/device_pairing_screen.dart';
import 'presentation/screens/settings/connection_diagnostics_screen.dart';
import 'presentation/screens/settings/notification_preferences_screen.dart';
import 'presentation/screens/notifications/notifications_screen.dart';
import 'presentation/screens/dog_profile/dog_profile_screen.dart';
import 'presentation/screens/dog_profile/add_dog_screen.dart';
import 'presentation/screens/dog_profile/edit_dog_screen.dart';
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

/// Paths reachable while signed out. Anything else is bounced to /login
/// by the router's redirect guard when authProvider says !isAuthenticated.
const _publicPaths = <String>{'/', '/login', '/demo', '/forgot-password'};

/// Builds the app router. Lives inside [_WimzAppState] so the redirect can
/// read the current auth state from Riverpod. [refreshListenable] is bumped
/// whenever authProvider's identity-affecting fields change so GoRouter
/// re-evaluates redirects — without it, a logout() call while sitting on
/// /home would leave the user stranded watching "Reconnecting…".
GoRouter _buildRouter(WidgetRef ref, Listenable refreshListenable) => GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: refreshListenable,
  redirect: (context, state) {
    final auth = ref.read(authProvider);
    final path = state.uri.path;
    // While silent re-auth is in flight, stay on splash. The splash screen
    // does the routing once bootstrapping completes.
    if (auth.bootstrapping) {
      return path == '/' ? null : '/';
    }
    // Gate /login on isAuthenticated: an already-signed-in user shouldn't
    // see the login screen.
    if (path == '/login' && auth.isAuthenticated) {
      return '/home';
    }
    // Protected-route guard: anyone hitting a non-public path while signed
    // out gets bounced to /login. Pairs with logout(notice:) — the notice
    // survives the auth-state reset so /login can explain the bounce.
    //
    // Build 111: local-AP and demo mode never authenticate against the relay
    // (setLocalConnected()/enableDemoMode() touch connectionProvider, not
    // authProvider), but they are legitimately connected and MUST be allowed
    // onto protected routes. The Build 99 guard didn't account for them, so
    // "Connect to Robot" and "Demo Mode" both navigated to /home and were
    // instantly bounced back to /login — the user could never get past the
    // login screen (and the stuck "Connecting…" spinner made it look frozen).
    if (!auth.isAuthenticated && !_publicPaths.contains(path)) {
      final inDemoMode = ref.read(connectionProvider).isDemoMode;
      final inLocalMode = ref.read(settingsProvider).localModeEnabled;
      if (!inDemoMode && !inLocalMode) {
        return '/login';
      }
    }
    return null;
  },
  routes: [
    // Splash / silent re-auth gate (initial location)
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),

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

    // Password recovery (public — reachable while signed out)
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ForgotPasswordScreen(
          initialEmail: extra?['email'] as String?,
        );
      },
    ),

    // Main app shell with bottom navigation.
    //
    // Build 100: switched from ShellRoute → StatefulShellRoute.indexedStack so
    // tab widget trees stay MOUNTED when the user switches tabs. The previous
    // ShellRoute disposed HomeScreen on every nav-away, which destroyed the
    // iOS RTCVideoView platform-view; the renderer's MediaStream survived in
    // the provider, but rebinding the native texture cost 1–5s of black-screen
    // on every return to /home. IndexedStack keeps every branch's tree alive
    // so the texture binding is never torn down.
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        // Branch 0 — Home tab
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
        ]),

        // Branch 1 — Dogs tab
        StatefulShellBranch(routes: [
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
        ]),

        // Branch 2 — Missions tab (also serves /programs since they share a screen)
        StatefulShellBranch(routes: [
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
          GoRoute(
            path: '/programs',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MissionsScreen(),
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
        ]),

        // Branch 3 — Photo Gallery
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/gallery',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PhotoGalleryScreen(),
            ),
          ),
        ]),

        // Branch 4 — Activity / Notifications
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/activity',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: NotificationsScreen(),
            ),
          ),
        ]),

        // Branch 5 — Settings
        StatefulShellBranch(routes: [
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
              GoRoute(
                path: 'connection-diagnostics',
                builder: (context, state) =>
                    const ConnectionDiagnosticsScreen(),
              ),
            ],
          ),
        ]),
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
      routes: [
        GoRoute(
          path: 'edit',
          builder: (context, state) => EditDogScreen(
            dogId: state.pathParameters['id']!,
          ),
        ),
      ],
    ),
  ],
);

/// Main shell with bottom navigation.
///
/// Build 100: now hosts a [StatefulNavigationShell] from
/// StatefulShellRoute.indexedStack. The shell internally uses IndexedStack so
/// every branch's widget tree stays mounted between tab switches — critical
/// for the home tab's WebRTC video, whose iOS native texture would otherwise
/// re-bind on every return (1–5s black-screen).
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider);
    final connState = ref.watch(connectionProvider);

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

    // Branch index is owned by the shell itself; no path parsing needed.
    final currentIndex = navigationShell.currentIndex;

    // Show reconnecting banner when connection lost with saved host (not demo mode)
    final showReconnecting = !connState.isDemoMode &&
        connState.host != null &&
        (connState.status == ConnectionStatus.connecting ||
         connState.status == ConnectionStatus.error);

    return Scaffold(
      body: Stack(
        children: [
          navigationShell,
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
                  onTap: () => _goBranch(0),
                ),
                _NavBarItem(
                  icon: Icons.pets,
                  label: 'Dogs',
                  isSelected: currentIndex == 1,
                  onTap: () => _goBranch(1),
                ),
                _NavBarItem(
                  icon: Icons.flag,
                  label: 'Missions',
                  isSelected: currentIndex == 2,
                  onTap: () => _goBranch(2),
                ),
                _NavBarItem(
                  icon: Icons.photo_library,
                  label: 'Photos',
                  isSelected: currentIndex == 3,
                  onTap: () => _goBranch(3),
                ),
                _NavBarItem(
                  icon: Icons.notifications,
                  label: 'Activity',
                  isSelected: currentIndex == 4,
                  badgeCount: unreadCount,
                  onTap: () => _goBranch(4),
                ),
                _NavBarItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  isSelected: currentIndex == 5,
                  onTap: () => _goBranch(5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Switch to a branch. If the user taps the already-selected tab, reset that
  /// branch's nested stack back to its initial route (matches the previous
  /// `context.go('/home')` behavior, which collapsed pushed sub-routes).
  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
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
  late final GoRouter _router;
  // Bumped whenever authProvider's identity-affecting fields change; drives
  // GoRouter.refreshListenable so a logout() (4001 or 401) immediately
  // re-evaluates redirects and bounces the user to /login.
  final ValueNotifier<int> _authRefresh = ValueNotifier<int>(0);
  ProviderSubscription<AuthState>? _authSub;
  ProviderSubscription<bool>? _localModeSub;
  ProviderSubscription<bool>? _demoModeSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = _buildRouter(ref, _authRefresh);
    _authSub = ref.listenManual<AuthState>(authProvider, (prev, next) {
      if (prev?.isAuthenticated != next.isAuthenticated ||
          prev?.bootstrapping != next.bootstrapping) {
        _authRefresh.value++;
      }
    });
    // Build 111: the redirect guard now also treats local-AP and demo mode as
    // "may access protected routes". Re-evaluate routing when EITHER toggles,
    // so exiting those modes (e.g. local→sign out) re-applies the guard. Keyed
    // on the specific flags — not on connection status — so the 2s status-check
    // churn can't trigger a redirect storm.
    _localModeSub = ref.listenManual<bool>(
      settingsProvider.select((s) => s.localModeEnabled),
      (prev, next) {
        if (prev != next) _authRefresh.value++;
      },
    );
    _demoModeSub = ref.listenManual<bool>(
      connectionProvider.select((c) => c.isDemoMode),
      (prev, next) {
        if (prev != next) _authRefresh.value++;
      },
    );
    // Build 104: instantiate the voice-commands auto-sync coordinator. It
    // subscribes to the WS state stream and re-pushes any unsynced
    // recordings the moment we go connected.
    ref.read(voiceCommandsAutoSyncProvider);

    // Wire Dio's 401 callback so REST auth failures route through the same
    // logout(notice:) path as WS 4001. See dio_client.dart.
    DioClient.onUnauthorized = () {
      final auth = ref.read(authProvider);
      if (!auth.isAuthenticated) return;
      ref.read(authProvider.notifier).logout(
            notice: 'Your session expired — please sign in again.',
          );
    };
  }

  @override
  void dispose() {
    _backgroundTeardownTimer?.cancel();
    _authSub?.close();
    _localModeSub?.close();
    _demoModeSub?.close();
    _authRefresh.dispose();
    DioClient.onUnauthorized = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Build 113: stop the wheels the instant we lose foreground while
        // driving. The robot's 500ms motor watchdog is the backstop; this
        // makes the stop immediate (sends a zero over whatever transport is
        // alive, and zeros local state so resume can't pick up at speed).
        ref.read(motorControlProvider.notifier).emergencyStop();

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
    // Build 100: app-wide chrome shift driven by the robot's night_mode_state.
    // Swapping the theme primary cyan → steel-blue makes every screen feel
    // the mode change without modifying the IR video pixels themselves.
    final nightState = ref.watch(nightModeProvider);
    final isNight = nightState?.currentMode == DayNight.night;
    final theme = isNight ? AppTheme.darkNight : AppTheme.dark;
    return MaterialApp.router(
      title: 'WIM-Z',
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
