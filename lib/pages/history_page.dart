import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/session_record.dart';
import '../utils/dates.dart';
import '../widgets/empty_state.dart';
import '../widgets/exercise_tile.dart';
import 'about_page.dart';
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
    final allRecords = store.history;
    final records = allRecords
        .where((record) => switch (_filter) {
              HistoryFilter.all => true,
              HistoryFilter.completed => record.allCompleted,
              HistoryFilter.unfinished => !record.allCompleted,
            })
        .toList();

    // 每个月的条数一次算清。原来是遍历到某个月时再用 where 全文扫一遍，
    // 记录攒多了就是 O(n²)。
    final monthCounts = <String, int>{};
    for (final record in records) {
      final key = _monthKey(record.date);
      monthCounts[key] = (monthCounts[key] ?? 0) + 1;
    }

    // 把「月份标题 + 记录」摊平成一维列表。这里只放引用，不建 widget；
    // 真正的构建交给下面的 SliverList.builder，只做屏幕上看得见的那几行。
    final rows = <_HistoryRow>[];
    String? currentMonthKey;
    for (final record in records) {
      final date = parseDateKey(record.date);
      if (date == null) continue;
      final key = _monthKey(record.date);
      if (key != currentMonthKey) {
        currentMonthKey = key;
        rows.add(_HistoryRow.month(formatMonth(date), monthCounts[key] ?? 0));
      }
      rows.add(_HistoryRow.record(record, date));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: <Widget>[
          IconButton(
            tooltip: '关于',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (context) => const AboutPage()),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                ],
              ),
            ),
          ),
          if (rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                child: EmptyState(
                  icon: Icons.history,
                  title: allRecords.isEmpty ? '还没有训练记录' : '没有符合条件的记录',
                  message: allRecords.isEmpty
                      ? '去「今日训练」把练过的器械打上勾，这里就会自动留下来。'
                      : '换一个筛选条件试试。',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final record = row.record;
                  if (record == null) {
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        4,
                        index == 0 ? 8 : 20,
                        4,
                        6,
                      ),
                      child: Text(
                        '${row.monthLabel} · 共 ${row.monthCount} 次',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    );
                  }
                  return _recordCard(theme, record, row.date!);
                },
              ),
            ),
        ],
      ),
    );
  }

  /// `2026-10-07` -> `2026-10`，用作按月的键。
  String _monthKey(String date) =>
      date.length >= 7 ? date.substring(0, 7) : date;

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

/// 摊平后的一行：要么是月份标题，要么是一条训练记录。
class _HistoryRow {
  const _HistoryRow._({this.monthLabel, this.monthCount, this.record, this.date});

  factory _HistoryRow.month(String label, int count) =>
      _HistoryRow._(monthLabel: label, monthCount: count);

  factory _HistoryRow.record(SessionRecord record, DateTime date) =>
      _HistoryRow._(record: record, date: date);

  final String? monthLabel;
  final int? monthCount;
  final SessionRecord? record;
  final DateTime? date;
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
