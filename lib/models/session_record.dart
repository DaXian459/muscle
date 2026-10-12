import 'exercise_item.dart';

/// 时长写成人话：不到 1 分钟 / 52 分钟 / 1 小时 12 分钟。
String formatDuration(Duration value) {
  final minutes = value.inMinutes;
  if (minutes < 1) return '不到 1 分钟';
  if (minutes < 60) return '$minutes 分钟';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours 小时' : '$hours 小时 $rest 分钟';
}

/// 计时器上的走秒格式：`12:34` / `1:02:03`。
String formatTimer(Duration value) {
  final total = value.isNegative ? 0 : value.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

/// 训练记录中的一项器械：在计划内容之上叠加「是否已完成」。
class SessionItem {
  const SessionItem({
    required this.item,
    this.completed = false,
    this.completedAt,
    this.fromPlan = false,
  });

  final ExerciseItem item;
  final bool completed;

  /// 打卡时间（ISO8601），未完成时为 null。
  final String? completedAt;

  /// 是否来自周计划模板，用于在界面上区分「计划内」与「临时加练」。
  final bool fromPlan;

  String get id => item.id;
  String get name => item.name;
  int get sets => item.sets;
  int get reps => item.reps;
  double? get weight => item.weight;
  String get note => item.note;
  String get summary => item.summary;
  String get setsAndReps => item.setsAndReps;

  /// 「高位下拉 20kg」，历史卡片上的小标签用它，好让重量一眼可见。
  String get nameWithWeight {
    final load = weight;
    return load != null && load > 0
        ? '$name ${formatWeight(load)}kg'
        : name;
  }

  SessionItem copyWith({
    ExerciseItem? item,
    bool? completed,
    String? completedAt,
    bool clearCompletedAt = false,
    bool? fromPlan,
  }) {
    return SessionItem(
      item: item ?? this.item,
      completed: completed ?? this.completed,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      fromPlan: fromPlan ?? this.fromPlan,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'item': item.toJson(),
        'completed': completed,
        'completedAt': completedAt,
        'fromPlan': fromPlan,
      };

  static SessionItem fromJson(Map<String, dynamic> json) => SessionItem(
        item: ExerciseItem.fromJson(
          (json['item'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
        completed: json['completed'] as bool? ?? false,
        completedAt: json['completedAt'] as String?,
        fromPlan: json['fromPlan'] as bool? ?? false,
      );
}

/// 某一天完整的器械训练记录。
class SessionRecord {
  SessionRecord({
    required this.date,
    required List<SessionItem> items,
    this.startedAt,
    this.elapsedSeconds = 0,
    this.runningSince,
    this.finishedAt,
  }) : items = List<SessionItem>.unmodifiable(items);

  /// 形如 `2026-10-07`。
  final String date;
  final List<SessionItem> items;

  // --- 手动计时 ---

  /// 第一次点「开始训练」的时刻（ISO8601）。没开过计时器时为 null。
  final String? startedAt;

  /// 已经累计的训练秒数，**不含** [runningSince] 之后正在跑的那一段。
  ///
  /// 拆成「累计」+「当前段起点」两截是为了支持暂停：暂停时把当前段并进累计，
  /// 继续时只换一个段起点，不用回头改历史。界面上的实时时长 = 两者相加。
  final int elapsedSeconds;

  /// 当前这一段的起点；null 表示没在跑（没开始过 / 已暂停 / 已结束）。
  final String? runningSince;

  /// 点「结束训练」的时刻。
  final String? finishedAt;

  bool get isRunning => runningSince != null;

  bool get isPaused =>
      startedAt != null && runningSince == null && finishedAt == null;

  bool get isFinished => finishedAt != null;

  /// 是否手动计过时。计过就以计时为准，否则退回打卡推算。
  bool get hasTimer => startedAt != null;

  DateTime? get startedTime => _parseTime(startedAt);
  DateTime? get runningSinceTime => _parseTime(runningSince);
  DateTime? get finishedTime => _parseTime(finishedAt);

  static DateTime? _parseTime(String? value) =>
      value == null ? null : DateTime.tryParse(value);

  bool get isEmpty => items.isEmpty;
  int get total => items.length;
  int get completedCount => items.where((entry) => entry.completed).length;
  bool get allCompleted => items.isNotEmpty && completedCount == total;
  double get progress => items.isEmpty ? 0 : completedCount / total;

  /// 这一天所有打卡时刻，已按时间排好序。
  List<DateTime> get tickTimes {
    final times = items
        .map((entry) => entry.completedAt)
        .whereType<String>()
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .toList()
      ..sort();
    return times;
  }

  /// 第一次打卡的时刻。
  DateTime? get firstTickAt {
    final times = tickTimes;
    return times.isEmpty ? null : times.first;
  }

  /// 最后一次打卡的时刻。只有一个打卡点时不给出（算不出跨度）。
  DateTime? get lastTickAt {
    final times = tickTimes;
    return times.length >= 2 ? times.last : null;
  }

  /// 用打卡首尾推算的时长（没开计时器时的兜底）。
  ///
  /// 打卡不足两次、或时间没往前走时为 null —— 显示「用时 0 分钟」比不显示更糟。
  Duration? get tickDuration {
    final times = tickTimes;
    if (times.length < 2) return null;
    final span = times.last.difference(times.first);
    return span > Duration.zero ? span : null;
  }

  /// 本次训练时长。开了计时器就以计时为准，否则用打卡推算。
  ///
  /// [now] 传了才把「正在跑的这一段」算进去。**只有今天该传** ——
  /// 一个忘了关的计时器跨天后会累出好几天，那种情况只能算已累计的部分。
  Duration? duration({DateTime? now}) {
    if (!hasTimer) return tickDuration;

    final accumulated = Duration(seconds: elapsedSeconds);
    final since = runningSinceTime;
    if (now == null || since == null) return accumulated;

    final segment = now.difference(since);
    return segment > Duration.zero ? accumulated + segment : accumulated;
  }

  SessionRecord copyWith({
    List<SessionItem>? items,
    String? startedAt,
    int? elapsedSeconds,
    String? runningSince,
    bool clearRunningSince = false,
    String? finishedAt,
    /// 把计时相关的字段整段清掉（重新计时用）。
    bool clearTimer = false,
  }) {
    if (clearTimer) {
      return SessionRecord(date: date, items: items ?? this.items);
    }
    return SessionRecord(
      date: date,
      items: items ?? this.items,
      startedAt: startedAt ?? this.startedAt,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      runningSince:
          clearRunningSince ? null : (runningSince ?? this.runningSince),
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date,
        'items': items.map((entry) => entry.toJson()).toList(),
        'startedAt': startedAt,
        'elapsedSeconds': elapsedSeconds,
        'runningSince': runningSince,
        'finishedAt': finishedAt,
      };

  static SessionRecord fromJson(Map<String, dynamic> json) => SessionRecord(
        date: json['date'] as String? ?? '',
        items: (json['items'] as List?)
                ?.whereType<Map<Object?, Object?>>()
                .map((entry) =>
                    SessionItem.fromJson(entry.cast<String, dynamic>()))
                .toList() ??
            const <SessionItem>[],
        startedAt: json['startedAt'] as String?,
        elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
        runningSince: json['runningSince'] as String?,
        finishedAt: json['finishedAt'] as String?,
      );
}
