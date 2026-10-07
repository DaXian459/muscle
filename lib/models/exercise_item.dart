import 'package:flutter/foundation.dart';

/// 重量去掉多余的小数位：20.0 -> 20，22.5 -> 22.5。
String formatWeight(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

/// 一条器械训练项，既是周计划模板里的内容，也是当天训练记录的内容。
@immutable
class ExerciseItem {
  const ExerciseItem({
    required this.id,
    required this.name,
    this.sets = 3,
    this.reps = 12,
    this.weight,
    this.note = '',
  });

  final String id;

  /// 器械或动作名称，例如「高位下拉」。
  final String name;

  /// 组数。
  final int sets;

  /// 每组次数。
  final int reps;

  /// 配重（公斤），自重训练留空。
  final double? weight;

  final String note;

  ExerciseItem copyWith({
    String? name,
    int? sets,
    int? reps,
    double? weight,
    bool clearWeight = false,
    String? note,
  }) {
    return ExerciseItem(
      id: id,
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weight: clearWeight ? null : (weight ?? this.weight),
      note: note ?? this.note,
    );
  }

  /// 例如「4 组 × 10 次 · 60 kg」。
  String get summary {
    final buffer = StringBuffer('$sets 组 × $reps 次');
    final load = weight;
    if (load != null && load > 0) {
      buffer.write(' · ${formatWeight(load)} kg');
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'sets': sets,
        'reps': reps,
        'weight': weight,
        'note': note,
      };

  static ExerciseItem fromJson(Map<String, dynamic> json) => ExerciseItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        sets: (json['sets'] as num?)?.toInt() ?? 3,
        reps: (json['reps'] as num?)?.toInt() ?? 12,
        weight: (json['weight'] as num?)?.toDouble(),
        note: json['note'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is ExerciseItem &&
      other.id == id &&
      other.name == name &&
      other.sets == sets &&
      other.reps == reps &&
      other.weight == weight &&
      other.note == note;

  @override
  int get hashCode => Object.hash(id, name, sets, reps, weight, note);
}
