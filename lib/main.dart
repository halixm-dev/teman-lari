import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/utils/responsive.dart';
import 'data/datasources/preferences_storage.dart';
import 'data/backup/snapshot_backup_service.dart';
import 'presentation/widgets/local_recovery_gate.dart';
import 'presentation/widgets/tracked_workout_guard.dart';
import 'domain/entities/training_plan.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/core_provider.dart';
import 'presentation/screens/analysis_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/plan_screen.dart';
import 'presentation/screens/run_session_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/theme/app_theme.dart';

GoRouter createRouter({
  PreferencesStorage? preferencesStorage,
  String initialLocation = '/dashboard',
}) {
  final storage = preferencesStorage ?? PreferencesStorage();
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/dashboard'),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const MainNavigationScreen(),
      ),
      GoRoute(
        path: '/analysis',
        builder: (context, state) => const AnalysisScreen(),
      ),
      GoRoute(path: '/plan', builder: (context, state) => const PlanScreen()),
      GoRoute(
        path: '/run-session',
        builder: (context, state) => TrackedWorkoutGuard(
          child: RunSessionScreen(day: state.extra as TrainingDay),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    redirect: (context, state) async {
      final hasCompleted = await storage.hasCompletedOnboarding();
      final loc = state.matchedLocation;
      if (loc == '/') {
        return hasCompleted ? '/dashboard' : '/onboarding';
      }
      if (!hasCompleted && loc == '/dashboard') {
        return '/onboarding';
      }
      if (hasCompleted && loc == '/onboarding') {
        return '/dashboard';
      }
      return null;
    },
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(
    LocalRecoveryGate(
      initialize: SnapshotBackupService.shared.initialize,
      ready: () => const ProviderScope(child: TemanLariApp()),
    ),
  );
}

class TemanLariApp extends ConsumerStatefulWidget {
  final RouterConfig<Object>? routerConfig;

  const TemanLariApp({super.key, this.routerConfig});

  @override
  ConsumerState<TemanLariApp> createState() => _TemanLariAppState();
}

class _TemanLariAppState extends ConsumerState<TemanLariApp> {
  late RouterConfig<Object> _router;

  @override
  void initState() {
    super.initState();
    _router =
        widget.routerConfig ??
        createRouter(preferencesStorage: ref.read(preferencesStorageProvider));
  }

  @override
  void didUpdateWidget(TemanLariApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routerConfig != oldWidget.routerConfig) {
      _router =
          widget.routerConfig ??
          createRouter(
            preferencesStorage: ref.read(preferencesStorageProvider),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Teman Lari',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.isLoading) return;
      context.go('/dashboard');
    });

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    AnalysisScreen(),
    PlanScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      return _DesktopNavigationScaffold(
        currentIndex: _currentIndex,
        screens: _screens,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
      );
    }
    return _MobileNavigationScaffold(
      currentIndex: _currentIndex,
      screens: _screens,
      onDestinationSelected: (index) => setState(() => _currentIndex = index),
    );
  }
}

class _DesktopNavigationScaffold extends StatelessWidget {
  final int currentIndex;
  final List<Widget> screens;
  final ValueChanged<int> onDestinationSelected;

  const _DesktopNavigationScaffold({
    required this.currentIndex,
    required this.screens,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ImageIcon(
                const AssetImage('assets/icons/Icon.png'),
                color: Theme.of(context).colorScheme.primary,
                size: 48,
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics),
                label: Text('Analysis'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_today),
                label: Text('Plan'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: screens[currentIndex]),
        ],
      ),
    );
  }
}

class _MobileNavigationScaffold extends StatelessWidget {
  final int currentIndex;
  final List<Widget> screens;
  final ValueChanged<int> onDestinationSelected;

  const _MobileNavigationScaffold({
    required this.currentIndex,
    required this.screens,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Analysis'),
          NavigationDestination(
            icon: Icon(Icons.calendar_today),
            label: 'Plan',
          ),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
