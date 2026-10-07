import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/session_record.dart';
import '../utils/dates.dart';
import '../widgets/empty_state.dart';
import '../widgets/exercise_editor_sheet.dart';
import '../widgets/exercise_tile.dart';

/// 今日训练：查看某一天的器械清单并逐个打卡。
class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> with WidgetsBindingObserver {
  DateTime _date = today();

  /// 页面是不是「跟着今天走」。
  ///
  /// 用前后箭头翻到别的日期后就不再跟了：这时即使跨了天，也该停在用户
  /// 正在看的那一天，不能把他眼前的记录顶掉。
  bool _pinnedToToday = true;

  bool get _isToday => isSameDay(_date, today());

  /// 过去的日期不套用周计划，只有真正记录过才有清单。
  bool get _isPast => _date.isBefore(today());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    // App 在后台过了夜再回来时，_date 还停在昨天，这里把它拉回今天。
    // 顺带 setState 一次，让「今天 / 昨天」这类相对日期描述也刷新。
    setState(() {
      if (_pinnedToToday) _date = today();
    });
  }

  void _shiftDay(int days) => setState(() {
        _date = addDays(_date, days);
        _pinnedToToday = isSameDay(_date, today());
      });

  void _backToToday() => setState(() {
        _date = today();
        _pinnedToToday = true;
      });

  Future<void> _addItem() async {
    final result = await showExerciseEditor(
      context,
      title: '添加器械 · ${weekdayName(_date.weekday)}',
    );
    if (!mounted || result == null || result.item == null) return;
    await context.read<AppStore>().addSessionItem(_date, result.item!);
  }

  Future<void> _editItem(SessionItem entry) async {
    final result = await showExerciseEditor(
      context,
      initial: entry.item,
      title: '编辑器械',
    );
    if (!mounted || result == null) return;
    final store = context.read<AppStore>();
    if (result.deleted) {
      await store.removeSessionItem(_date, entry.id);
    } else if (result.item != null) {
      await store.updateSessionItem(_date, result.item!);
    }
  }

  Future<void> _removeItem(SessionItem entry) async {
    final store = context.read<AppStore>();
    final date = _date;
    await store.removeSessionItem(date, entry.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已移除「${entry.name}」'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => store.addSessionItem(
            date,
            entry.item,
            completed: entry.completed,
          ),
        ),
      ),
    );
  }

  Future<void> _loadPlan() async {
    final store = context.read<AppStore>();
    final before = store.sessionFor(_date).total;
    await store.syncWithPlan(_date);
    if (!mounted) return;
    final added = store.sessionFor(_date).total - before;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added > 0 ? '已按周计划补齐 $added 台器械' : '周计划里没有可补充的器械',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<AppStore>();
    final session = store.sessionFor(_date);
    final plannedToday = store.planFor(_date.weekday);

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日训练'),
        actions: <Widget>[
          IconButton(
            tooltip: '载入周计划',
            onPressed: _loadPlan,
            icon: const Icon(Icons.playlist_add_check),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-today',
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('添加器械'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: <Widget>[
          _dateCard(theme),
          const SizedBox(height: 12),
          _progressCard(theme, store, session),
          const SizedBox(height: 8),
          if (session.items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.fitness_center,
                title: _isPast
                    ? '这一天没有训练记录'
                    : (plannedToday.isEmpty
                        ? '${weekdayName(_date.weekday)}没有安排训练'
                        : '这一天的清单已清空'),
                message: _isPast
                    ? '历史日期不会套用现在的周计划，只有当时记过的才会留在这里。'
                        '要补记这一天的训练，可以手动添加，或者照周计划补一份清单。'
                    : (plannedToday.isEmpty
                        ? '可以在这里添加今天用到的器械，也可以去「周计划」把每个星期固定下来。'
                        : '周计划里还安排着 ${plannedToday.length} 台器械，点右上角可以按计划重新补齐。'),
                action: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    if (plannedToday.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: _loadPlan,
                        icon: const Icon(Icons.playlist_add_check),
                        label: Text(_isPast ? '按周计划补记' : '按计划补齐'),
                      ),
                    FilledButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      label: const Text('添加器械'),
                    ),
                  ],
                ),
              ),
            )
          else ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(
                '训练清单 · ${session.completedCount}/${session.total}',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            for (final entry in session.items)
              ExerciseCheckTile(
                key: ValueKey<String>(entry.id),
                entry: entry,
                onToggle: () => store.toggleItem(_date, entry.id),
                onEdit: () => _editItem(entry),
                onDelete: () => _removeItem(entry),
              ),
          ],
        ],
      ),
    );
  }

  Widget _dateCard(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: '前一天',
                  onPressed: () => _shiftDay(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Text(
                        formatFullDate(_date),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${describeDay(_date)} · ${weekdayName(_date.weekday)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '后一天',
                  onPressed: () => _shiftDay(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (!_isToday)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: TextButton.icon(
                  onPressed: _backToToday,
                  icon: const Icon(Icons.today, size: 18),
                  label: const Text('回到今天'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _progressCard(ThemeData theme, AppStore store, SessionRecord session) {
    final scheme = theme.colorScheme;
    final total = session.total;
    final done = session.completedCount;

    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    total == 0 ? '暂无安排' : '已完成 $done / $total 台器械',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (total > 0)
                  Text(
                    '${(session.progress * 100).round()}%',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: scheme.primary),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: session.progress,
                minHeight: 8,
                backgroundColor: scheme.surface.withValues(alpha: 0.7),
              ),
            ),
            if (total > 0) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      session.allCompleted ? '这一天的训练已全部完成 🎉' : '练完一项就点一下打勾',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  TextButton(
                    onPressed: () => store.setAllCompleted(
                      _date,
                      !session.allCompleted,
                    ),
                    child: Text(session.allCompleted ? '取消全选' : '全部完成'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
