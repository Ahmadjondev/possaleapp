import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/features/auth/domain/user_model.dart';
import 'package:pos_terminal/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pos_terminal/features/auth/presentation/bloc/auth_event.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

/// Placeholder home screen — will be replaced by the full POS sale screen.
class HomeScreen extends StatelessWidget {
  final UserModel user;

  const HomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          // Status bar
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: context.colors.surface,
            child: Row(
              children: [
                const Icon(
                  Icons.point_of_sale_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'POS Terminal',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (user.defaultWarehouseName != null) ...[
                  Icon(
                    Icons.warehouse_outlined,
                    color: context.colors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    user.defaultWarehouseName!,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Icon(
                  Icons.person_outline,
                  color: context.colors.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  user.displayName,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(
                    Icons.lock_outline,
                    color: context.colors.textSecondary,
                    size: 22,
                  ),
                  iconSize: 22,
                  tooltip: 'Lock (Ctrl+L)',
                  onPressed: () {
                    context.read<AuthBloc>().add(const AuthLockRequested());
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.logout,
                    color: context.colors.textSecondary,
                    size: 22,
                  ),
                  iconSize: 22,
                  tooltip: 'Logout',
                  onPressed: () {
                    context.read<AuthBloc>().add(const AuthLogoutRequested());
                  },
                ),
              ],
            ),
          ),

          // Main content placeholder
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Authentication Complete',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'POS sale screen will be implemented here',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
