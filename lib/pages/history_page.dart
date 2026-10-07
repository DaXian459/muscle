import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/session_record.dart';
import '../utils/dates.dart';
import '../widgets/empty_state.dart';
import '../widgets/exercise_tile.dart';
import 'session_detail_page.dart';

enum HistoryFilter { all, completed, unfinished }

/// 历史训练记录：按月份分组的打卡列表。
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  HistoryFilter _filter = HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<AppStore>();
    final records = store.history
        .where((record) => switch (_filter) {
              HistoryFilter.all => true,
              HistoryFilter.completed => record.allCompleted,
              HistoryFilter.unfinished => !record.allCompleted,
            })
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('历史记录')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          _stats(theme, store),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: <Widget>[
                for (final filter in HistoryFilter.values)
                  ChoiceChip(
                    label: Text(switch (filter) {
                      HistoryFilter.all => '全部',
                      HistoryFilter.completed => '已完成',
                      HistoryFilter.unfinished => '未完成',
                    }),
                    selected: _filter == filter,
                    onSelected: (selected) {
                      if (selected) setState(() => _filter = filter);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.history,
                title: store.history.isEmpty ? '还没有训练记录' : '没有符合条件的记录',
                message: store.history.isEmpty
                    ? '去「今日训练」把练过的器械打上勾，这里就会自动留下来。'
                    : '换一个筛选条件试试。',
              ),
            )
          else
            ..._buildGroupedList(theme, records),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedList(ThemeData theme, List<SessionRecord> records) {
    final widgets = <Widget>[];
    String? currentMonth;
    for (final record in records) {
      final date = parseDateKey(record.date);
      if (date == null) continue;
      final month = formatMonth(date);
      if (month != currentMonth) {
        currentMonth = month;
        widgets.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, widgets.isEmpty ? 8 : 20, 4, 6),
            child: Text(
              '$month · 共 ${records.where((item) => item.date.startsWith(record.date.substring(0, 7))).length} 次',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        );
      }
      widgets.add(_recordCard(theme, record, date));
    }
    return widgets;
  }

  Widget _stats(ThemeData theme, AppStore store) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatCard(
            label: '训练天数',
            value: '${store.trainingDayCount}',
            unit: '天',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: '完成器械',
            value: '${store.completedItemCount}',
            unit: '次',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: '连续打卡',
            value: '${store.currentStreak}',
            unit: '天',
          ),
        ),
      ],
    );
  }

  Widget _recordCard(ThemeData theme, SessionRecord record, DateTime date) {
    final scheme = theme.colorScheme;
    final completedNames = record.items
        .where((entry) => entry.completed)
        .map((entry) => entry.name)
        .toList();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => SessionDetailPage(date: date),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    formatShortDate(date),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${describeDay(date)} · ${weekdayName(date.weekday)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  _statusTag(scheme, record),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: record.progress,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '完成 ${record.completedCount}/${record.total} 台器械',
                style: theme.textTheme.bodyMedium,
              ),
              if (completedNames.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final name in completedNames)
                      StatusTag(text: name, color: scheme.primary),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusTag(ColorScheme scheme, SessionRecord record) {
    if (record.allCompleted) {
      return StatusTag(text: '已全部完成', color: scheme.primary);
    }
    if (record.completedCount > 0) {
      return StatusTag(text: '部分完成', color: scheme.tertiary);
    }
    return StatusTag(text: '未完成', color: scheme.error);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.unit});

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: <Widget>[
            RichText(
              text: TextSpan(
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: scheme.primary),
                children: <InlineSpan>[
                  TextSpan(text: value),
                  TextSpan(
                    text: unit,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
