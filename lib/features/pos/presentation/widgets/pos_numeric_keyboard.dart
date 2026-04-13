import 'package:flutter/material.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

/// Tracks the currently-active numeric input field.
/// The [PosNumericKeyboard] writes into whichever controller is registered.
class ActiveInputController extends ChangeNotifier {
  TextEditingController? _controller;
  int? _maxDigits;

  TextEditingController? get controller => _controller;
  bool get hasActiveField => _controller != null;

  /// Register [controller] as the active input target.
  /// Pass [maxDigits] to cap the total number of digit characters (0–9)
  /// the keyboard is allowed to type — useful for UZS money fields
  /// (use [kMaxMoneyInputDigits] from app_colors.dart).
  void setActive(TextEditingController controller, {int? maxDigits}) {
    if (_controller == controller) return;
    _controller = controller;
    _maxDigits = maxDigits;
    notifyListeners();
  }

  void clearActive([TextEditingController? controller]) {
    if (controller != null && _controller != controller) return;
    _controller = null;
    _maxDigits = null;
    notifyListeners();
  }

  void type(String value) {
    final c = _controller;
    if (c == null) return;
    // Enforce digit limit for money / numeric fields.
    final max = _maxDigits;
    if (max != null && value.length == 1 && RegExp(r'\d').hasMatch(value)) {
      final currentDigits = c.text.replaceAll(RegExp(r'[^\d]'), '').length;
      if (currentDigits >= max) return;
    }
    final text = c.text;
    final sel = c.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(start, end, value);
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + value.length),
    );
  }

  void backspace() {
    final c = _controller;
    if (c == null || c.text.isEmpty) return;
    final sel = c.selection;
    final start = sel.isValid ? sel.start : c.text.length;
    final end = sel.isValid ? sel.end : c.text.length;
    if (start == end) {
      if (start == 0) return;
      c.value = TextEditingValue(
        text: c.text.replaceRange(start - 1, end, ''),
        selection: TextSelection.collapsed(offset: start - 1),
      );
    } else {
      c.value = TextEditingValue(
        text: c.text.replaceRange(start, end, ''),
        selection: TextSelection.collapsed(offset: start),
      );
    }
  }

  void clear() {
    final c = _controller;
    if (c == null) return;
    c.value = const TextEditingValue();
  }
}

/// Compact numeric keypad for POS touchscreen input.
class PosNumericKeyboard extends StatelessWidget {
  final ActiveInputController controller;
  final bool large;

  const PosNumericKeyboard({
    super.key,
    required this.controller,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isActive = controller.hasActiveField;
        final gap = large ? 6.0 : 4.0;
        final pad = large ? 8.0 : 6.0;
        return FocusScope(
          canRequestFocus: false,
          child: Container(
            padding: EdgeInsets.all(pad),
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border(top: BorderSide(color: context.colors.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRow(['7', '8', '9', '⌫'], isActive),
                SizedBox(height: gap),
                _buildRow(['4', '5', '6', 'C'], isActive),
                SizedBox(height: gap),
                _buildRow(['1', '2', '3', '.'], isActive),
                SizedBox(height: gap),
                _buildRow(['0', '00', '000'], isActive),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRow(List<String> keys, bool isActive) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: large ? 3 : 2),
            child: _KeyButton(
              label: key,
              isActive: isActive,
              large: large,
              onTap: () => _handleKey(key),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _handleKey(String key) {
    switch (key) {
      case '⌫':
        controller.backspace();
      case 'C':
        controller.clear();
      default:
        controller.type(key);
    }
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool large;
  final VoidCallback onTap;

  const _KeyButton({
    required this.label,
    required this.isActive,
    this.large = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSpecial = label == '⌫' || label == 'C';
    final bgColor = isSpecial
        ? (label == '⌫'
              ? AppColors.danger.withValues(alpha: 0.15)
              : AppColors.warning.withValues(alpha: 0.15))
        : context.colors.surfaceLight;
    final textColor = isSpecial
        ? (label == '⌫' ? AppColors.danger : AppColors.warning)
        : context.colors.textPrimary;

    final height = large ? 90.0 : 70.0;
    final iconSize = large ? 28.0 : 18.0;
    final fontSize = large
        ? (label.length > 2 ? 18.0 : 24.0)
        : (label.length > 2 ? 13.0 : 16.0);
    final radius = BorderRadius.circular(large ? 8 : 6);

    return Material(
      color: bgColor,
      borderRadius: radius,
      child: InkWell(
        onTap: isActive ? onTap : null,
        borderRadius: radius,
        child: Container(
          height: height,
          alignment: Alignment.center,
          child: label == '⌫'
              ? Icon(
                  Icons.backspace_outlined,
                  size: iconSize,
                  color: isActive
                      ? textColor
                      : textColor.withValues(alpha: 0.3),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? textColor
                        : textColor.withValues(alpha: 0.3),
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
