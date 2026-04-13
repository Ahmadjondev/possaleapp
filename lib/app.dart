import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/constants/app_theme.dart';
import 'package:pos_terminal/core/di/injection.dart';
import 'package:pos_terminal/core/printing/printer_config.dart';
import 'package:pos_terminal/core/router/app_router.dart';
import 'package:pos_terminal/core/theme/theme_cubit.dart';
import 'package:pos_terminal/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pos_terminal/features/auth/presentation/bloc/auth_event.dart';
import 'package:pos_terminal/features/auth/presentation/bloc/auth_state.dart';

/// Inactivity lock timeout.
const _kInactivityTimeout = Duration(minutes: 30);

class PosTerminalApp extends StatefulWidget {
  const PosTerminalApp({super.key});

  @override
  State<PosTerminalApp> createState() => _PosTerminalAppState();
}

class _PosTerminalAppState extends State<PosTerminalApp> {
  late final AuthBloc _authBloc;
  late final AppRouter _appRouter;
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _authBloc = getIt<AuthBloc>();
    _appRouter = AppRouter(
      authBloc: _authBloc,
      configStorage: getIt<PrinterConfigStorage>(),
    );
    _authBloc.add(const AuthCheckRequested());
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _authBloc.close();
    super.dispose();
  }

  void _resetInactivityTimer() {
    if (_authBloc.state is! AuthAuthenticated) return;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_kInactivityTimeout, _lockNow);
  }

  void _lockNow() {
    if (_authBloc.state is AuthAuthenticated) {
      _authBloc.add(const AuthLockRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider.value(value: getIt<ThemeCubit>()),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        bloc: _authBloc,
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            _resetInactivityTimer();
          } else {
            _inactivityTimer?.cancel();
          }
        },
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp.router(
              title: 'Digitex POS Terminal',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeMode,
              routerConfig: _appRouter.router,
              builder: (context, child) {
                return Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _resetInactivityTimer(),
                  onPointerMove: (_) => _resetInactivityTimer(),
                  child: child!,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
