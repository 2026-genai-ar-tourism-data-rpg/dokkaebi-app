// ============================================================
// [v1] 앱 엔트리 + 5탭 셸 — 도깨비 모바일 클라이언트
// pipeline: 모바일 클라이언트 / 부트스트랩·네비게이션
// 구현(요약): 다크 RPG 테마 + 하단 5탭(홈/지도/퀘스트/도감/프로필). 시안 1~10 기반.
//            ⚠️ 지도·도감·AR·실시간은 TODO(정찬희/이지선) — 탭 골격만.
// 구현일: 2026-06-18 | 작성: kys (app-theme/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import 'screens/dex_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/quest_tab_screen.dart';
import 'session.dart';
import 'store.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.load(); // 저장된 로그인 복원
  if (Session.isLoggedIn) await ScenarioStore.I.load(); // 내 탐험 복원
  runApp(const DokkaebiApp());
}

class DokkaebiApp extends StatelessWidget {
  const DokkaebiApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '도깨비: 팔도의 비밀',
      theme: buildDokkaebiTheme(),
      // 로그인돼 있으면 메인, 아니면 온보딩 → 로그인
      home: Session.isLoggedIn ? const MainShell() : const OnboardingScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// 하단 5탭 셸 (시안 네비게이션)
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;
  static const _tabs = [
    HomeScreen(),
    MapScreen(),
    QuestTabScreen(),
    DexScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _tabs[_idx]),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.teal.withOpacity(0.18),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
        child: NavigationBar(
          height: 64,
          selectedIndex: _idx,
          onDestinationSelected: (i) => setState(() => _idx = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: '지도'),
            NavigationDestination(icon: Icon(Icons.military_tech_outlined), selectedIcon: Icon(Icons.military_tech), label: '퀘스트'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: '도감'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '프로필'),
          ],
        ),
      ),
    );
  }
}
