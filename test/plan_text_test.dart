import 'package:flutter_test/flutter_test.dart';
import 'package:muscle/models/exercise_item.dart';
import 'package:muscle/models/weekly_plan.dart';
import 'package:muscle/utils/plan_text.dart';

int _seed = 0;
String _id() => 'test-${_seed++}';

PlanImportResult _decode(String text) => decodePlanText(text, idFactory: _id);

void main() {
  group('导出', () {
    test('按星期分组，带重量与备注，没安排的日子不出现', () {
      final plan = WeeklyPlan(<int, List<ExerciseItem>>{
        DateTime.monday: const <ExerciseItem>[
          ExerciseItem(id: 'a', name: '杠铃卧推', sets: 3, reps: 8, weight: 60),
          ExerciseItem(
            id: 'b',
            name: '上斜哑铃卧推',
            sets: 3,
            reps: 10,
            note: '坐姿第 2 档',
          ),
        ],
        DateTime.friday: const <ExerciseItem>[
          ExerciseItem(id: 'c', name: '侧平举', sets: 3, reps: 15),
        ],
      });

      final text = encodePlanText(plan);
      expect(text, contains('周一'));
      expect(text, contains('杠铃卧推 3×8 @60kg'));
      expect(text, contains('上斜哑铃卧推 3×10 // 坐姿第 2 档'));
      expect(text, contains('周五'));
      expect(text, contains('侧平举 3×15'));
      expect(text, isNot(contains('周三')));
    });
  });

  group('解析', () {
    test('用户手写的那张计划表能直接认出来', () {
      const input = '周一 \n'
          '动作\t组数 × 次数\n'
          '杠铃/哑铃卧推\t3 × 8\n'
          '上斜哑铃卧推\t3 × 10\n'
          '坐姿哑铃推举\t3 × 10\n'
          '绳索下压\t3 × 12\n'
          '哑铃侧平举\t3 × 15\n'
          '周二 \n'
          '动作\t组数 × 次数\n'
          '高位下拉\t3 × 8\n';

      final result = _decode(input);
      expect(result.unreadable, isEmpty, reason: '表头和分组标题不该算错误');
      expect(result.days[DateTime.monday], hasLength(5));
      expect(result.days[DateTime.tuesday], hasLength(1));

      final first = result.days[DateTime.monday]!.first;
      expect(first.name, '杠铃/哑铃卧推');
      expect(first.sets, 3);
      expect(first.reps, 8);
    });

    test('星期的各种写法都认', () {
      for (final header in <String>['周一', '星期一', '礼拜一', '周1']) {
        final result = _decode('$header\n卧推 3×8\n');
        expect(
          result.days[DateTime.monday],
          hasLength(1),
          reason: '「$header」没被认出来',
        );
      }
      expect(_decode('星期天\n卧推 3×8\n').days[DateTime.sunday], hasLength(1));
      expect(_decode('周日\n卧推 3×8\n').days[DateTime.sunday], hasLength(1));
    });

    test('组数×次数的各种写法都认', () {
      for (final line in <String>[
        '卧推 3×8',
        '卧推 3 × 8',
        '卧推 3组 × 8次',
        '卧推 3 组 x 8 次',
        '卧推\t3X8',
        '卧推 3*8',
      ]) {
        final result = _decode('周一\n$line\n');
        final item = result.days[DateTime.monday]?.first;
        expect(item, isNotNull, reason: '「$line」没解析出来');
        expect(item!.sets, 3, reason: '「$line」组数不对');
        expect(item.reps, 8, reason: '「$line」次数不对');
      }
    });

    test('重量和备注', () {
      final item = _decode('周一\n卧推 4x10 @62.5kg // 最后一组力竭\n')
          .days[DateTime.monday]!
          .single;
      expect(item.weight, 62.5);
      expect(item.note, '最后一组力竭');
    });

    test('次数区间会降级：记下限，原文进备注，并计入 degraded', () {
      final result = _decode('周四\n深蹲 3 × 8-10\n站姿提踵 3 × 15-20\n');
      final items = result.days[DateTime.thursday]!;

      expect(items, hasLength(2));
      expect(items.first.reps, 8);
      expect(items.first.note, '每组 8-10 次');
      expect(items.last.reps, 15);
      expect(items.last.note, '每组 15-20 次');
      expect(result.degraded, 2);
    });

    test('计时动作也会降级', () {
      final result = _decode('周五\n平板支撑 3 × 45 秒\n');
      final item = result.days[DateTime.friday]!.single;
      expect(item.reps, 45);
      expect(item.note, '每组 45 秒');
      expect(result.degraded, 1);
    });

    test('认不出的行会被回报，不静默丢弃', () {
      final result = _decode('周一\n卧推 3×8\n热身 10 分钟\n');
      expect(result.days[DateTime.monday], hasLength(1));
      expect(result.unreadable, <String>['热身 10 分钟']);
    });

    test('整行没有数字的当成标题忽略，不算错误', () {
      final result = _decode('周一 胸 / 肩 / 三头\n卧推 3×8\n');
      expect(result.unreadable, isEmpty);
      expect(result.days[DateTime.monday], hasLength(1));
    });

    test('还没写星期就先出现动作，算无法归类', () {
      final result = _decode('卧推 3×8\n周一\n划船 3×10\n');
      expect(result.unreadable, <String>['卧推 3×8']);
      expect(result.days[DateTime.monday], hasLength(1));
    });

    test('空文本解析不出东西', () {
      final result = _decode('\n\n# 只有注释\n');
      expect(result.isEmpty, isTrue);
      expect(result.filledWeekdays, isEmpty);
    });
  });

  group('往返', () {
    test('导出再导入，动作内容一致', () {
      final plan = WeeklyPlan(<int, List<ExerciseItem>>{
        DateTime.monday: const <ExerciseItem>[
          ExerciseItem(id: 'a', name: '杠铃卧推', sets: 3, reps: 8, weight: 60),
          ExerciseItem(id: 'b', name: '上斜哑铃卧推', sets: 3, reps: 10),
        ],
        DateTime.thursday: const <ExerciseItem>[
          ExerciseItem(
            id: 'c',
            name: '深蹲（或腿举）',
            sets: 3,
            reps: 8,
            note: '每组 8-10 次',
          ),
        ],
      });

      final result = _decode(encodePlanText(plan));
      expect(result.unreadable, isEmpty);
      expect(result.degraded, 0, reason: '导出的是单个次数，不该再被判成降级');

      for (final weekday in <int>[DateTime.monday, DateTime.thursday]) {
        final before = plan.itemsFor(weekday);
        final after = result.days[weekday]!;
        expect(after, hasLength(before.length));
        for (var i = 0; i < before.length; i++) {
          expect(after[i].name, before[i].name);
          expect(after[i].sets, before[i].sets);
          expect(after[i].reps, before[i].reps);
          expect(after[i].weight, before[i].weight);
          expect(after[i].note, before[i].note);
        }
      }
    });

    test('带备注的往返也稳定', () {
      final plan = WeeklyPlan(<int, List<ExerciseItem>>{
        DateTime.friday: const <ExerciseItem>[
          ExerciseItem(
            id: 'a',
            name: '绳索下压',
            sets: 3,
            reps: 12,
            weight: 25,
            note: '手肘夹紧',
          ),
        ],
      });
      final once = _decode(encodePlanText(plan));
      final twice = _decode(encodePlanText(
        WeeklyPlan(<int, List<ExerciseItem>>{DateTime.friday: once.days[DateTime.friday]!}),
      ));
      expect(twice.days[DateTime.friday]!.single.note, '手肘夹紧');
      expect(twice.days[DateTime.friday]!.single.weight, 25);
    });
  });
}
