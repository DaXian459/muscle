import 'package:flutter/foundation.dart';

import '../models/exercise_item.dart';
import '../models/session_record.dart';
import '../models/weekly_plan.dart';
import '../utils/dates.dart';
import 'app_repository.dart';

/// 全应用唯一的状态来源：持有周计划模板与全部训练记录，并把改动写回本地。
class AppStore extends ChangeNotifier {
  AppStore(this._repository)
      : _plan = _repository.loadPlan(),
        _sessions = _repository.loadSessions();

  final AppRepository _repository;
  WeeklyPlan _plan;
  final Map<String, SessionRecord> _sessions;

  WeeklyPlan get plan => _plan;

  /// 周一 ~ 周日各安排了哪些器械。
  List<ExerciseItem> planFor(int weekday) => _plan.itemsFor(weekday);

  /// 某一天是否已经产生过训练记录（而不是仅仅从模板读出来的待办）。
  bool hasRecord(DateTime date) => _sessions.containsKey(dateKey(date));

  /// 取出某一天的训练记录。
  ///
  /// 今天和以后：没有记录时按当天是星期几从周计划生成待办清单，用户真正操作
  /// （打卡 / 增删）时才落盘。
  ///
  /// 过去的日期：**不套用周计划**。周计划是往前看的模板，今天往计划里加的器械
  /// 不该凭空出现在上个月某一天；历史日期只有真正记录过才有内容。想照着计划
  /// 补记，用 [syncWithPlan]（界面上是「按周计划补记」）。
  SessionRecord sessionFor(DateTime date) {
    final key = dateKey(date);
    final stored = _sessions[key];
    if (stored != null) return stored;
    if (date.isBefore(today())) {
      return SessionRecord(date: key, items: const <SessionItem>[]);
    }
    return SessionRecord(
      date: key,
      items: _plan
          .itemsFor(date.weekday)
          .map((item) => SessionItem(item: item, fromPlan: true))
          .toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // 周计划
  // ---------------------------------------------------------------------------

  Future<void> addPlanItem(int weekday, ExerciseItem item) {
    final items = [..._plan.itemsFor(weekday), item];
    return _updatePlan(_plan.copyWithDay(weekday, items));
  }

  Future<void> updatePlanItem(int weekday, ExerciseItem item) {
    final items = _plan
        .itemsFor(weekday)
        .map((existing) => existing.id == item.id ? item : existing)
        .toList();
    return _updatePlan(_plan.copyWithDay(weekday, items));
  }

  Future<void> removePlanItem(int weekday, String itemId) {
    final items = _plan
        .itemsFor(weekday)
        .where((existing) => existing.id != itemId)
        .toList();
    return _updatePlan(_plan.copyWithDay(weekday, items));
  }

  Future<void> clearPlanDay(int weekday) =>
      _updatePlan(_plan.copyWithDay(weekday, const <ExerciseItem>[]));

  /// 把某一天的安排复制到另外几天，用于快速铺开一周的计划。
  Future<void> copyPlanDay(int fromWeekday, int toWeekday) {
    final source = _plan.itemsFor(fromWeekday);
    final copies = source
        .map((item) => ExerciseItem(
              id: item.id,
              name: item.name,
              sets: item.sets,
              reps: item.reps,
              weight: item.weight,
              note: item.note,
            ))
        .toList();
    return _updatePlan(_plan.copyWithDay(toWeekday, copies));
  }

  /// 把从剪贴板导入的计划并进周计划。
  ///
  /// [replace] 为 true 时整份替换（导入内容里没有的星期会被清空），
  /// 否则追加到对应星期后面，适合「别人的计划里只有周五，我加到自己周五」这种用法。
  Future<void> applyImportedPlan(
    Map<int, List<ExerciseItem>> days, {
    required bool replace,
  }) {
    var next = replace ? WeeklyPlan() : _plan;
    for (final entry in days.entries) {
      if (entry.value.isEmpty) continue;
      final existing =
          replace ? const <ExerciseItem>[] : next.itemsFor(entry.key);
      next = next.copyWithDay(
        entry.key,
        <ExerciseItem>[...existing, ...entry.value],
      );
    }
    return _updatePlan(next);
  }

  Future<void> _updatePlan(WeeklyPlan next) async {
    final changedWeekdays = _changedWeekdays(_plan, next);
    _plan = next;
    final sessionsChanged = _syncUpcomingSessions(changedWeekdays);
    notifyListeners();
    await _repository.savePlan(next);
    if (sessionsChanged) {
      await _repository.saveSessions(_sessions);
    }
  }

  /// 这次改动影响到了星期几，用于只刷新相关的那些天。
  Set<int> _changedWeekdays(WeeklyPlan before, WeeklyPlan after) {
    final changed = <int>{};
    for (var weekday = 1; weekday <= 7; weekday++) {
      final oldItems = before.itemsFor(weekday);
      final newItems = after.itemsFor(weekday);
      if (oldItems.length != newItems.length) {
        changed.add(weekday);
        continue;
      }
      for (var index = 0; index < oldItems.length; index++) {
        if (oldItems[index] != newItems[index]) {
          changed.add(weekday);
          break;
        }
      }
    }
    return changed;
  }

  /// 计划改动后，把**今天及以后**已经产生过记录的日子重新对齐。
  ///
  /// 过去的日期不动：历史必须是当时练了什么就是什么，
  /// 不能因为后来调整了周计划就跟着变形。
  bool _syncUpcomingSessions(Set<int> weekdays) {
    if (weekdays.isEmpty) return false;
    final base = today();
    var changed = false;
    for (final key in _sessions.keys.toList()) {
      final date = parseDateKey(key);
      if (date == null || date.isBefore(base)) continue;
      if (!weekdays.contains(date.weekday)) continue;
      final record = _sessions[key]!;
      final merged = _mergePlanInto(record, date.weekday);
      if (!_sameItems(record.items, merged)) {
        _sessions[key] = record.copyWith(items: merged);
        changed = true;
      }
    }
    return changed;
  }

  /// 以周计划为准重建当天清单：
  /// 计划内的器械按计划顺序排在前面，组数 / 重量等改动会同步过来，已完成状态保留；
  /// 当天临时添加的器械保留；已经打过卡、之后又被移出计划的器械也保留，避免丢掉记录。
  List<SessionItem> _mergePlanInto(SessionRecord record, int weekday) {
    final planned = _plan.itemsFor(weekday);
    final plannedIds = planned.map((item) => item.id).toSet();
    final stored = <String, SessionItem>{
      for (final entry in record.items) entry.id: entry,
    };
    return <SessionItem>[
      for (final item in planned)
        stored[item.id]?.copyWith(item: item) ??
            SessionItem(item: item, fromPlan: true),
      for (final entry in record.items)
        if (!plannedIds.contains(entry.id) &&
            (!entry.fromPlan || entry.completed))
          entry,
    ];
  }

  bool _sameItems(List<SessionItem> a, List<SessionItem> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index].id != b[index].id ||
          a[index].completed != b[index].completed ||
          a[index].completedAt != b[index].completedAt ||
          a[index].fromPlan != b[index].fromPlan ||
          a[index].item != b[index].item) {
        return false;
      }
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // 当天训练记录
  // ---------------------------------------------------------------------------

  /// 切换某一台器械的完成状态。
  Future<void> toggleItem(DateTime date, String itemId) {
    final record = sessionFor(date);
    final items = record.items.map((entry) {
      if (entry.id != itemId) return entry;
      final completed = !entry.completed;
      return entry.copyWith(
        completed: completed,
        completedAt: completed ? DateTime.now().toIso8601String() : null,
        clearCompletedAt: !completed,
      );
    }).toList();
    return _saveSession(record.copyWith(items: items));
  }

  /// 一键全选 / 取消全选。
  Future<void> setAllCompleted(DateTime date, bool completed) {
    final record = sessionFor(date);
    final timestamp = completed ? DateTime.now().toIso8601String() : null;
    final items = record.items
        .map((entry) => entry.copyWith(
              completed: completed,
              completedAt: timestamp,
              clearCompletedAt: !completed,
            ))
        .toList();
    return _saveSession(record.copyWith(items: items));
  }

  Future<void> addSessionItem(
    DateTime date,
    ExerciseItem item, {
    bool completed = false,
  }) {
    final record = sessionFor(date);
    final items = [
      ...record.items,
      SessionItem(
        item: item,
        completed: completed,
        completedAt: completed ? DateTime.now().toIso8601String() : null,
        fromPlan: false,
      ),
    ];
    return _saveSession(record.copyWith(items: items));
  }

  Future<void> updateSessionItem(DateTime date, ExerciseItem item) {
    final record = sessionFor(date);
    final items = record.items
        .map((entry) => entry.id == item.id ? entry.copyWith(item: item) : entry)
        .toList();
    return _saveSession(record.copyWith(items: items));
  }

  Future<void> removeSessionItem(DateTime date, String itemId) {
    final record = sessionFor(date);
    final items =
        record.items.where((entry) => entry.id != itemId).toList();
    return _saveSession(record.copyWith(items: items));
  }

  /// 把周计划里新加、但当天记录里还没有的器械补进来（不影响已有的完成状态）。
  Future<void> syncWithPlan(DateTime date) {
    final record = sessionFor(date);
    final known = record.items.map((entry) => entry.id).toSet();
    final additions = _plan
        .itemsFor(date.weekday)
        .where((item) => !known.contains(item.id))
        .map((item) => SessionItem(item: item, fromPlan: true));
    final items = [...record.items, ...additions];
    if (items.length == record.items.length) return Future<void>.value();
    return _saveSession(record.copyWith(items: items));
  }

  /// 删除某一天的全部记录（历史里清除这一天）。
  Future<void> deleteSession(DateTime date) {
    final key = dateKey(date);
    if (_sessions.remove(key) == null) return Future<void>.value();
    notifyListeners();
    return _repository.saveSessions(_sessions);
  }

  Future<void> _saveSession(SessionRecord record) {
    // 即使一条不剩也保留这一天：否则清单会立刻按周计划重新长出来，
    // 「删掉今天不想练的」就永远生效不了。历史列表本身会跳过空记录。
    _sessions[record.date] = record;
    notifyListeners();
    return _repository.saveSessions(_sessions);
  }

  // ---------------------------------------------------------------------------
  // 历史与统计
  // ---------------------------------------------------------------------------

  /// 历史训练记录，按日期倒序（只包含真正产生过记录的日子）。
  List<SessionRecord> get history {
    final records = _sessions.values
        .where((record) => record.items.isNotEmpty)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  /// 某一天有没有已完成的器械。
  bool hasCompletedOn(DateTime date) =>
      (_sessions[dateKey(date)]?.completedCount ?? 0) > 0;

  /// 完成过训练的累计天数。
  int get trainingDayCount =>
      _sessions.values.where((record) => record.completedCount > 0).length;

  /// 累计完成的器械次数。
  int get completedItemCount =>
      _sessions.values.fold(0, (sum, record) => sum + record.completedCount);

  /// 累计登记过的器械次数（含未完成）。
  int get loggedItemCount =>
      _sessions.values.fold(0, (sum, record) => sum + record.total);

  /// 连续打卡天数；今天还没练时从昨天往前数。
  int get currentStreak {
    var cursor = today();
    if (!hasCompletedOn(cursor)) {
      cursor = addDays(cursor, -1);
    }
    var streak = 0;
    while (hasCompletedOn(cursor)) {
      streak++;
      cursor = addDays(cursor, -1);
    }
    return streak;
  }

  /// 某一天所在这一周内，已经完成的器械次数。
  int completedInWeek(DateTime anchor) => weekDates(anchor)
      .fold(0, (sum, day) => sum + (_sessions[dateKey(day)]?.completedCount ?? 0));
}
