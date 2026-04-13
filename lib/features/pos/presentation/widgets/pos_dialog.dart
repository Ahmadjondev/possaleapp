import 'package:flutter/material.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

/// Reusable Windows-style dialog shell for the POS desktop app.
///
/// Provides a consistent look: title bar (icon + title + close),
/// scrollable content area, and an optional action footer.
class PosDialog extends StatelessWidget {
  final String title;
  final IconData? icon;
  final double width;
  final double? height;
  final Widget child;
  final List<Widget>? actions;

  /// When false, skips the [Dialog] wrapper — useful when composing
  /// this panel inside a custom overlay layout (e.g. side-by-side keyboard).
  final bool useDialogShell;

  const PosDialog({
    super.key,
    required this.title,
    this.icon,
    this.width = 420,
    this.height,
    required this.child,
    this.actions,
    this.useDialogShell = true,
  });

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      width: width,
      height: height,
      constraints: BoxConstraints(
        maxHeight: height ?? MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title bar ─────────────────────────────────
          _TitleBar(title: title, icon: icon),
          // ── Content ───────────────────────────────────
          Flexible(child: child),
          // ── Footer ────────────────────────────────────
          if (actions != null && actions!.isNotEmpty)
            _Footer(actions: actions!),
        ],
      ),
    );

    if (!useDialogShell) return panel;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: panel,
    );
  }
}

class _TitleBar extends StatelessWidget {
  final String title;
  final IconData? icon;

  const _TitleBar({required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.accent, size: 16),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _CloseButton(onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        hoverColor: AppColors.danger.withValues(alpha: 0.2),
        child: Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.close, color: context.colors.textMuted, size: 16),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final List<Widget> actions;
  const _Footer({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
    );
  }
}
