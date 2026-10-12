import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/session_record.dart';
import '../utils/dates.dart';
import '../widgets/empty_state.dart';
import '../widgets/exercise_editor_sheet.dart';
import '../widgets/exercise_tile.dart';
import '../widgets/weight_editor.dart';

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

  /// 计时中用来每秒刷新一次。
  ///
  /// 不跑的时候必须是 null：一个常驻的周期定时器会让 Widget 测试里的
  /// pumpAndSettle 永远等不到「没有待处理帧」，而且白耗电。
  Timer? _ticker;

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
    _ticker?.cancel();
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

  /// 全部完成 / 取消全选。
  ///
  /// 只有「取消」需要确认：它会把已经记下的打卡时间一并抹掉，
  /// 而训练时长正是靠这些时间推出来的 —— 点错一下半天就白打了。
  /// 「全部完成」是补齐，且随时可以再取消，不拦。
  Future<void> _toggleAll(AppStore store, SessionRecord session) async {
    final turnOn = !session.allCompleted;

    if (!turnOn) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('取消全部打卡？'),
          content: Text(
            '「${formatFullDate(_date)}」已完成的 '
            '${session.completedCount} 台器械会全部变回未完成，'
            '打卡时间也会一起清掉，本次训练时长将不再显示。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('再想想'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('取消全部打卡'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    await store.setAllCompleted(_date, turnOn);
  }

  /// 记录这一天的配重。
  ///
  /// 只改当天的记录，不动周计划 —— 重量本来就是一天一个数，
  /// 周计划里那个更像是「起始值」。
  Future<void> _editWeight(SessionItem entry) async {
    final store = context.read<AppStore>();
    final text = await showWeightEditor(
      context,
      name: entry.name,
      weight: entry.weight,
    );
    if (text == null || !mounted) return;

    final value = parseWeightInput(text);
    await store.updateSessionItem(
      _date,
      entry.item.copyWith(weight: value, clearWeight: value == null),
    );
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

    // 计时中才需要每秒刷新一次
    _syncTicker(session.isRunning && _isToday);

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
                onWeightTap: () => _editWeight(entry),
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

  /// 计时中才需要每秒刷新；暂停、结束、翻到别的日期都要停掉。
  void _syncTicker(bool shouldRun) {
    if (shouldRun && _ticker == null) {
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (mounted) setState(() {});
        },
      );
    } else if (!shouldRun && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  /// 进度卡片底下那行：时长 + 计时按钮。
  Widget _timerRow(ThemeData theme, AppStore store, SessionRecord session) {
    final scheme = theme.colorScheme;
    // 只有今天、且确实在跑，才把「正在跑的这段」算进去。
    // 别的日期上还在跑多半是忘了关，那种只能算已累计的部分。
    final live = session.isRunning && _isToday;
    final span = session.duration(now: live ? currentTime() : null);

    final IconData icon;
    final String label;
    if (session.isRunning && _isToday) {
      icon = Icons.timer_outlined;
      label = '训练中 ${formatTimer(span ?? Duration.zero)}';
    } else if (session.isPaused && _isToday) {
      icon = Icons.pause_circle_outline;
      label = '已暂停 ${formatTimer(span ?? Duration.zero)}';
    } else if (session.isFinished) {
      icon = Icons.check_circle_outline;
      label = '用时 ${formatDuration(span ?? Duration.zero)}';
    } else if (span != null) {
      icon = Icons.schedule;
      label = '本次训练 约 ${formatDuration(span)}';
    } else {
      icon = Icons.timer_outlined;
      label = '还没开始计时';
    }

    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        ..._timerButtons(store, session),
      ],
    );
  }

  List<Widget> _timerButtons(AppStore store, SessionRecord session) {
    // 过去的日期上不给按钮：那时候的训练早就结束了，
    // 现在按「开始」只会记出一个荒唐的时长。
    if (!_isToday) return const <Widget>[];

    final ButtonStyle style = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minimumSize: const Size(0, 34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    if (session.isRunning) {
      return <Widget>[
        TextButton(
          style: style,
          onPressed: () => store.pauseTraining(_date),
          child: const Text('暂停'),
        ),
        TextButton(
          style: style,
          onPressed: () => store.finishTraining(_date),
          child: const Text('结束'),
        ),
      ];
    }
    if (session.isPaused) {
      return <Widget>[
        TextButton(
          style: style,
          onPressed: () => store.resumeTraining(_date),
          child: const Text('继续'),
        ),
        TextButton(
          style: style,
          onPressed: () => store.finishTraining(_date),
          child: const Text('结束'),
        ),
      ];
    }
    if (session.isFinished) {
      return <Widget>[
        TextButton(
          style: style,
          onPressed: () => store.startTraining(_date),
          child: const Text('重新计时'),
        ),
      ];
    }
    return <Widget>[
      TextButton(
        style: style,
        onPressed: () => store.startTraining(_date),
        child: const Text('开始训练'),
      ),
    ];
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
            const SizedBox(height: 10),
            _timerRow(theme, store, session),
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
                    onPressed: () => _toggleAll(store, session),
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
