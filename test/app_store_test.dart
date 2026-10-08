import 'package:flutter_test/flutter_test.dart';
import 'package:muscle/data/app_repository.dart';
import 'package:muscle/data/app_store.dart';
import 'package:muscle/models/exercise_item.dart';
import 'package:muscle/utils/dates.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-07 是星期三。
///
/// 下面一半以上的用例都依赖「这一天是不是今天/过去/未来」，
/// 所以整个文件把时钟钉死在这天的中午 —— 否则测试只在写它的那天能过。
final DateTime kWednesday = DateTime(2026, 10, 7);

Future<AppStore> buildStore() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return AppStore(AppRepository(prefs));
}

void main() {
  // 把「现在」钉在 kWednesday 中午：今天 / 过去 / 未来的判定才是确定的
  setUp(() => debugNowOverride = DateTime(2026, 10, 7, 12));
  tearDown(() => debugNowOverride = null);

  test('全新安装时既没有计划也没有记录', () async {
    final store = await buildStore();
    expect(store.history, isEmpty);
    expect(store.plan.totalItems, 0);
    expect(store.sessionFor(kWednesday).items, isEmpty);
    expect(store.trainingDayCount, 0);
    expect(store.currentStreak, 0);
  });

  test('周计划里的器械会出现在对应星期的当天清单', () async {
    final store = await buildStore();
    expect(kWednesday.weekday, DateTime.wednesday);

    await store.addPlanItem(
      DateTime.wednesday,
      const ExerciseItem(
        id: 'a',
        name: '高位下拉',
        sets: 4,
        reps: 10,
        weight: 45,
      ),
    );

    final session = store.sessionFor(kWednesday);
    expect(session.total, 1);
    expect(session.items.single.name, '高位下拉');
    expect(session.items.single.fromPlan, isTrue);

    // 只是从模板读出来还不算训练记录。
    expect(store.hasRecord(kWednesday), isFalse);
    expect(store.history, isEmpty);
  });

  test('打卡后留下历史记录，取消打卡后计数归零', () async {
    final store = await buildStore();
    await store.addPlanItem(
      DateTime.wednesday,
      const ExerciseItem(id: 'a', name: '卧推'),
    );

    await store.toggleItem(kWednesday, 'a');
    expect(store.hasRecord(kWednesday), isTrue);
    expect(store.history.length, 1);
    expect(store.history.single.completedCount, 1);
    expect(store.history.single.allCompleted, isTrue);
    expect(store.history.single.items.single.completedAt, isNotNull);
    expect(store.completedItemCount, 1);
    expect(store.trainingDayCount, 1);

    await store.toggleItem(kWednesday, 'a');
    final record = store.history.single;
    expect(record.completedCount, 0);
    expect(record.items.single.completedAt, isNull);
    expect(store.completedItemCount, 0);
    expect(store.trainingDayCount, 0);
  });

  test('全部完成 / 取消全选', () async {
    final store = await buildStore();
    await store.addSessionItem(
      kWednesday,
      const ExerciseItem(id: 'a', name: 'A'),
    );
    await store.addSessionItem(
      kWednesday,
      const ExerciseItem(id: 'b', name: 'B'),
    );

    await store.setAllCompleted(kWednesday, true);
    expect(store.sessionFor(kWednesday).completedCount, 2);
    expect(store.sessionFor(kWednesday).allCompleted, isTrue);

    await store.setAllCompleted(kWednesday, false);
    expect(store.sessionFor(kWednesday).completedCount, 0);
  });

  test('清单被删空后这一天不再出现在历史里', () async {
    final store = await buildStore();
    await store.addSessionItem(
      kWednesday,
      const ExerciseItem(id: 'x', name: '深蹲'),
    );
    expect(store.hasRecord(kWednesday), isTrue);

    await store.removeSessionItem(kWednesday, 'x');
    expect(store.sessionFor(kWednesday).items, isEmpty);
    expect(store.history, isEmpty);
    // 空记录本身要留着，否则清单又会按周计划长回来。
    expect(store.hasRecord(kWednesday), isTrue);
  });

  test('往周计划里加器械后，当天的清单会自动跟上', () async {
    final store = await buildStore();
    await store.addPlanItem(
      DateTime.wednesday,
      const ExerciseItem(id: 'a', name: 'A'),
    );
    await store.toggleItem(kWednesday, 'a');
    expect(store.sessionFor(kWednesday).total, 1);

    await store.addPlanItem(
      DateTime.wednesday,
      const ExerciseItem(id: 'b', name: 'B'),
    );

    final session = store.sessionFor(kWednesday);
    expect(session.total, 2);
    expect(session.items.first.id, 'a');
    expect(session.items.last.id, 'b');
    // 已经打过的卡不会被抹掉。
    expect(session.completedCount, 1);
    expect(session.items.first.completed, isTrue);
    expect(session.items.last.completed, isFalse);
  });

  test('在计划里改动作会同步到当天，完成状态保留', () async {
    final store = await buildStore();
    await store.addPlanItem(
      DateTime.wednesday,
      const ExerciseItem(id: 'a', name: '卧推', sets: 3, reps: 10),
    );
    await store.toggleItem(kWednesday, 'a');

    await store.updatePlanItem(
      DateTime.wednesday,
      const ExerciseItem(
        id: 'a',
        name: '上斜卧推',
        sets: 5,
        reps: 8,
        weight: 40,
      ),
    );

    final entry = store.sessionFor(kWednesday).items.single;
    expect(entry.name, '上斜卧推');
    expect(entry.sets, 5);
    expect(entry.reps, 8);
    expect(entry.weight, 40);
    expect(entry.completed, isTrue);
  });

  test('从计划里删掉未完成的器械会一起移出当天，已完成的保留', () async {
    final store = await buildStore();
    await store.addPlanItem(
      DateTime.wednesday,
      const ExerciseItem(id: 'a', name: '已完成的'),
    );
    await store.addPlanItem(
      DateTime.wednesday,
      const ExerciseItem(id: 'b', name: '还没练的'),
    );
    await store.toggleItem(kWednesday, 'a');

    await store.removePlanItem(DateTime.wednesday, 'b');
    expect(
      store.sessionFor(kWednesday).items.map((entry) => entry.id),
      <String>['a'],
    );

    // 已经打过卡的即使从计划移除也留着，避免丢掉训练记录。
    await store.removePlanItem(DateTime.wednesday, 'a');
    expect(
      store.sessionFor(kWednesday).items.map((entry) => entry.id),
      <String>['a'],
    );
    expect(store.sessionFor(kWednesday).completedCount, 1);
  });

  test('当天临时加的器械不会被计划同步冲掉', () async {
    final store = await buildStore();
    await store.addSessionItem(
      kWednesday,
      const ExerciseItem(id: 'temp', name: '临时加练'),
    );
    await store.addPlanItem(
      DateTime.wednesday,
      const ExerciseItem(id: 'a', name: 'A'),
    );

    final ids =
        store.sessionFor(kWednesday).items.map((entry) => entry.id).toList();
    expect(ids, <String>['a', 'temp']);
  });

  test('过去的日期不会自动套用当前的周计划', () async {
    final store = await buildStore();
    final lastWednesday = addDays(kWednesday, -7);
    expect(lastWednesday.weekday, DateTime.wednesday);

    await store.addPlanItem(
      DateTime.wednesday,
      const ExerciseItem(id: 'a', name: 'A'),
    );

    // 历史日期默认是空的：今天往计划里加的器械不该凭空出现在上周三。
    expect(store.sessionFor(lastWednesday).items, isEmpty);

    // 想补记要显式载入（对应界面上的「按周计划补记」）。
    await store.syncWithPlan(lastWednesday);
    expect(store.sessionFor(lastWednesday).total, 1);
    await store.toggleItem(lastWednesday, 'a');
    expect(store.sessionFor(lastWednesday).completedCount, 1);

    // 之后再改计划，这条历史记录不再跟着变。
    await store.addPlanItem(
      DateTime.wednesday,
      const ExerciseItem(id: 'b', name: 'B'),
    );
    expect(store.sessionFor(lastWednesday).total, 1);
    expect(store.sessionFor(lastWednesday).items.single.id, 'a');
    // 今天则正常跟上。
    expect(store.sessionFor(kWednesday).total, 2);
  });

  test('历史日期上的记录不会被计划同步改写', () async {
    final store = await buildStore();
    final lastWednesday = addDays(kWednesday, -7);

    // 补记了两台，其中一台已完成。
    await store.addPlanItem(
      DateTime.wednesday,
      const ExerciseItem(id: 'a', name: 'A'),
    );
    await store.addPlanItem(
      DateTime.wednesday,
      const ExerciseItem(id: 'b', name: 'B'),
    );
    await store.syncWithPlan(lastWednesday);
    await store.toggleItem(lastWednesday, 'a');
    expect(store.sessionFor(lastWednesday).total, 2);

    // 把没练的那台从计划里删掉，历史不受影响。
    await store.removePlanItem(DateTime.wednesday, 'b');
    expect(store.sessionFor(lastWednesday).total, 2);
    expect(store.sessionFor(lastWednesday).completedCount, 1);

    // 再往计划里加一台，历史同样不动。
    await store.addPlanItem(
      DateTime.wednesday,
      const ExerciseItem(id: 'c', name: 'C'),
    );
    expect(store.sessionFor(lastWednesday).total, 2);
  });

  test('只刷新被改动的那个星期几', () async {
    final store = await buildStore();
    await store.addPlanItem(
      DateTime.wednesday,
      const ExerciseItem(id: 'a', name: 'A'),
    );
    await store.addPlanItem(
      DateTime.thursday,
      const ExerciseItem(id: 't', name: 'T'),
    );
    final tomorrow = addDays(kWednesday, 1);
    await store.toggleItem(tomorrow, 't');
    expect(store.sessionFor(tomorrow).total, 1);

    // 改周三的计划，周四的记录不该被动。
    await store.addPlanItem(
      DateTime.wednesday,
      const ExerciseItem(id: 'b', name: 'B'),
    );
    expect(store.sessionFor(tomorrow).total, 1);
    expect(store.sessionFor(kWednesday).total, 2);
  });

  test('清单清空后仍然可以手动按计划补齐', () async {
    final store = await buildStore();
    await store.addPlanItem(
      DateTime.wednesday,
      const ExerciseItem(id: 'a', name: 'A'),
    );
    await store.removeSessionItem(kWednesday, 'a');
    expect(store.sessionFor(kWednesday).items, isEmpty);

    await store.syncWithPlan(kWednesday);
    expect(store.sessionFor(kWednesday).total, 1);
  });

  test('计划可以复制到其他星期，也可以整天空白', () async {
    final store = await buildStore();
    await store.addPlanItem(
      DateTime.monday,
      const ExerciseItem(id: 'a', name: '卧推'),
    );
    await store.addPlanItem(
      DateTime.monday,
      const ExerciseItem(id: 'b', name: '飞鸟'),
    );

    await store.copyPlanDay(DateTime.monday, DateTime.friday);
    expect(store.plan.itemsFor(DateTime.friday).length, 2);
    expect(store.plan.itemsFor(DateTime.friday).first.name, '卧推');

    await store.clearPlanDay(DateTime.monday);
    expect(store.plan.itemsFor(DateTime.monday), isEmpty);
    expect(store.plan.itemsFor(DateTime.friday).length, 2);

    await store.removePlanItem(DateTime.friday, 'b');
    expect(store.plan.itemsFor(DateTime.friday).single.name, '卧推');
  });

  test('数据会写入本地并在重新打开后读回', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(AppRepository(prefs));

    await store.addPlanItem(
      DateTime.monday,
      const ExerciseItem(
        id: 'p1',
        name: '腿举机',
        sets: 5,
        reps: 8,
        weight: 120,
      ),
    );
    await store.addSessionItem(
      kWednesday,
      const ExerciseItem(id: 's1', name: '临时加练'),
    );
    await store.toggleItem(kWednesday, 's1');

    final reopened = AppStore(AppRepository(prefs));
    expect(reopened.plan.itemsFor(DateTime.monday).single.name, '腿举机');
    expect(reopened.plan.itemsFor(DateTime.monday).single.weight, 120);
    expect(reopened.history.single.date, dateKey(kWednesday));
    expect(reopened.history.single.items.single.name, '临时加练');
    expect(reopened.history.single.completedCount, 1);
  });

  test('连续打卡天数从今天往前数', () async {
    final store = await buildStore();
    final base = today();
    for (var offset = 0; offset < 3; offset++) {
      final date = addDays(base, -offset);
      final id = 'id$offset';
      await store.addSessionItem(date, ExerciseItem(id: id, name: '器械'));
      await store.toggleItem(date, id);
    }
    expect(store.currentStreak, 3);
    expect(store.trainingDayCount, 3);
    expect(store.completedItemCount, 3);
  });

  test('历史按日期倒序，并按周统计完成次数', () async {
    final store = await buildStore();
    for (final date in <DateTime>[
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 7),
      DateTime(2026, 10, 6),
    ]) {
      await store.addSessionItem(
        date,
        ExerciseItem(id: dateKey(date), name: '器械'),
      );
      await store.toggleItem(date, dateKey(date));
    }
    expect(
      store.history.map((record) => record.date).toList(),
      <String>['2026-10-07', '2026-10-06', '2026-10-05'],
    );
    expect(store.completedInWeek(DateTime(2026, 10, 7)), 3);
    expect(store.completedInWeek(DateTime(2026, 10, 12)), 0);
  });

  test('删除某一天的记录', () async {
    final store = await buildStore();
    await store.addSessionItem(
      kWednesday,
      const ExerciseItem(id: 'a', name: '卧推'),
    );
    await store.toggleItem(kWednesday, 'a');
    expect(store.history, hasLength(1));

    await store.deleteSession(kWednesday);
    expect(store.history, isEmpty);
    // 模板还在，所以再次打开这一天仍能看到待办清单。
    expect(store.sessionFor(kWednesday).items, isEmpty);
  });
}
