import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pos_terminal/core/constants/app_colors.dart';
import 'package:pos_terminal/features/pos/data/models/draft_model.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/cart/cart_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/cart/cart_event.dart';
import 'package:pos_terminal/features/pos/presentation/bloc/draft/draft_bloc.dart';
import 'package:pos_terminal/features/pos/presentation/pos_screen.dart';
import 'package:pos_terminal/features/pos/presentation/widgets/pos_dialog.dart';
import 'package:pos_terminal/core/constants/app_colors_extension.dart';

class DraftListDialog extends StatefulWidget {
  const DraftListDialog({super.key});

  static Future<void> show(BuildContext context) {
    // Trigger load before showing
    context.read<DraftBloc>().add(const DraftsLoadRequested());
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<DraftBloc>(),
        child: BlocProvider.value(
          value: context.read<CartBloc>(),
          child: const DraftListDialog(),
        ),
      ),
    );
  }

  @override
  State<DraftListDialog> createState() => _DraftListDialogState();
}

class _DraftListDialogState extends State<DraftListDialog> {
  void _loadDraft(DraftModel draft) {
    // Fetch full draft details (list endpoint may not include items)
    context.read<DraftBloc>().add(DraftLoadRequested(draftId: draft.id));
  }

  void _deleteDraft(int draftId) {
    context.read<DraftBloc>().add(DraftDeleteRequested(draftId: draftId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DraftBloc, DraftState>(
      listener: (context, state) {
        if (state is DraftDetailLoaded) {
          final items = state.draft.items.map((e) => e.toCartItem()).toList();
          if (items.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Қоралама бўш'),
                backgroundColor: AppColors.warning,
              ),
            );
            return;
          }
          context.read<CartBloc>().add(CartDraftLoaded(items: items));
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Қоралама #${state.draft.id} юкланди'),
              duration: const Duration(seconds: 2),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
      child: PosDialog(
        title: 'Қораламалар',
        icon: Icons.folder_open,
        width: 480,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.textSecondary,
              side: BorderSide(color: context.colors.border),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Ёпиш'),
          ),
        ],
        child: BlocBuilder<DraftBloc, DraftState>(
          builder: (context, state) {
            if (state is DraftLoading) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              );
            }

            if (state is DraftError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    state.message,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }

            if (state is DraftsLoaded) {
              if (state.drafts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.drafts_outlined,
                          color: context.colors.textMuted,
                          size: 40,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Қораламалар мавжуд эмас',
                          style: TextStyle(
                            color: context.colors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                itemCount: state.drafts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final draft = state.drafts[index];
                  return _DraftTile(
                    draft: draft,
                    onLoad: () => _loadDraft(draft),
                    onDelete: () => _deleteDraft(draft.id),
                  );
                },
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  final DraftModel draft;
  final VoidCallback onLoad;
  final VoidCallback onDelete;

  const _DraftTile({
    required this.draft,
    required this.onLoad,
    required this.onDelete,
  });

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = draft.itemCount > 0 ? draft.itemCount : draft.items.length;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                color: AppColors.accent,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.saleNumber != null
                          ? 'Қоралама ${draft.saleNumber}'
                          : 'Қоралама #${draft.id}',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      children: [
                        Text(
                          '$count маҳсулот',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (draft.customerName != null)
                          Text(
                            '• ${draft.customerName}',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        if (draft.createdAt != null &&
                            draft.createdAt!.isNotEmpty)
                          Text(
                            '• ${_formatDate(draft.createdAt)}',
                            style: TextStyle(
                              color: context.colors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    if (draft.note != null && draft.note!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        draft.note!,
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (draft.totalUzs > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    formatMoneyShort(draft.totalUzs),
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    onTap: onLoad,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.download,
                            size: 16,
                            color: AppColors.success,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Юклаш',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Material(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: AppColors.danger,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Ўчириш',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
