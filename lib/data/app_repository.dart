import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_record.dart';
import '../models/weekly_plan.dart';

/// 本地持久化：把周计划和历史记录以 JSON 字符串存进 shared_preferences。
///
/// 数据量很小（每条记录只有几行文本），换来的是全平台可用、无需额外原生依赖。
class AppRepository {
  AppRepository(this._prefs);

  static const String planKey = 'weekly_plan_v1';
  static const String sessionsKey = 'sessions_v1';

  final SharedPreferences _prefs;

  static Future<AppRepository> open() async =>
      AppRepository(await SharedPreferences.getInstance());

  WeeklyPlan loadPlan() {
    final raw = _prefs.getString(planKey);
    if (raw == null || raw.isEmpty) return WeeklyPlan();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return WeeklyPlan();
      return WeeklyPlan.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      // 数据损坏时退回空计划，避免整个应用起不来。
      return WeeklyPlan();
    }
  }

  Future<void> savePlan(WeeklyPlan plan) =>
      _prefs.setString(planKey, jsonEncode(plan.toJson()));

  Map<String, SessionRecord> loadSessions() {
    final raw = _prefs.getString(sessionsKey);
    if (raw == null || raw.isEmpty) return <String, SessionRecord>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, SessionRecord>{};
      final result = <String, SessionRecord>{};
      decoded.forEach((key, value) {
        if (value is! Map) return;
        final record = SessionRecord.fromJson(value.cast<String, dynamic>());
        if (record.date.isEmpty) return;
        result[record.date] = record;
      });
      return result;
    } catch (_) {
      return <String, SessionRecord>{};
    }
  }

  Future<void> saveSessions(Map<String, SessionRecord> sessions) {
    final payload = <String, dynamic>{
      for (final entry in sessions.entries) entry.key: entry.value.toJson(),
    };
    return _prefs.setString(sessionsKey, jsonEncode(payload));
  }
}
