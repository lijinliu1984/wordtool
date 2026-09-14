import 'package:flutter/material.dart';

import 'about_page.dart';
import 'home_page.dart';
import 'word_square_page.dart';

/// 应用主框架：底部三 Tab 导航
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _pages = [
    HomePage(key: HomePage.globalKey),
    const WordSquarePage(),
    const AboutPage(),
  ];

  void _onTabTapped(int index) {
    if (index == 0 && _currentIndex != 0) {
      // 切换到首页 tab，刷新首页数据
      HomePage.globalKey.currentState?.refresh();
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).cardColor,
        selectedItemColor: const Color(0xFFFF6B9D),
        unselectedItemColor: Colors.grey[600],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: '单词广场',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            label: '关于',
          ),
        ],
      ),
    );
  }
}
