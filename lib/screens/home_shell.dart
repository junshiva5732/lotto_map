import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/banner_ad_widget.dart';
import 'lucky_screen.dart';
import 'map_screen.dart';
import 'memo_list_screen.dart';
import 'ranking_screen.dart';

/// 하단 탭 4개 + 공통 배너.
class HomeShell extends StatefulWidget {
  final AppServices services;
  const HomeShell({super.key, required this.services});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    widget.services.state.addListener(_onState);
  }

  @override
  void dispose() {
    widget.services.state.removeListener(_onState);
    super.dispose();
  }

  void _onState() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final s = widget.services;
    final tab = s.state.tab;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            // 지도는 상태(카메라 위치)를 유지해야 하므로 IndexedStack
            child: IndexedStack(
              index: tab,
              children: [
                MapScreen(services: s),
                RankingScreen(services: s),
                MemoListScreen(services: s),
                LuckyScreen(services: s),
              ],
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => s.state.tab = i,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: '지도'),
          NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: '랭킹'),
          NavigationDestination(
              icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: '내 메모'),
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: '행운 번호'),
        ],
      ),
    );
  }
}
