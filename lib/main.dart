// ============================================================
// [v1] 앱 엔트리 + 5탭 셸 — 도깨비 모바일 클라이언트
// pipeline: 모바일 클라이언트 / 부트스트랩·네비게이션
// 구현(요약): 다크 RPG 테마 + 하단 5탭(홈/지도/퀘스트/도감/프로필). 시안 1~10 기반.
//            ⚠️ 지도·도감·AR·실시간은 TODO(정찬희/이지선) — 탭 골격만.
// 구현일: 2026-06-18 | 작성: kys (app-theme/kys/v1)
// [v2] 2026-09-04: navigatorKey(AppNav) — ApiClient가 401을 받으면 로그인 화면으로 보낸다.
//                  카카오 init은 웹에서 건너뛰고 실패해도 앱을 죽이지 않는다(흰 화면 방지).
// ============================================================
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import 'config.dart';
import 'nav.dart';
import 'screens/dex_screen.dart';
import 'screens/map_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/quest_tab_screen.dart';
import 'session.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets/nav_icons.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 키 없이도 앱은 뜨게 둔다(다른 화면 작업엔 지장 없어야 함) — 지도 탭만
  // 못 그려진다. 실제 키는 --dart-define=KAKAO_NATIVE_APP_KEY=... 로 주입.
  // 웹은 네이티브 키가 아니라 JavaScript 키를 요구해 init이 무조건 던진다 → 웹에선 건너뛴다.
  // 키가 잘못돼도(예시 파일의 자리표시자 그대로 등) 앱이 흰 화면으로 죽으면 안 되므로
  // 실패는 로그만 남기고 계속 간다.
  if (!kIsWeb && AppConfig.kakaoNativeAppKey.isNotEmpty) {
    try {
      await KakaoMapsFlutter.init(AppConfig.kakaoNativeAppKey);
    } catch (e) {
      debugPrint('KakaoMapsFlutter.init 실패 — 지도 탭만 비활성: $e');
    }
  }
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
      navigatorKey: AppNav.key,
      theme: buildDokkaebiTheme(),
      // 로그인돼 있으면 메인 셸(홈=지역 선택 지도), 아니면 온보딩 → 로그인.
      // 프롤로그는 로그인 직후가 아니라 첫 코스 생성 직후에 뜬다(explore_confirm_screen.dart).
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
  // 홈 탭 = 지역 선택 지도(MapScreen). 별도 지도 탭은 없앴다.
  static const _tabs = [
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
          destinations: [
            NavigationDestination(
                icon: const DokkaebiNavIcon(DokkaebiNavIconType.home,
                    color: AppColors.textSecondary),
                selectedIcon: const DokkaebiNavIconPop(
                    child: DokkaebiNavIcon(DokkaebiNavIconType.home,
                        color: AppColors.teal, filled: true)),
                label: '홈'),
            NavigationDestination(
                icon: const DokkaebiNavIcon(DokkaebiNavIconType.quest,
                    color: AppColors.textSecondary),
                selectedIcon: const DokkaebiNavIconPop(
                    child: DokkaebiNavIcon(DokkaebiNavIconType.quest,
                        color: AppColors.teal, filled: true)),
                label: '퀘스트'),
            NavigationDestination(
                icon: const DokkaebiNavIcon(DokkaebiNavIconType.dex,
                    color: AppColors.textSecondary),
                selectedIcon: const DokkaebiNavIconPop(
                    child: DokkaebiNavIcon(DokkaebiNavIconType.dex,
                        color: AppColors.teal, filled: true)),
                label: '도감'),
            NavigationDestination(
                icon: const DokkaebiNavIcon(DokkaebiNavIconType.profile,
                    color: AppColors.textSecondary),
                selectedIcon: const DokkaebiNavIconPop(
                    child: DokkaebiNavIcon(DokkaebiNavIconType.profile,
                        color: AppColors.teal, filled: true)),
                label: '프로필'),
          ],
        ),
      ),
    );
  }
}
