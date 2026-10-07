import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/exercise_item.dart';
import '../utils/dates.dart';
import '../widgets/empty_state.dart';
import '../widgets/exercise_editor_sheet.dart';
import '../widgets/exercise_tile.dart';

/// 周计划：为周一 ~ 周日分别安排要用的器械，这份模板会被复制到具体某一天。
class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  int _weekday = DateTime.now().weekday;

  Future<void> _addItem() async {
    final result = await showExerciseEditor(
      context,
      title: '为${weekdayName(_weekday)}添加器械',
    );
    if (!mounted || result == null || result.item == null) return;
    await context.read<AppStore>().addPlanItem(_weekday, result.item!);
  }

  Future<void> _editItem(ExerciseItem item) async {
    final result = await showExerciseEditor(
      context,
      initial: item,
      title: '编辑器械',
    );
    if (!mounted || result == null) return;
    final store = context.read<AppStore>();
    if (result.deleted) {
      await store.removePlanItem(_weekday, item.id);
    } else if (result.item != null) {
      await store.updatePlanItem(_weekday, result.item!);
    }
  }

  Future<void> _removeItem(ExerciseItem item) async {
    final store = context.read<AppStore>();
    final weekday = _weekday;
    await store.removePlanItem(weekday, item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已从${weekdayName(weekday)}移除「${item.name}」'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => store.addPlanItem(weekday, item),
        ),
      ),
    );
  }

  Future<void> _clearDay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('清空${weekdayName(_weekday)}的安排？'),
        content: const Text('只影响周计划模板，已经产生的训练记录不会变化。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AppStore>().clearPlanDay(_weekday);
  }

  Future<void> _copyToOtherDays() async {
    final source = _weekday;
    final targets = <int>{};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('把${weekdayName(source)}的安排复制到'),
          content: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              for (var day = 1; day <= 7; day++)
                if (day != source)
                  FilterChip(
                    label: Text(weekdayName(day)),
                    selected: targets.contains(day),
                    onSelected: (selected) => setDialogState(() {
                      if (selected) {
                        targets.add(day);
                      } else {
                        targets.remove(day);
                      }
                    }),
                  ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('复制'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || targets.isEmpty || !mounted) return;
    final store = context.read<AppStore>();
    for (final day in targets) {
      await store.copyPlanDay(source, day);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制到 ${targets.map(weekdayName).join('、')}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<AppStore>();
    final items = store.planFor(_weekday);

    return Scaffold(
      appBar: AppBar(title: const Text('周计划')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-plan',
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: Text('添加器械'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: <Widget>[
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final weekday = index + 1;
                return _WeekdayCard(
                  weekday: weekday,
                  count: store.planFor(weekday).length,
                  selected: weekday == _weekday,
                  isToday: weekday == DateTime.now().weekday,
                  onTap: () => setState(() => _weekday = weekday),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _overviewCard(theme, store),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${weekdayName(_weekday)}的安排',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: '复制到其他天',
                onPressed: items.isEmpty ? null : _copyToOtherDays,
                icon: const Icon(Icons.copy_all),
              ),
              IconButton(
                tooltip: '清空这一天',
                onPressed: items.isEmpty ? null : _clearDay,
                icon: const Icon(Icons.playlist_remove),
              ),
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: EmptyState(
                icon: Icons.event_available,
                title: '${weekdayName(_weekday)}还没有安排',
                message: '把这一天要练的器械加进来，之后每天打开「今日训练」就能直接照着打卡。',
                action: FilledButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('添加器械'),
                ),
              ),
            )
          else
            for (var index = 0; index < items.length; index++)
              PlanItemTile(
                key: ValueKey<String>(items[index].id),
                item: items[index],
                index: index,
                onEdit: () => _editItem(items[index]),
                onDelete: () => _removeItem(items[index]),
              ),
        ],
      ),
    );
  }

  Widget _overviewCard(ThemeData theme, AppStore store) {
    final scheme = theme.colorScheme;
    final thisWeekDone = store.completedInWeek(DateTime.now());
    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '每周安排 ${store.plan.totalItems} 个动作 · 训练 ${store.plan.trainingDayCount} 天',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '本周已完成 $thisWeekDone 台器械，累计打卡 ${store.trainingDayCount} 天',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayCard extends StatelessWidget {
  const _WeekdayCard({
    required this.weekday,
    required this.count,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final int weekday;
  final int count;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = selected
        ? scheme.primary
        : scheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 68,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: isToday && !selected
              ? Border.all(color: scheme.primary, width: 1.4)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              weekdayName(weekday),
              style: theme.textTheme.labelLarge?.copyWith(color: foreground),
            ),
            const SizedBox(height: 6),
            Text(
              count == 0 ? '休息' : '$count 台',
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected
                    ? scheme.onPrimary.withValues(alpha: 0.85)
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
