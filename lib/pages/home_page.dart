import 'package:flutter/material.dart';

import 'history_page.dart';
import 'plan_page.dart';
import 'today_page.dart';

/// 底部导航容器：今日训练 / 周计划 / 历史记录。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  static const List<Widget> _pages = <Widget>[
    TodayPage(),
    PlanPage(),
    HistoryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: '今日训练',
          ),
          NavigationDestination(
            icon: Icon(Icons.date_range),
            label: '周计划',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: '历史记录',
          ),
        ],
      ),
    );
  }
}
