/// 日期与星期相关的格式化工具，统一使用“周一 ~ 周日”的中文表述。
const List<String> kWeekdayNames = <String>[
  '周一',
  '周二',
  '周三',
  '周四',
  '周五',
  '周六',
  '周日',
];

/// 1 = 周一 ... 7 = 周日，与 [DateTime.weekday] 保持一致。
String weekdayName(int weekday) => kWeekdayNames[(weekday - 1).clamp(0, 6)];

/// 把任意时间点抹成当天零点，方便做“按天”比较。
DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

/// 仅测试用：把「现在」固定成某个时间点。
///
/// 跨天刷新的逻辑必须能验证（后台过夜再回来要跳到新的一天），
/// 而真实时钟没法在测试里拨动，所以留这个入口。
/// 测试结束务必置回 null。
DateTime? debugNowOverride;

/// 当前时间，测试里可被 [debugNowOverride] 替换。
DateTime currentTime() => debugNowOverride ?? DateTime.now();

DateTime today() => dateOnly(currentTime());

/// 用 [DateTime] 自带的字段溢出规则做加法，天然避开夏令时带来的 23/25 小时问题。
DateTime addDays(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);

/// 持久化用的日期字符串，形如 `2026-10-07`，可直接按字典序排序。
String dateKey(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime? parseDateKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

String formatFullDate(DateTime value) =>
    '${value.year}年${value.month}月${value.day}日';

String formatMonth(DateTime value) => '${value.year}年${value.month}月';

String formatShortDate(DateTime value) => '${value.month}/${value.day}';

/// 相对今天的口语化描述：今天 / 昨天 / 前天 / 明天 / 后天，其余回退到星期。
String describeDay(DateTime value, {DateTime? now}) {
  final base = dateOnly(now ?? DateTime.now());
  final diff = dateOnly(value).difference(base).inDays;
  switch (diff) {
    case -2:
      return '前天';
    case -1:
      return '昨天';
    case 0:
      return '今天';
    case 1:
      return '明天';
    case 2:
      return '后天';
  }
  return weekdayName(value.weekday);
}

/// 周一作为一周的起点。
DateTime startOfWeek(DateTime value) {
  final day = dateOnly(value);
  return DateTime(day.year, day.month, day.day - (day.weekday - 1));
}

List<DateTime> weekDates(DateTime value) {
  final start = startOfWeek(value);
  return List<DateTime>.generate(7, (index) => addDays(start, index));
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
