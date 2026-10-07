import 'dart:convert';

import '../models/exercise_item.dart';
import '../models/weekly_plan.dart';
import 'dates.dart';
import 'ids.dart';

/// 一次导入的解析结果。
class PlanImportResult {
  const PlanImportResult({
    required this.days,
    required this.unreadable,
    required this.degraded,
  });

  /// 星期（1~7，与 [DateTime.weekday] 一致）-> 解析出来的动作。
  final Map<int, List<ExerciseItem>> days;

  /// 认不出来的行，原样回报给用户。宁可多问一句，也不静默丢人家的动作。
  final List<String> unreadable;

  /// 被降级处理的条数（次数区间、计时动作）。
  final int degraded;

  bool get isEmpty => itemCount == 0;

  int get itemCount =>
      days.values.fold(0, (sum, items) => sum + items.length);

  /// 按星期升序排列的、有内容的那些天，用于预览。
  List<int> get filledWeekdays {
    final result = days.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toList()
      ..sort();
    return result;
  }
}

/// 周计划的文本编解码，用于通过剪贴板分享 / 导入训练计划。
///
/// 导出格式：
///
///     # 肌肉 · 周计划
///
///     周一
///     杠铃/哑铃卧推 3×8
///     上斜哑铃卧推 3×10 @20kg // 坐姿第 2 档
///
///     周二
///     高位下拉 3×8
///
/// 行首 `#` 是注释，空行忽略。导入比导出宽容得多：制表符、`3 组 × 8 次`、
/// `星期三`、`周3`、全角 `＠` 都认。
///
/// **次数区间会被降级**：当前数据模型每个动作只存单个次数，所以 `3 × 8-10`
/// 会记成 8 次，区间原文放进备注（界面显示「3 组 × 8 次」+「每组 8-10 次」）。
/// 计时动作 `3 × 45 秒` 同理。降级条数会在导入预览里提示，不会闷声处理。
String encodePlanText(WeeklyPlan plan) {
  final buffer = StringBuffer()
    ..writeln('# 肌肉 · 周计划')
    ..writeln('# 粘贴给用同一个 App 的人，在「周计划」页点「从剪贴板导入」即可')
    ..writeln();

  for (var weekday = 1; weekday <= 7; weekday++) {
    final items = plan.itemsFor(weekday);
    if (items.isEmpty) continue;
    buffer.writeln(weekdayName(weekday));
    for (final item in items) {
      buffer.write('${item.name} ${item.sets}×${item.reps}');
      final load = item.weight;
      if (load != null && load > 0) {
        buffer.write(' @${formatWeight(load)}kg');
      }
      if (item.note.isNotEmpty) {
        buffer.write(' // ${item.note}');
      }
      buffer.writeln();
    }
    buffer.writeln();
  }
  return '${buffer.toString().trimRight()}\n';
}

/// 解析一段周计划文本。认不出的行会收集在 [PlanImportResult.unreadable] 里。
PlanImportResult decodePlanText(String text, {String Function()? idFactory}) {
  final makeId = idFactory ?? newId;
  final days = <int, List<ExerciseItem>>{};
  final unreadable = <String>[];
  var degraded = 0;
  int? currentDay;

  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;

    final day = _matchDay(line);
    if (day != null) {
      currentDay = day;
      days.putIfAbsent(day, () => <ExerciseItem>[]);
      continue;
    }

    // 整行没有数字的多半是分组标题、说明之类，直接跳过，不算错误
    if (!_hasDigit.hasMatch(line)) continue;
    // 「动作 / 组数 × 次数」这种表头
    if (line.contains('组数') && line.contains('次数')) continue;

    final parsed = currentDay == null ? null : _parseItem(line, makeId);
    if (parsed == null) {
      unreadable.add(line);
      continue;
    }
    days[currentDay]!.add(parsed.item);
    if (parsed.degraded) degraded++;
  }

  return PlanImportResult(
    days: days,
    unreadable: unreadable,
    degraded: degraded,
  );
}

final RegExp _hasDigit = RegExp(r'\d');

final RegExp _dayPattern =
    RegExp(r'^(?:周|星期|礼拜)\s*([一二三四五六日天1-7])');

const Map<String, int> _dayNames = <String, int>{
  '一': DateTime.monday,
  '二': DateTime.tuesday,
  '三': DateTime.wednesday,
  '四': DateTime.thursday,
  '五': DateTime.friday,
  '六': DateTime.saturday,
  '日': DateTime.sunday,
  '天': DateTime.sunday,
};

/// `名称 3×8`、`名称 3 组 × 8-10 次`、`名称 3×8 @20kg // 备注`
///
/// 分组：1=名称 2=组数 3=次数 4=次数上限 5=单位(次/秒) 6=重量 7=备注
final RegExp _itemPattern = RegExp(
  r'^(.+?)[\s\u3000]*(\d+)\s*组?\s*[×xX✕*]\s*(\d+)'
  r'(?:\s*[-~～—]\s*(\d+))?'
  r'\s*(次|秒)?'
  r'(?:\s*[@＠]\s*([\d.]+)\s*(?:kg|KG|公斤)?)?'
  r'(?:\s*//\s*(.*))?'
  r'\s*$',
);

int? _matchDay(String line) {
  final match = _dayPattern.firstMatch(line);
  if (match == null) return null;
  final key = match.group(1)!;
  return _dayNames[key] ?? int.tryParse(key);
}

_ParsedItem? _parseItem(String line, String Function() makeId) {
  final match = _itemPattern.firstMatch(line);
  if (match == null) return null;

  final name = match.group(1)?.trim() ?? '';
  final sets = int.tryParse(match.group(2) ?? '');
  final reps = int.tryParse(match.group(3) ?? '');
  if (name.isEmpty || sets == null || sets <= 0 || reps == null || reps <= 0) {
    return null;
  }

  final rangeEnd = match.group(4);
  final unit = match.group(5);
  final weightText = match.group(6);
  final noteText = match.group(7)?.trim() ?? '';

  // 模型只存单个次数：区间取下限、计时按次数记，
  // 原文补进备注，保证信息不丢，界面上也能看出真实要求。
  final extras = <String>[];
  var degraded = false;
  if (rangeEnd != null) {
    extras.add('每组 $reps-$rangeEnd 次');
    degraded = true;
  } else if (unit == '秒') {
    extras.add('每组 $reps 秒');
    degraded = true;
  }
  if (noteText.isNotEmpty) extras.add(noteText);

  return _ParsedItem(
    ExerciseItem(
      id: makeId(),
      name: name,
      sets: sets,
      reps: reps,
      weight: weightText == null ? null : double.tryParse(weightText),
      note: extras.join('；'),
    ),
    degraded,
  );
}

class _ParsedItem {
  const _ParsedItem(this.item, this.degraded);

  final ExerciseItem item;
  final bool degraded;
}
