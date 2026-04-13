import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/features/auth/domain/user_model.dart';
import 'package:pos_terminal/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pos_terminal/features/auth/presentation/bloc/auth_event.dart';
import 'package:pos_terminal/features/auth/presentation/bloc/auth_state.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

class PinLockScreen extends StatefulWidget {
  final UserModel user;

  const PinLockScreen({super.key, required this.user});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  static const _pinLength = 4;
  final FocusNode _focusNode = FocusNode();

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 12,
    ).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);

    // Use HardwareKeyboard to avoid the duplicate KeyDownEvent assertion.
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;

    // Digit keys 0-9 (main keyboard + numpad)
    final digitMap = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };

    final digit = digitMap[key];
    if (digit != null) {
      _onDigit(digit);
      return true;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _onBackspace();
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      _onClear();
      return true;
    }
    return false;
  }

  void _onDigit(String digit) {
    // Block input while verifying
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthPinRequired && authState.isVerifying) return;

    if (_pin.length >= _pinLength) return;
    setState(() => _pin += digit);
    if (_pin.length == _pinLength) {
      _submitPin();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _onClear() {
    setState(() => _pin = '');
  }

  void _submitPin() {
    context.read<AuthBloc>().add(AuthPinSubmitted(pin: _pin));
  }

  void _onSwitchUser() {
    context.read<AuthBloc>().add(const AuthLogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthPinRequired &&
            state.errorMessage != null &&
            !state.isVerifying) {
          // Wrong PIN — shake and clear
          _shakeController.forward(from: 0);
          setState(() => _pin = '');
        }
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            child: Center(
              child: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final isVerifying =
                      state is AuthPinRequired && state.isVerifying;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // User indicator
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Center(
                          child: Text(
                            widget.user.displayName.isNotEmpty
                                ? widget.user.displayName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.user.displayName,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ПИН кодни киритинг',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // PIN dots with shake animation + loading overlay
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              _shakeController.status == AnimationStatus.forward
                                  ? _shakeAnimation.value *
                                        (_shakeController.value < 0.5 ? 1 : -1)
                                  : 0,
                              0,
                            ),
                            child: child,
                          );
                        },
                        child: isVerifying
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.accent,
                                ),
                              )
                            : _buildPinDots(),
                      ),

                      // Error message
                      if (state is AuthPinRequired &&
                          state.errorMessage != null &&
                          !state.isVerifying)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 12),

                      const SizedBox(height: 24),

                      // Numpad
                      IgnorePointer(
                        ignoring: isVerifying,
                        child: Opacity(
                          opacity: isVerifying ? 0.4 : 1.0,
                          child: _buildNumpad(),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Switch user link
                      TextButton(
                        onPressed: isVerifying ? null : _onSwitchUser,
                        child: Text(
                          'Фойдаланувчини алмаштириш',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_pinLength, (i) {
        final filled = i < _pin.length;
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.accent : Colors.transparent,
            border: Border.all(
              color: filled ? AppColors.accent : context.colors.textMuted,
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNumpad() {
    return SizedBox(
      width: 320,
      child: Column(
        children: [
          _numpadRow(['1', '2', '3']),
          const SizedBox(height: 12),
          _numpadRow(['4', '5', '6']),
          const SizedBox(height: 12),
          _numpadRow(['7', '8', '9']),
          const SizedBox(height: 12),
          _numpadRow(['⌫', '0', 'C']),
        ],
      ),
    );
  }

  Widget _numpadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        return SizedBox(
          width: 84,
          height: 64,
          child: Material(
            color: context.colors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                if (key == '⌫') {
                  _onBackspace();
                } else if (key == 'C') {
                  _onClear();
                } else {
                  _onDigit(key);
                }
              },
              child: Center(
                child: Text(
                  key,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
