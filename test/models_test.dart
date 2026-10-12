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

  group('训练时长', () {
    SessionRecord recordWith(List<String?> stamps) => SessionRecord(
          date: '2026-10-07',
          items: <SessionItem>[
            for (var i = 0; i < stamps.length; i++)
              SessionItem(
                item: ExerciseItem(id: 'i$i', name: '动作$i'),
                completed: stamps[i] != null,
                completedAt: stamps[i],
              ),
          ],
        );

    test('打卡不足两次时算不出时长', () {
      expect(recordWith(<String?>[]).duration(), isNull);
      expect(recordWith(<String?>[null, null]).duration(), isNull);
      // 只打了一次卡：一个点算不出跨度，不显示「用时 0 分钟」误导人
      expect(recordWith(<String?>['2026-10-07T18:30:00']).duration(), isNull);
      expect(recordWith(<String?>['2026-10-07T18:30:00']).firstTickAt,
          DateTime(2026, 10, 7, 18, 30));
    });

    test('用首尾打卡时间算时长，与录入先后无关', () {
      final record = recordWith(<String?>[
        '2026-10-07T19:22:00',
        '2026-10-07T18:30:00',
        '2026-10-07T18:55:00',
      ]);
      expect(record.duration(), const Duration(minutes: 52));
      expect(record.firstTickAt, DateTime(2026, 10, 7, 18, 30));
      expect(record.lastTickAt, DateTime(2026, 10, 7, 19, 22));
    });

    test('时间戳有问题时当作算不出来，而不是给出负数或 0', () {
      expect(
        recordWith(<String?>['2026-10-07T18:30:00', '2026-10-07T18:30:00'])
            .duration(),
        isNull,
      );
      expect(
        recordWith(<String?>['2026-10-07T19:00:00', '不是时间']).duration(),
        isNull,
      );
    });

    test('时长文案', () {
      expect(formatDuration(const Duration(seconds: 40)), '不到 1 分钟');
      expect(formatDuration(const Duration(minutes: 1)), '1 分钟');
      expect(formatDuration(const Duration(minutes: 52)), '52 分钟');
      expect(formatDuration(const Duration(hours: 1)), '1 小时');
      expect(
        formatDuration(const Duration(hours: 1, minutes: 12)),
        '1 小时 12 分钟',
      );
      expect(formatDuration(const Duration(hours: 2, minutes: 5)), '2 小时 5 分钟');
    });

    test('计时器走秒的格式', () {
      expect(formatTimer(const Duration(seconds: 9)), '00:09');
      expect(formatTimer(const Duration(minutes: 12, seconds: 34)), '12:34');
      expect(formatTimer(const Duration(hours: 1, minutes: 2, seconds: 3)),
          '1:02:03');
      // 负数不该出现，真出现也要显示成 0 而不是 -1:-1
      expect(formatTimer(const Duration(seconds: -5)), '00:00');
    });
  });

  group('手动计时', () {
    SessionRecord timed({
      String? startedAt,
      int elapsedSeconds = 0,
      String? runningSince,
      String? finishedAt,
    }) =>
        SessionRecord(
          date: '2026-10-07',
          items: const <SessionItem>[],
          startedAt: startedAt,
          elapsedSeconds: elapsedSeconds,
          runningSince: runningSince,
          finishedAt: finishedAt,
        );

    test('没开过计时器就不算数，改用打卡推算', () {
      final record = timed();
      expect(record.hasTimer, isFalse);
      expect(record.isRunning, isFalse);
      expect(record.duration(), isNull);
    });

    test('跑着的时候，传了 now 才算上当前这一段', () {
      final record = timed(
        startedAt: '2026-10-07T18:30:00',
        elapsedSeconds: 600,
        runningSince: '2026-10-07T19:00:00',
      );
      expect(record.isRunning, isTrue);
      expect(
        record.duration(now: DateTime(2026, 10, 7, 19, 5)),
        const Duration(minutes: 15),
      );
      // 不传 now（比如看的是历史）就只算已累计的那部分
      expect(record.duration(), const Duration(minutes: 10));
    });

    test('忘了关的计时器不会累出好几天', () {
      // 三天前开始、一直没停
      final record = timed(
        startedAt: '2026-10-04T18:00:00',
        runningSince: '2026-10-04T18:00:00',
      );
      // 看历史时不传 now，就不会把跑着的这三天算进去
      expect(record.duration(), Duration.zero);
    });

    test('暂停后再继续，累计时长不会丢', () {
      final paused = timed(
        startedAt: '2026-10-07T18:00:00',
        elapsedSeconds: 1800,
      );
      expect(paused.isPaused, isTrue);
      expect(paused.duration(), const Duration(minutes: 30));

      final resumed = paused.copyWith(runningSince: '2026-10-07T19:00:00');
      expect(resumed.isRunning, isTrue);
      expect(
        resumed.duration(now: DateTime(2026, 10, 7, 19, 10)),
        const Duration(minutes: 40),
      );
    });

    test('结束之后以计时为准，不再看打卡', () {
      final record = timed(
        startedAt: '2026-10-07T18:00:00',
        elapsedSeconds: 2700,
        finishedAt: '2026-10-07T18:45:00',
      );
      expect(record.isFinished, isTrue);
      expect(record.isRunning, isFalse);
      expect(record.duration(), const Duration(minutes: 45));
    });

    test('计时相关的字段能存能读，旧数据没有这些字段也能读', () {
      final record = timed(
        startedAt: '2026-10-07T18:00:00',
        elapsedSeconds: 123,
        runningSince: '2026-10-07T18:30:00',
      );
      final restored = SessionRecord.fromJson(record.toJson());
      expect(restored.startedAt, '2026-10-07T18:00:00');
      expect(restored.elapsedSeconds, 123);
      expect(restored.runningSince, '2026-10-07T18:30:00');
      expect(restored.isRunning, isTrue);

      // 老版本存下来的记录里没有这些键
      final legacy = SessionRecord.fromJson(<String, dynamic>{
        'date': '2026-10-07',
        'items': <dynamic>[],
      });
      expect(legacy.hasTimer, isFalse);
      expect(legacy.elapsedSeconds, 0);
      expect(legacy.isRunning, isFalse);
    });
  });
}
