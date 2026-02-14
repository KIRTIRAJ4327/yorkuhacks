import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/arrival_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/navigation_screen.dart';
import 'presentation/screens/route_selection_screen.dart';
import 'presentation/screens/safety_chat_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'providers/theme_provider.dart';

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/routes',
      builder: (context, state) => const RouteSelectionScreen(),
    ),
    GoRoute(
      path: '/navigate',
      builder: (context, state) => const NavigationScreen(),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const SafetyChatScreen(),
    ),
    GoRoute(
      path: '/arrived',
      builder: (context, state) => const ArrivalScreen(),
    ),
  ],
);

class SafePathApp extends ConsumerWidget {
  const SafePathApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'SafePath York',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
