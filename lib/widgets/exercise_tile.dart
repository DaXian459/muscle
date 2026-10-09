import 'package:flutter/material.dart';

import '../models/exercise_item.dart';
import '../models/session_record.dart';

/// 小圆角标签，用于「计划内」「已完成」这类状态提示。
class StatusTag extends StatelessWidget {
  const StatusTag({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 当天训练清单里的一项：点击任意位置即可切换完成状态。
class ExerciseCheckTile extends StatelessWidget {
  const ExerciseCheckTile({
    super.key,
    required this.entry,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
    this.onWeightTap,
  });

  final SessionItem entry;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// 点重量标签时回调。给了才显示标签。
  final VoidCallback? onWeightTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final completed = entry.completed;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: completed ? scheme.primaryContainer.withValues(alpha: 0.4) : null,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          child: Row(
            children: <Widget>[
              Checkbox(value: completed, onChanged: (_) => onToggle()),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            entry.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              decoration: completed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: completed ? scheme.onSurfaceVariant : null,
                            ),
                          ),
                        ),
                        if (entry.fromPlan) ...<Widget>[
                          const SizedBox(width: 6),
                          StatusTag(text: '计划内', color: scheme.secondary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: <Widget>[
                        Text(
                          // 有重量标签时摘要就不再重复重量
                          onWeightTap != null
                              ? entry.setsAndReps
                              : entry.summary,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        if (onWeightTap != null)
                          _WeightChip(
                            weight: entry.weight,
                            onTap: onWeightTap!,
                          ),
                      ],
                    ),
                    if (entry.note.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        entry.note,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  tooltip: '更多操作',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    if (onEdit != null)
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('编辑'),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('删除'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 周计划里的一项器械安排。
class PlanItemTile extends StatelessWidget {
  const PlanItemTile({
    super.key,
    required this.item,
    required this.index,
    this.onEdit,
    this.onDelete,
  });

  final ExerciseItem item;
  final int index;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 14,
              backgroundColor: scheme.primary.withValues(alpha: 0.12),
              child: Text(
                '${index + 1}',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: scheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    item.summary,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (item.note.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      item.note,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '更多操作',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(value: 'edit', child: Text('编辑')),
                PopupMenuItem<String>(value: 'delete', child: Text('删除')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 清单项上的重量标签：已记重量就显示数值，没记就提示可以添。
///
/// 单独做成可点的小标签，是因为整行的点击已经是「打勾」了 ——
/// 不能再把「改重量」挤进同一次点击里。
class _WeightChip extends StatelessWidget {
  const _WeightChip({required this.weight, required this.onTap});

  final double? weight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final load = weight;
    final hasWeight = load != null && load > 0;
    final color = hasWeight ? scheme.primary : scheme.onSurfaceVariant;

    return Material(
      color: hasWeight
          ? scheme.primary.withValues(alpha: 0.12)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                hasWeight ? Icons.fitness_center : Icons.add,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 3),
              Text(
                hasWeight ? '${formatWeight(load)} kg' : '重量',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
