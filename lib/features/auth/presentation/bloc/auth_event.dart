import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// App started — check stored tokens and PIN status.
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// User submits login form.
class AuthLoginRequested extends AuthEvent {
  final String username;
  final String password;

  const AuthLoginRequested({required this.username, required this.password});

  @override
  List<Object?> get props => [username, password];
}

/// User submits PIN on lock screen.
class AuthPinSubmitted extends AuthEvent {
  final String pin;

  const AuthPinSubmitted({required this.pin});

  @override
  List<Object?> get props => [pin];
}

/// User taps "Switch User" or logs out.
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Lock screen triggered (manual or auto on app resume).
class AuthLockRequested extends AuthEvent {
  const AuthLockRequested();
}
