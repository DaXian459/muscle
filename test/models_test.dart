import 'package:flutter_test/flutter_test.dart';
import 'package:muscle/models/exercise_item.dart';
import 'package:muscle/models/session_record.dart';
import 'package:muscle/models/weekly_plan.dart';
import 'package:muscle/utils/dates.dart';

void main() {
  group('ExerciseItem', () {
    test('摘要包含组数、次数与重量', () {
      const item = ExerciseItem(
        id: 'a',
        name: '高位下拉',
        sets: 4,
        reps: 10,
        weight: 45,
      );
      expect(item.summary, '4 组 × 10 次 · 45 kg');
    });

    test('自重训练不显示重量', () {
      const item = ExerciseItem(id: 'b', name: '引体向上', sets: 4, reps: 8);
      expect(item.summary, '4 组 × 8 次');
    });

    test('重量支持小数并去掉多余的 0', () {
      const item = ExerciseItem(
        id: 'c',
        name: '哑铃弯举',
        sets: 3,
        reps: 12,
        weight: 12.5,
      );
      expect(item.summary, '3 组 × 12 次 · 12.5 kg');
      expect(formatWeight(20), '20');
    });

    test('JSON 往返保持内容一致', () {
      const original = ExerciseItem(
        id: 'd',
        name: '腿举机',
        sets: 5,
        reps: 8,
        weight: 120,
        note: '座位第 3 档',
      );
      final restored = ExerciseItem.fromJson(original.toJson());
      expect(restored, original);
      expect(restored.note, '座位第 3 档');
    });

    test('copyWith 可以清空重量', () {
      const original = ExerciseItem(id: 'e', name: '深蹲', weight: 60);
      expect(original.copyWith(clearWeight: true).weight, isNull);
      expect(original.copyWith(sets: 6).weight, 60);
    });
  });

  group('WeeklyPlan', () {
    test('未安排的星期返回空列表而不是 null', () {
      final plan = WeeklyPlan();
      for (var weekday = 1; weekday <= 7; weekday++) {
        expect(plan.itemsFor(weekday), isEmpty);
        expect(plan.isRestDay(weekday), isTrue);
      }
    });

    test('统计动作数与训练天数', () {
      final plan = WeeklyPlan(<int, List<ExerciseItem>>{
        1: const <ExerciseItem>[
          ExerciseItem(id: '1', name: '卧推'),
          ExerciseItem(id: '2', name: '高位下拉'),
        ],
        3: const <ExerciseItem>[ExerciseItem(id: '3', name: '深蹲')],
      });
      expect(plan.totalItems, 3);
      expect(plan.trainingDayCount, 2);
      expect(plan.isRestDay(2), isTrue);
    });

    test('JSON 往返只保留 1~7 的星期', () {
      final plan = WeeklyPlan(<int, List<ExerciseItem>>{
        2: const <ExerciseItem>[ExerciseItem(id: 'x', name: '划船机')],
      });
      final restored = WeeklyPlan.fromJson(plan.toJson());
      expect(restored.itemsFor(2).single.name, '划船机');
      expect(restored.itemsFor(1), isEmpty);
    });
  });

  group('SessionRecord', () {
    test('统计完成进度', () {
      final record = SessionRecord(
        date: '2026-10-07',
        items: const <SessionItem>[
          SessionItem(item: ExerciseItem(id: 'a', name: 'A'), completed: true),
          SessionItem(item: ExerciseItem(id: 'b', name: 'B')),
          SessionItem(item: ExerciseItem(id: 'c', name: 'C'), completed: true),
        ],
      );
      expect(record.total, 3);
      expect(record.completedCount, 2);
      expect(record.progress, closeTo(2 / 3, 0.0001));
      expect(record.allCompleted, isFalse);
    });

    test('空记录不算全部完成', () {
      final record = SessionRecord(date: '2026-10-07', items: const <SessionItem>[]);
      expect(record.isEmpty, isTrue);
      expect(record.allCompleted, isFalse);
      expect(record.progress, 0);
    });

    test('JSON 往返保留完成状态与来源', () {
      final record = SessionRecord(
        date: '2026-10-07',
        items: <SessionItem>[
          SessionItem(
            item: const ExerciseItem(id: 'a', name: '卧推', weight: 60),
            completed: true,
            completedAt: '2026-10-07T20:00:00.000',
            fromPlan: true,
          ),
        ],
      );
      final restored = SessionRecord.fromJson(record.toJson());
      expect(restored.date, '2026-10-07');
      expect(restored.items.single.completed, isTrue);
      expect(restored.items.single.completedAt, '2026-10-07T20:00:00.000');
      expect(restored.items.single.fromPlan, isTrue);
      expect(restored.items.single.weight, 60);
    });
  });

  group('日期工具', () {
    test('星期名称', () {
      expect(weekdayName(1), '周一');
      expect(weekdayName(7), '周日');
    });

    test('日期键可以互相转换', () {
      expect(dateKey(DateTime(2026, 10, 7)), '2026-10-07');
      expect(parseDateKey('2026-10-07'), DateTime(2026, 10, 7));
      expect(parseDateKey('乱七八糟'), isNull);
    });

    test('一周从周一开始', () {
      // 2026-10-07 是星期三
      final start = startOfWeek(DateTime(2026, 10, 7));
      expect(start, DateTime(2026, 10, 5));
      expect(start.weekday, DateTime.monday);
      expect(weekDates(DateTime(2026, 10, 7)).last, DateTime(2026, 10, 11));
    });

    test('跨月加减天数', () {
      expect(addDays(DateTime(2026, 10, 31), 1), DateTime(2026, 11, 1));
      expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    });

    test('相对日期描述', () {
      final now = DateTime(2026, 10, 7);
      expect(describeDay(DateTime(2026, 10, 7), now: now), '今天');
      expect(describeDay(DateTime(2026, 10, 6), now: now), '昨天');
      expect(describeDay(DateTime(2026, 10, 4), now: now), '周日');
    });
  });
}
