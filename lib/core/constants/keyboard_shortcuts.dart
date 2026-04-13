import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keyboard shortcut bindings for POS operations.
class KeyboardShortcuts {
  KeyboardShortcuts._();

  // Sale actions
  static final pay = SingleActivator(LogicalKeyboardKey.f9);
  static final holdSale = SingleActivator(LogicalKeyboardKey.f10);
  static final recallSale = SingleActivator(LogicalKeyboardKey.f11);
  static final cancelSale = SingleActivator(LogicalKeyboardKey.escape);
  static final addToCart = SingleActivator(LogicalKeyboardKey.enter);
  static final removeItem = SingleActivator(LogicalKeyboardKey.delete);

  // Navigation
  static final search = SingleActivator(LogicalKeyboardKey.keyF, control: true);
  static final lockScreen = SingleActivator(
    LogicalKeyboardKey.keyL,
    control: true,
  );

  // Quantity
  static final increaseQty = SingleActivator(LogicalKeyboardKey.add);
  static final decreaseQty = SingleActivator(LogicalKeyboardKey.minus);

  // Category quick-switch (F1–F8)
  static final categoryKeys = [
    SingleActivator(LogicalKeyboardKey.f1),
    SingleActivator(LogicalKeyboardKey.f2),
    SingleActivator(LogicalKeyboardKey.f3),
    SingleActivator(LogicalKeyboardKey.f4),
    SingleActivator(LogicalKeyboardKey.f5),
    SingleActivator(LogicalKeyboardKey.f6),
    SingleActivator(LogicalKeyboardKey.f7),
    SingleActivator(LogicalKeyboardKey.f8),
  ];
}
