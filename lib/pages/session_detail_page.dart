import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/session_record.dart';
import '../utils/dates.dart';
import '../widgets/empty_state.dart';
import '../widgets/exercise_editor_sheet.dart';
import '../widgets/exercise_tile.dart';

/// 某一天的训练详情：既能回看，也能补打卡或修正记录。
class SessionDetailPage extends StatelessWidget {
  const SessionDetailPage({super.key, required this.date});

  final DateTime date;

  Future<void> _addItem(BuildContext context) async {
    final store = context.read<AppStore>();
    final result = await showExerciseEditor(context, title: '补记器械');
    if (result == null || result.item == null) return;
    await store.addSessionItem(date, result.item!);
  }

  Future<void> _editItem(BuildContext context, SessionItem entry) async {
    final store = context.read<AppStore>();
    final result = await showExerciseEditor(
      context,
      initial: entry.item,
      title: '编辑器械',
    );
    if (result == null) return;
    if (result.deleted) {
      await store.removeSessionItem(date, entry.id);
    } else if (result.item != null) {
      await store.updateSessionItem(date, result.item!);
    }
  }

  Future<void> _deleteRecord(BuildContext context) async {
    final store = context.read<AppStore>();
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('删除 ${formatFullDate(date)} 的训练记录？'),
        content: const Text('这一天的打卡和历史都会一并移除，且无法恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await store.deleteSession(date);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final store = context.watch<AppStore>();
    final record = store.sessionFor(date);

    return Scaffold(
      appBar: AppBar(
        title: Text('${formatFullDate(date)} ${weekdayName(date.weekday)}'),
        actions: <Widget>[
          IconButton(
            tooltip: '删除这一天记录',
            onPressed: () => _deleteRecord(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-session-detail',
        onPressed: () => _addItem(context),
        icon: const Icon(Icons.add),
        label: const Text('补记器械'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: <Widget>[
          Card(
            elevation: 0,
            color: scheme.primaryContainer.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    record.total == 0
                        ? '这一天没有训练记录'
                        : '完成 ${record.completedCount} / ${record.total} 台器械',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: record.progress,
                      minHeight: 8,
                      backgroundColor: scheme.surface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (record.items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: EmptyState(
                icon: Icons.fitness_center,
                title: '这一天没有记录',
                message: '可以补记当天用过的器械，历史里就会留下这一天。',
                action: FilledButton.icon(
                  onPressed: () => _addItem(context),
                  icon: const Icon(Icons.add),
                  label: const Text('补记器械'),
                ),
              ),
            )
          else
            for (final entry in record.items)
              ExerciseCheckTile(
                key: ValueKey<String>(entry.id),
                entry: entry,
                onToggle: () => store.toggleItem(date, entry.id),
                onEdit: () => _editItem(context, entry),
                onDelete: () => store.removeSessionItem(date, entry.id),
              ),
        ],
      ),
    );
  }
}
