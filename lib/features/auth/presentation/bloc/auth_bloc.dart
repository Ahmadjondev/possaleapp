import 'dart:convert';
import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/network/api_client.dart';
import 'package:pos_terminal/core/network/api_exception.dart';
import 'package:pos_terminal/features/auth/data/auth_local_storage.dart';
import 'package:pos_terminal/features/auth/data/auth_repository.dart';
import 'package:pos_terminal/features/auth/domain/user_model.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final AuthLocalStorage _authStorage;
  final ApiClient _apiClient;

  AuthBloc({
    required AuthRepository authRepository,
    required AuthLocalStorage authStorage,
    required ApiClient apiClient,
  }) : _authRepository = authRepository,
       _authStorage = authStorage,
       _apiClient = apiClient,
       super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthPinSubmitted>(_onPinSubmitted);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthLockRequested>(_onLockRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final serverUrl = _authStorage.getServerUrl();
    final accessToken = await _authStorage.getAccessToken();

    if (serverUrl == null || accessToken == null) {
      emit(const AuthUnauthenticated());
      return;
    }

    // Tokens exist — update API base URL and check user
    _apiClient.updateBaseUrl(serverUrl);

    try {
      final userData = await _authRepository.getCurrentUser();
      final user = UserModel.fromJson(userData);
      await _authStorage.saveCurrentUser(jsonEncode(user.toJson()));

      if (_authStorage.isPinVerifiedToday()) {
        emit(AuthAuthenticated(user: user));
      } else {
        emit(AuthPinRequired(user: user));
      }
    } on ApiException {
      // Token invalid / expired and refresh failed
      emit(const AuthUnauthenticated());
    } catch (e) {
      // Network error — try cached user for PIN screen
      final cachedUser = _authStorage.getCurrentUser();
      if (cachedUser != null) {
        final user = UserModel.fromJson(jsonDecode(cachedUser));
        emit(AuthPinRequired(user: user));
      } else {
        emit(
          const AuthUnauthenticated(errorMessage: 'Серверга уланиб бўлмади'),
        );
      }
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    // Read server URL saved during setup
    var serverUrl = _authStorage.getServerUrl()?.trim() ?? '';
    if (serverUrl.isEmpty) {
      emit(
        const AuthUnauthenticated(
          errorMessage: 'Сервер манзили созланмаган. Аввал созлашни ўтказинг.',
        ),
      );
      return;
    }
    if (!serverUrl.startsWith('http')) {
      serverUrl = 'https://$serverUrl';
    }
    if (serverUrl.endsWith('/')) {
      serverUrl = serverUrl.substring(0, serverUrl.length - 1);
    }

    _apiClient.updateBaseUrl(serverUrl);

    try {
      final result = await _authRepository.login(
        username: event.username,
        password: event.password,
      );

      final access = result['access'] as String;
      final refresh = result['refresh'] as String;

      await _authStorage.saveTokens(access: access, refresh: refresh);

      // Fetch user profile
      final userData = await _authRepository.getCurrentUser();
      final user = UserModel.fromJson(userData);
      await _authStorage.saveCurrentUser(jsonEncode(user.toJson()));

      // After login, require PIN verification
      emit(AuthPinRequired(user: user));
    } on ApiException catch (e) {
      emit(AuthUnauthenticated(errorMessage: e.message));
    } catch (e) {
      log('Login error: $e');
      emit(const AuthUnauthenticated(errorMessage: 'Серверга уланиб бўлмади'));
    }
  }

  Future<void> _onPinSubmitted(
    AuthPinSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is! AuthPinRequired) return;

    // Show loading indicator
    emit(
      AuthPinRequired(
        user: currentState.user,
        isVerifying: true,
        failedAttempts: currentState.failedAttempts,
      ),
    );

    try {
      final valid = await _authRepository.verifyPin(event.pin);
      if (valid) {
        await _authStorage.savePinVerifiedTimestamp();
        emit(AuthAuthenticated(user: currentState.user));
      } else {
        final attempts = currentState.failedAttempts + 1;
        if (attempts >= 5) {
          // Too many failed attempts — force re-login
          await _authStorage.clearAll();
          emit(
            const AuthUnauthenticated(
              errorMessage: 'Жуда кўп нотўғри уринишлар. Қайта киринг.',
            ),
          );
        } else {
          emit(
            AuthPinRequired(
              user: currentState.user,
              errorMessage: 'Нотўғри ПИН',
              failedAttempts: attempts,
            ),
          );
        }
      }
    } on ApiException catch (e) {
      emit(
        AuthPinRequired(
          user: currentState.user,
          errorMessage: e.message,
          failedAttempts: currentState.failedAttempts,
        ),
      );
    } catch (e) {
      emit(
        AuthPinRequired(
          user: currentState.user,
          errorMessage: 'Алоқа хатоси',
          failedAttempts: currentState.failedAttempts,
        ),
      );
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authStorage.clearAll();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onLockRequested(
    AuthLockRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final user = (state as AuthAuthenticated).user;
      await _authStorage.clearPinVerification();
      emit(AuthPinRequired(user: user));
    }
  }
}
