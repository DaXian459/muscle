import 'exercise_item.dart';

/// 以星期为单位的训练计划模板，1 = 周一 ... 7 = 周日，与 [DateTime.weekday] 对齐。
///
/// 模板本身不带日期，[AppStore] 会根据某一天是星期几，把对应的器械清单
/// 复制成当天的训练记录，因此计划只需要维护一份。
class WeeklyPlan {
  WeeklyPlan([Map<int, List<ExerciseItem>>? days]) : _days = _normalize(days);

  static Map<int, List<ExerciseItem>> _normalize(
    Map<int, List<ExerciseItem>>? days,
  ) {
    final result = <int, List<ExerciseItem>>{};
    for (var weekday = 1; weekday <= 7; weekday++) {
      result[weekday] =
          List<ExerciseItem>.unmodifiable(days?[weekday] ?? const <ExerciseItem>[]);
    }
    return result;
  }

  final Map<int, List<ExerciseItem>> _days;

  List<ExerciseItem> itemsFor(int weekday) =>
      _days[weekday] ?? const <ExerciseItem>[];

  bool isRestDay(int weekday) => itemsFor(weekday).isEmpty;

  /// 一周内安排的器械动作总数。
  int get totalItems =>
      _days.values.fold(0, (sum, items) => sum + items.length);

  /// 一周内有安排的天数。
  int get trainingDayCount =>
      _days.values.where((items) => items.isNotEmpty).length;

  WeeklyPlan copyWithDay(int weekday, List<ExerciseItem> items) {
    final next = Map<int, List<ExerciseItem>>.from(_days);
    next[weekday] = List<ExerciseItem>.from(items);
    return WeeklyPlan(next);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'days': _days.map(
          (weekday, items) =>
              MapEntry(weekday.toString(), items.map((e) => e.toJson()).toList()),
        ),
      };

  static WeeklyPlan fromJson(Map<String, dynamic> json) {
    final raw =
        (json['days'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final days = <int, List<ExerciseItem>>{};
    raw.forEach((key, value) {
      final weekday = int.tryParse(key);
      if (weekday == null || weekday < 1 || weekday > 7) return;
      days[weekday] = (value as List?)
              ?.whereType<Map<Object?, Object?>>()
              .map((entry) => ExerciseItem.fromJson(entry.cast<String, dynamic>()))
              .toList() ??
          <ExerciseItem>[];
    });
    return WeeklyPlan(days);
  }
}
