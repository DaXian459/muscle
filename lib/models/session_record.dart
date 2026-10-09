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
  SessionRecord({required this.date, required List<SessionItem> items})
      : items = List<SessionItem>.unmodifiable(items);

  /// 形如 `2026-10-07`。
  final String date;
  final List<SessionItem> items;

  bool get isEmpty => items.isEmpty;
  int get total => items.length;
  int get completedCount => items.where((entry) => entry.completed).length;
  bool get allCompleted => items.isNotEmpty && completedCount == total;
  double get progress => items.isEmpty ? 0 : completedCount / total;

  /// 这一天所有打卡时刻，已按时间排好序。
  ///
  /// 训练时长与起止时间都由它推出来 —— 不额外要求用户去按「开始 / 结束」，
  /// 因为这个 App 的交互就是「练完一台点一下打勾」。
  /// 代价是：如果攒到练完才统一打勾，算出来的时长会接近 0，所以界面上标「约」。
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
  DateTime? get startedAt {
    final times = tickTimes;
    return times.isEmpty ? null : times.first;
  }

  /// 最后一次打卡的时刻。只有一个打卡点时不给出（算不出跨度）。
  DateTime? get finishedAt {
    final times = tickTimes;
    return times.length >= 2 ? times.last : null;
  }

  /// 本次训练时长。打卡不足两次、或时间没往前走时为 null，
  /// 免得显示出一个「用时 0 分钟」误导人。
  Duration? get duration {
    final times = tickTimes;
    if (times.length < 2) return null;
    final span = times.last.difference(times.first);
    return span > Duration.zero ? span : null;
  }

  SessionRecord copyWith({List<SessionItem>? items}) =>
      SessionRecord(date: date, items: items ?? this.items);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date,
        'items': items.map((entry) => entry.toJson()).toList(),
      };

  static SessionRecord fromJson(Map<String, dynamic> json) => SessionRecord(
        date: json['date'] as String? ?? '',
        items: (json['items'] as List?)
                ?.whereType<Map<Object?, Object?>>()
                .map((entry) =>
                    SessionItem.fromJson(entry.cast<String, dynamic>()))
                .toList() ??
            const <SessionItem>[],
      );
}
