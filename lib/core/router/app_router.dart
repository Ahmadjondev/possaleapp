import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_terminal/core/printing/printer_config.dart';
import 'package:pos_terminal/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pos_terminal/features/auth/presentation/bloc/auth_state.dart';
import 'package:pos_terminal/features/auth/presentation/login_screen.dart';
import 'package:pos_terminal/features/auth/presentation/pin_lock_screen.dart';
import 'package:pos_terminal/features/pos/presentation/pos_screen.dart';
import 'package:pos_terminal/features/pos/presentation/screens/barcode_printing_screen.dart';
import 'package:pos_terminal/features/pos/presentation/screens/featured_products_screen.dart';
import 'package:pos_terminal/features/pos/presentation/screens/sales_list_screen.dart';
import 'package:pos_terminal/features/settings/presentation/settings_screen.dart';
import 'package:pos_terminal/features/setup/presentation/setup_screen.dart';
import 'package:pos_terminal/features/splash/splash_screen.dart';

class AppRouter {
  final AuthBloc authBloc;
  final PrinterConfigStorage configStorage;

  AppRouter({required this.authBloc, required this.configStorage});

  late final GoRouter router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final location = state.matchedLocation;

      // Always allow splash and setup screens
      if (location == '/splash' || location == '/setup') return null;

      // If setup not done, force to setup
      if (!configStorage.isSetupCompleted) {
        return '/setup';
      }

      final authState = authBloc.state;

      if (authState is AuthLoading || authState is AuthInitial) {
        return null; // Stay on current page while loading
      }

      if (authState is AuthUnauthenticated) {
        return location == '/login' ? null : '/login';
      }

      if (authState is AuthPinRequired) {
        return location == '/pin' ? null : '/pin';
      }

      if (authState is AuthAuthenticated) {
        if (location == '/login' || location == '/pin') {
          return '/';
        }
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/setup', builder: (context, state) => const SetupScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/pin',
        builder: (context, state) {
          final authState = authBloc.state;
          if (authState is AuthPinRequired) {
            return PinLockScreen(user: authState.user);
          }
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          final authState = authBloc.state;
          if (authState is AuthAuthenticated) {
            return PosScreen(user: authState.user);
          }
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) {
          final authState = authBloc.state;
          if (authState is AuthAuthenticated) {
            return SettingsScreen(user: authState.user);
          }
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: '/sales',
        builder: (context, state) {
          final authState = authBloc.state;
          if (authState is AuthAuthenticated) {
            return const SalesListScreen();
          }
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: '/featured',
        builder: (context, state) {
          final authState = authBloc.state;
          if (authState is AuthAuthenticated) {
            return const FeaturedProductsScreen();
          }
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: '/barcode-printing',
        builder: (context, state) {
          final authState = authBloc.state;
          if (authState is AuthAuthenticated) {
            return const BarcodePrintingScreen();
          }
          return const LoginScreen();
        },
      ),
    ],
  );
}

/// Converts a Stream into a Listenable for GoRouter's refreshListenable.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    stream.listen((_) => notifyListeners());
  }
}
