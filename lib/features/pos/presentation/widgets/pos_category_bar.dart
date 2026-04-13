import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/category/category_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/category/category_event_state.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/product/product_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/product/product_event.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

class PosCategoryBar extends StatelessWidget {
  const PosCategoryBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoryBloc, CategoryState>(
      builder: (context, state) {
        if (state is! CategoryLoaded) return const SizedBox.shrink();

        final categories = state.categories;
        final selectedId = state.selectedId;

        return Container(
          height: 52,
          color: context.colors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _CategoryChip(
                label: 'Барчаси',
                isSelected: selectedId == null,
                onTap: () {
                  context.read<CategoryBloc>().add(const CategorySelected());
                  context.read<ProductBloc>().add(
                    const ProductCategoryChanged(),
                  );
                },
              ),
              ...categories.map(
                (cat) => _CategoryChip(
                  label: cat.name,
                  count: cat.productCount,
                  isSelected: selectedId == cat.id,
                  onTap: () {
                    context.read<CategoryBloc>().add(
                      CategorySelected(categoryId: cat.id),
                    );
                    context.read<ProductBloc>().add(
                      ProductCategoryChanged(categoryId: cat.id),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      child: Material(
        color: isSelected ? AppColors.accent : context.colors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? context.colors.textPrimary
                        : context.colors.textSecondary,
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '($count)',
                    style: TextStyle(
                      color: isSelected
                          ? context.colors.textPrimary.withValues(alpha: 0.7)
                          : context.colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
