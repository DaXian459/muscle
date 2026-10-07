import 'exercise_item.dart';

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
