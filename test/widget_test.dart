import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muscle/data/app_repository.dart';
import 'package:muscle/data/app_store.dart';
import 'package:muscle/main.dart';
import 'package:muscle/models/exercise_item.dart';
import 'package:muscle/utils/dates.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> buildStore() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return AppStore(AppRepository(prefs));
}

/// 用接近手机的窗口尺寸，避免底部面板在测试里被挤到屏幕外。
void usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> goToTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

/// 点当前页面的悬浮按钮，在弹出的面板里填名称并保存。
Future<void> addEquipment(WidgetTester tester, String name) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, name);
  await tester.pumpAndSettle();
  await tester.tap(find.text('保存'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('启动后停在今日训练，并给出空状态提示', (WidgetTester tester) async {
    usePhoneSize(tester);
    final store = await buildStore();
    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('今日训练'), findsWidgets);
    expect(
      find.text('${weekdayName(DateTime.now().weekday)}没有安排训练'),
      findsOneWidget,
    );
    expect(find.text('暂无安排'), findsOneWidget);
  });

  testWidgets('周计划 → 今日打卡 → 历史记录的完整流程', (WidgetTester tester) async {
    usePhoneSize(tester);
    final store = await buildStore();
    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();

    final todayWeekday = DateTime.now().weekday;

    // 1. 在周计划里给今天这个星期安排一台器械。
    await goToTab(tester, '周计划');
    expect(find.text('${weekdayName(todayWeekday)}还没有安排'), findsOneWidget);
    await addEquipment(tester, '高位下拉');
    expect(find.text('高位下拉'), findsOneWidget);
    expect(store.planFor(todayWeekday), hasLength(1));

    // 2. 回到今日训练：这一天的清单已经按计划自动带出来了，等着打卡。
    await goToTab(tester, '今日训练');
    expect(find.text('高位下拉'), findsOneWidget);
    expect(find.text('计划内'), findsOneWidget);
    expect(find.text('已完成 0 / 1 台器械'), findsOneWidget);

    // 3. 练完点一下打勾。
    await tester.tap(find.text('高位下拉'));
    await tester.pumpAndSettle();
    expect(find.text('已完成 1 / 1 台器械'), findsOneWidget);
    expect(store.completedItemCount, 1);

    // 4. 历史记录里留下这一天。
    await goToTab(tester, '历史记录');
    expect(find.text('高位下拉'), findsOneWidget);
    expect(find.text('完成 1/1 台器械'), findsOneWidget);
    expect(find.text('已全部完成'), findsOneWidget);
  });

  testWidgets('先在今日训练临时加器械，之后补周计划会自动同步进来', (WidgetTester tester) async {
    usePhoneSize(tester);
    final store = await buildStore();
    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();

    // 先在今日训练里临时加一台，当天的记录就此产生。
    await addEquipment(tester, '椭圆机');
    expect(find.text('已完成 0 / 1 台器械'), findsOneWidget);

    // 之后才往周计划里补器械。
    await goToTab(tester, '周计划');
    await addEquipment(tester, '腿举机');
    await goToTab(tester, '今日训练');

    // 周计划里的器械自动出现，临时加的那台也还在。
    expect(find.text('椭圆机'), findsOneWidget);
    expect(find.text('腿举机'), findsOneWidget);
    expect(find.text('已完成 0 / 2 台器械'), findsOneWidget);
  });

  testWidgets('翻到过去的日期不会套用周计划，但可以按计划补记', (WidgetTester tester) async {
    usePhoneSize(tester);
    final store = await buildStore();
    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();

    final yesterday = addDays(today(), -1);
    final yesterdayWeekday = weekdayName(yesterday.weekday);

    // 给「昨天」那个星期几安排一台器械。
    await goToTab(tester, '周计划');
    await tester.tap(find.text(yesterdayWeekday));
    await tester.pumpAndSettle();
    await addEquipment(tester, '腿举机');
    expect(store.planFor(yesterday.weekday), hasLength(1));

    // 翻回昨天：不会自动冒出周计划里的器械。
    await goToTab(tester, '今日训练');
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('这一天没有训练记录'), findsOneWidget);
    expect(find.text('腿举机'), findsNothing);

    // 想补记就显式点一下。
    await tester.tap(find.text('按周计划补记'));
    await tester.pumpAndSettle();
    expect(find.text('腿举机'), findsOneWidget);
    expect(find.text('已完成 0 / 1 台器械'), findsOneWidget);
  });

  testWidgets('后台过夜再回来，今日训练会跳到新的一天', (WidgetTester tester) async {
    usePhoneSize(tester);
    final store = await buildStore();
    debugNowOverride = DateTime(2026, 10, 7, 23, 50);
    addTearDown(() => debugNowOverride = null);

    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('2026年10月7日'), findsOneWidget);

    // App 在后台过了夜，再回到前台
    debugNowOverride = DateTime(2026, 10, 8, 8, 0);
    // 模拟系统广播的生命周期事件；测试里需要直接触发这个受保护方法
    // ignore: invalid_use_of_protected_member
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('2026年10月8日'), findsOneWidget);
    expect(find.text('2026年10月7日'), findsNothing);
  });

  testWidgets('正在翻看历史日期时跨天，不会顶掉他在看的那一天', (WidgetTester tester) async {
    usePhoneSize(tester);
    final store = await buildStore();
    debugNowOverride = DateTime(2026, 10, 7, 23, 50);
    addTearDown(() => debugNowOverride = null);

    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();

    // 用户主动往前翻一天
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('2026年10月6日'), findsOneWidget);

    debugNowOverride = DateTime(2026, 10, 8, 8, 0);
    // ignore: invalid_use_of_protected_member
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // 仍停在用户翻到的那天
    expect(find.text('2026年10月6日'), findsOneWidget);
  });

  testWidgets('历史页可以进入关于页并打开开源许可', (WidgetTester tester) async {
    usePhoneSize(tester);
    final store = await buildStore();
    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();

    await goToTab(tester, '历史记录');
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.text('关于'), findsOneWidget);
    expect(find.text('开源许可'), findsOneWidget);
    expect(find.textContaining('1.0.0'), findsWidgets);

    await tester.tap(find.text('开源许可'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('历史记录按月份分组，并显示每月条数', (WidgetTester tester) async {
    usePhoneSize(tester);
    final store = await buildStore();
    // 跨两个月各记两天
    for (final date in <DateTime>[
      DateTime(2026, 9, 28),
      DateTime(2026, 9, 30),
      DateTime(2026, 10, 5),
    ]) {
      await store.addSessionItem(
        date,
        ExerciseItem(id: dateKey(date), name: '器械'),
      );
      await store.toggleItem(date, dateKey(date));
    }

    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();
    await goToTab(tester, '历史记录');

    expect(find.text('2026年10月 · 共 1 次'), findsOneWidget);
    expect(find.text('2026年9月 · 共 2 次'), findsOneWidget);
  });

  testWidgets('今日训练里可以直接添加器械并取消打卡', (WidgetTester tester) async {
    usePhoneSize(tester);
    final store = await buildStore();
    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();

    await addEquipment(tester, '坐姿划船');
    expect(find.text('坐姿划船'), findsOneWidget);
    expect(find.text('已完成 0 / 1 台器械'), findsOneWidget);

    await tester.tap(find.text('坐姿划船'));
    await tester.pumpAndSettle();
    expect(find.text('已完成 1 / 1 台器械'), findsOneWidget);

    // 再点一次取消打卡，进度回到 0。
    await tester.tap(find.text('坐姿划船'));
    await tester.pumpAndSettle();
    expect(find.text('已完成 0 / 1 台器械'), findsOneWidget);
    expect(store.completedItemCount, 0);
  });

  testWidgets('全部完成按钮会一次性勾选所有器械', (WidgetTester tester) async {
    usePhoneSize(tester);
    final store = await buildStore();
    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();

    await addEquipment(tester, '腿举机');
    await addEquipment(tester, '腿屈伸机');
    expect(find.text('已完成 0 / 2 台器械'), findsOneWidget);

    await tester.tap(find.text('全部完成'));
    await tester.pumpAndSettle();
    expect(find.text('已完成 2 / 2 台器械'), findsOneWidget);

    await tester.tap(find.text('取消全选'));
    await tester.pumpAndSettle();
    expect(find.text('已完成 0 / 2 台器械'), findsOneWidget);
  });

  testWidgets('编辑器里的常用器械可以一键填入名称', (WidgetTester tester) async {
    usePhoneSize(tester);
    final store = await buildStore();
    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, '龙门架'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('龙门架'), findsOneWidget);
    expect(find.text('3 组 × 12 次'), findsOneWidget);
  });

  testWidgets('历史记录可以按完成状态筛选', (WidgetTester tester) async {
    usePhoneSize(tester);
    final store = await buildStore();
    final yesterday = addDays(today(), -1);
    await store.addSessionItem(
      yesterday,
      const ExerciseItem(id: 'done', name: '卧推'),
    );
    await store.toggleItem(yesterday, 'done');
    await store.addSessionItem(
      addDays(today(), -2),
      const ExerciseItem(id: 'pending', name: '肩推机'),
    );

    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();
    await goToTab(tester, '历史记录');

    // 全部：两天都在，已完成的那天会把器械名列成标签。
    expect(find.text('卧推'), findsOneWidget);
    expect(find.text('完成 1/1 台器械'), findsOneWidget);
    expect(find.text('完成 0/1 台器械'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '已完成'));
    await tester.pumpAndSettle();
    expect(find.text('卧推'), findsOneWidget);
    expect(find.text('完成 1/1 台器械'), findsOneWidget);
    expect(find.text('完成 0/1 台器械'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '未完成'));
    await tester.pumpAndSettle();
    expect(find.text('卧推'), findsNothing);
    expect(find.text('完成 1/1 台器械'), findsNothing);
    expect(find.text('完成 0/1 台器械'), findsOneWidget);
  });

  testWidgets('历史记录的卡片可以进入详情页并补记器械', (WidgetTester tester) async {
    usePhoneSize(tester);
    final store = await buildStore();
    final yesterday = addDays(today(), -1);
    await store.addSessionItem(
      yesterday,
      const ExerciseItem(id: 'a', name: '划船机'),
    );
    await store.toggleItem(yesterday, 'a');

    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();
    await goToTab(tester, '历史记录');
    await tester.tap(find.text('划船机'));
    await tester.pumpAndSettle();

    expect(find.text('完成 1 / 1 台器械'), findsOneWidget);
    await addEquipment(tester, '椭圆机');
    expect(find.text('椭圆机'), findsOneWidget);
    expect(find.text('完成 1 / 2 台器械'), findsOneWidget);
  });
}
