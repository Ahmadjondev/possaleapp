import 'package:equatable/equatable.dart';
import 'package:pos_terminal/features/auth/domain/user_model.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state — checking stored auth.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Checking tokens / PIN status on startup.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// No valid tokens — show login screen.
class AuthUnauthenticated extends AuthState {
  final String? errorMessage;

  const AuthUnauthenticated({this.errorMessage});

  @override
  List<Object?> get props => [errorMessage];
}

/// Logged in but PIN not verified today — show PIN lock.
class AuthPinRequired extends AuthState {
  final UserModel user;
  final String? errorMessage;
  final int failedAttempts;
  final bool isVerifying;

  const AuthPinRequired({
    required this.user,
    this.errorMessage,
    this.failedAttempts = 0,
    this.isVerifying = false,
  });

  @override
  List<Object?> get props => [user, errorMessage, failedAttempts, isVerifying];
}

/// Fully authenticated and PIN verified — show POS.
class AuthAuthenticated extends AuthState {
  final UserModel user;

  const AuthAuthenticated({required this.user});

  @override
  List<Object?> get props => [user];
}
