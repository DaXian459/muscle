import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muscle/data/app_repository.dart';
import 'package:muscle/data/app_store.dart';
import 'package:muscle/main.dart';
import 'package:muscle/models/exercise_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> buildStore() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return AppStore(AppRepository(prefs));
}

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

/// 测试用的剪贴板替身，可以读回写入的内容。
class ClipboardBox {
  ClipboardBox(this.text);
  String text;
}

/// 用内存变量顶替系统剪贴板。
ClipboardBox installClipboard(WidgetTester tester, {String initial = ''}) {
  final box = ClipboardBox(initial);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          box.text = (call.arguments as Map<Object?, Object?>)['text'] as String;
          return null;
        case 'Clipboard.getData':
          return <String, dynamic>{'text': box.text};
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return box;
}

List<String> _namesOn(AppStore store, int weekday) =>
    store.plan.itemsFor(weekday).map((item) => item.name).toList();

void main() {
  testWidgets('周计划可以复制到剪贴板', (WidgetTester tester) async {
    usePhoneSize(tester);
    final clipboard = installClipboard(tester);
    final store = await buildStore();
    await store.addPlanItem(
      DateTime.monday,
      const ExerciseItem(id: 'a', name: '杠铃卧推', sets: 3, reps: 8, weight: 60),
    );
    await store.addPlanItem(
      DateTime.monday,
      const ExerciseItem(id: 'b', name: '上斜哑铃卧推', sets: 3, reps: 10),
    );

    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();
    await goToTab(tester, '周计划');

    await tester.tap(find.byIcon(Icons.content_copy));
    await tester.pumpAndSettle();

    expect(clipboard.text, contains('周一'));
    expect(clipboard.text, contains('杠铃卧推 3×8 @60kg'));
    expect(clipboard.text, contains('上斜哑铃卧推 3×10'));
    expect(find.textContaining('已复制周计划'), findsOneWidget);
  });

  testWidgets('从剪贴板导入别人的计划（替换）', (WidgetTester tester) async {
    usePhoneSize(tester);
    installClipboard(
      tester,
      initial: '周一\n'
          '杠铃卧推 3×8\n'
          '硬拉 3×6\n'
          '周二\n'
          '高位下拉 3×10\n',
    );
    final store = await buildStore();
    await store.addPlanItem(
      DateTime.friday,
      const ExerciseItem(id: 'old', name: '本来周五的安排'),
    );

    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();
    await goToTab(tester, '周计划');

    await tester.tap(find.byIcon(Icons.content_paste));
    await tester.pumpAndSettle();

    // 先给预览，说清会进来什么
    expect(find.text('导入预览'), findsOneWidget);
    expect(find.text('共 3 个动作'), findsOneWidget);
    expect(find.text('周一 · 2 个动作'), findsOneWidget);
    expect(find.text('周二 · 1 个动作'), findsOneWidget);

    await tester.tap(find.text('替换'));
    await tester.pumpAndSettle();

    expect(_namesOn(store, DateTime.monday), <String>['杠铃卧推', '硬拉']);
    expect(_namesOn(store, DateTime.tuesday), <String>['高位下拉']);
    // 替换会清掉导入内容里没有的星期
    expect(store.plan.itemsFor(DateTime.friday), isEmpty);
  });

  testWidgets('导入时选「追加」会保留现有计划', (WidgetTester tester) async {
    usePhoneSize(tester);
    installClipboard(tester, initial: '周一\n杠铃卧推 3×8\n');
    final store = await buildStore();
    await store.addPlanItem(
      DateTime.monday,
      const ExerciseItem(id: 'old', name: '原有的动作'),
    );

    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();
    await goToTab(tester, '周计划');

    await tester.tap(find.byIcon(Icons.content_paste));
    await tester.pumpAndSettle();
    await tester.tap(find.text('追加'));
    await tester.pumpAndSettle();

    expect(_namesOn(store, DateTime.monday), <String>['原有的动作', '杠铃卧推']);
  });

  testWidgets('导入带次数区间的计划会明确提示降级', (WidgetTester tester) async {
    usePhoneSize(tester);
    installClipboard(tester, initial: '周四\n深蹲 3×8-10\n站姿提踵 3×15-20\n');
    final store = await buildStore();

    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();
    await goToTab(tester, '周计划');

    await tester.tap(find.byIcon(Icons.content_paste));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 个是次数区间或计时'), findsOneWidget);

    await tester.tap(find.text('替换'));
    await tester.pumpAndSettle();

    final squat = store.plan.itemsFor(DateTime.thursday).first;
    expect(squat.reps, 8);
    expect(squat.note, '每组 8-10 次');
  });

  testWidgets('剪贴板是空的时候给提示，不弹预览', (WidgetTester tester) async {
    usePhoneSize(tester);
    installClipboard(tester, initial: '   ');
    final store = await buildStore();

    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();
    await goToTab(tester, '周计划');

    await tester.tap(find.byIcon(Icons.content_paste));
    await tester.pumpAndSettle();

    expect(find.text('剪贴板里没有文字'), findsOneWidget);
    expect(find.text('导入预览'), findsNothing);
  });

  testWidgets('周计划为空时导出会提示', (WidgetTester tester) async {
    usePhoneSize(tester);
    final clipboard = installClipboard(tester, initial: '不该被覆盖');
    final store = await buildStore();

    await tester.pumpWidget(MuscleApp(store: store));
    await tester.pumpAndSettle();
    await goToTab(tester, '周计划');

    await tester.tap(find.byIcon(Icons.content_copy));
    await tester.pumpAndSettle();

    expect(find.textContaining('周计划还是空的'), findsOneWidget);
    expect(clipboard.text, '不该被覆盖', reason: '空计划不该往剪贴板里写东西');
  });
}
