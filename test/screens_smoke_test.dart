// ============================================================
// [v1] 전 화면 스모크 테스트 — 렌더 예외·레이아웃 오버플로 일괄 검출
// pipeline: 모바일 클라이언트 / 테스트 (로컬 에러 전수 확인)
// 구현(요약): 모든 화면을 여러 화면 크기(소형폰~태블릿)로 pump해서
//            (1) 빌드 중 예외가 안 나는지, (2) RenderFlex 오버플로가 없는지 검사.
//            기존 테스트는 scenario/quest_journey 2개만 커버해서 나머지 화면은
//            실기기에서 처음 열 때야 빨간 화면을 만나게 된다 — 그 전에 잡는다.
//
//            ⚠️ 탭 바디 화면(home/map/quest_tab/dex/profile)은 자체 Scaffold가 없다.
//            MainShell의 Scaffold 안에 들어가는 구조라, 테스트에서도 똑같이 감싸야 한다.
//            안 감싸면 Material 조상이 없어 DefaultTextStyle이 48px로 튀고,
//            없는 오버플로가 잔뜩 보고된다(실측: Home 226px = 전부 허위).
// 구현일: 2026-08-04 | 작성: kys (local-sweep/kys/v1)
// ============================================================
import 'package:dokkaebi_app/models/scenario.dart';
import 'package:dokkaebi_app/screens/ar_search_screen.dart';
import 'package:dokkaebi_app/screens/create_scenario_screen.dart';
import 'package:dokkaebi_app/screens/dex_screen.dart';
import 'package:dokkaebi_app/screens/home_screen.dart';
import 'package:dokkaebi_app/screens/honbul_home_screen.dart';
import 'package:dokkaebi_app/screens/location_verify_screen.dart';
import 'package:dokkaebi_app/screens/login_screen.dart';
import 'package:dokkaebi_app/screens/map_screen.dart';
import 'package:dokkaebi_app/screens/onboarding_screen.dart';
import 'package:dokkaebi_app/screens/place_detail_screen.dart';
import 'package:dokkaebi_app/screens/profile_screen.dart';
import 'package:dokkaebi_app/screens/quest_journey_screen.dart';
import 'package:dokkaebi_app/screens/quest_play_screen.dart';
import 'package:dokkaebi_app/screens/quest_tab_screen.dart';
import 'package:dokkaebi_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 검사할 화면 크기 — 가장 좁은 기기에서 오버플로가 터진다.
/// iPhone SE(320x568)는 국내에서도 아직 쓰이는 최소 폭이라 반드시 포함한다.
const _sizes = <String, Size>{
  'iPhoneSE(320x568)': Size(320, 568),
  'iPhone14(390x844)': Size(390, 844),
  'iPad(768x1024)': Size(768, 1024),
};

/// 지금 오버플로가 남아 있지만 **다른 PR이 재구성 중**이라 여기서 고치지 않는 화면.
/// 값 = skip 사유(테스트 리포트에 그대로 출력된다).
///
/// app#14(이지선)가 탐험 마법사 도입과 함께 이 화면들을 다시 짜고 있다.
/// 지금 레이아웃을 손대면 충돌만 나고, 어차피 교체될 코드를 고치는 셈이 된다.
/// **app#14 머지 직후 이 맵을 비우고 남은 오버플로를 확인할 것.**
const _pendingRework = <String, String>{
  // 비어 있음 = 보류 중인 화면 없음.
  // app#14가 Home·Map·Onboarding을 재구성 중이지만, 오버플로는 좁은 기기에서
  // 실제로 잘리는 결함이라 먼저 고쳤다. #14와 충돌 시 #14 쪽 레이아웃을 채택하고
  // 이 테스트를 다시 돌려 남은 오버플로를 확인할 것.
};

/// 자체 Scaffold가 없는 '탭 바디' 화면 — MainShell과 동일하게 감싸 줘야 한다.
/// (main.dart의 MainShell: Scaffold(body: SafeArea(child: tab)))
const _tabBodies = {
  'HomeScreen', 'MapScreen', 'QuestTabScreen', 'DexScreen', 'ProfileScreen',
};

/// 퀘스트 플레이 화면에 넣을 최소 노드(AI 계약 형태).
QuestNode _node() => QuestNode.fromJson({
      'node_id': 'tour_1',
      'name': '경복궁',
      'kind': 'spot',
      'fragment_id': 'jongno_stone_1of5',
      'stone_no': 1,
      'is_finale': false,
      'map_x': 126.977,
      'map_y': 37.5796,
      'trigger_radius_m': 100,
      'npc_dialogue': '허허, 어서 오거라.',
      'mission': {
        'type': 'PHOTO_FIND',
        'order': '근정전 처마를 찾아 담거라',
        'hints': ['처마 끝을 보거라', '해 지는 쪽이니라'],
      },
      'objective': {
        'order': '근정전 처마를 찾아 담거라',
        'hints': ['처마 끝을 보거라'],
      },
      'hint_ladder': {'H1': '처마', 'H2': '해지는 쪽', 'H3': '주변을 보거라'},
      'actions': [
        {'a': 'goto', 'place': '경복궁'},
        {'a': 'listen', 'slot': 'intro'},
      ],
      'npc': {'name': '먹 도깨비', 'speech': '~니라'},
      'motivation': ['M1'],
      'strategy': ['S4_PHOTO_TRAIL'],
      'requires': <String>[],
      'requires_mode': 'none',
      'grants': ['fragment:jongno_stone_1of5'],
      'success': ['place_verified'],
    });

/// 화면 하나를 주어진 크기로 그려 보고 예외·오버플로를 잡는다.
Future<List<String>> _render(
  WidgetTester tester,
  Widget screen,
  Size size, {
  required bool needsShell,
}) async {
  final problems = <String>[];

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: buildDokkaebiTheme(),
    // 앱에서 보이는 그대로 — 탭 바디는 MainShell의 Scaffold 안에서 그려진다.
    home: needsShell ? Scaffold(body: SafeArea(child: screen)) : screen,
    debugShowCheckedModeBanner: false,
  ));
  // 애니메이션·비동기 초기화가 도는 화면이 있어 settle 대신 고정 프레임을 돌린다
  // (repeat 애니메이션이 있으면 pumpAndSettle이 타임아웃난다).
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 400));

  final err = tester.takeException();
  if (err != null) {
    final text = err.toString();
    // RenderFlex 오버플로는 예외로 올라오므로 구분해서 표기한다.
    problems.add(text.contains('overflowed') ? '레이아웃 오버플로: $text' : '렌더 예외: $text');
  }
  return problems;
}

void main() {
  setUpAll(() {
    // 폰트 네트워크 페치 차단 — 테스트에서 HTTP 400이 나는 것을 막는다.
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  // 인자 없이 열리는 화면들(기본값 보유). 앱에서 실제로 이렇게 열린다.
  final screens = <String, Widget Function()>{
    'OnboardingScreen': () => const OnboardingScreen(),
    'LoginScreen': () => const LoginScreen(),
    'HonbulHomeScreen': () => const HonbulHomeScreen(),
    'HomeScreen': () => const HomeScreen(),
    'MapScreen': () => const MapScreen(),
    'QuestTabScreen': () => const QuestTabScreen(),
    'DexScreen': () => const DexScreen(),
    'ProfileScreen': () => const ProfileScreen(),
    'PlaceDetailScreen': () => const PlaceDetailScreen(),
    'CreateScenarioScreen': () => const CreateScenarioScreen(),
    'LocationVerifyScreen': () => const LocationVerifyScreen(),
    'ArSearchScreen': () => const ArSearchScreen(
          placeName: '경복궁',
          order: '근정전 처마를 찾아 담거라',
          hints: ['처마 끝을 보거라', '해 지는 쪽이니라'],
          collected: 2,
          total: 5,
        ),
    'QuestJourneyScreen': () => const QuestJourneyScreen(),
    'QuestPlayScreen': () => QuestPlayScreen(node: _node()),
  };

  for (final entry in screens.entries) {
    group(entry.key, () {
      final pending = _pendingRework[entry.key];
      for (final size in _sizes.entries) {
        testWidgets(
          pending == null
              ? '${size.key} 에서 예외·오버플로 없이 그려진다'
              : '${size.key} 에서 예외·오버플로 없이 그려진다  [보류: $pending]',
          (tester) async {
            final problems = await _render(tester, entry.value(), size.value,
                needsShell: _tabBodies.contains(entry.key));
            expect(problems, isEmpty, reason: '${entry.key} @ ${size.key}\n${problems.join('\n')}');
          },
          skip: pending != null,
        );
      }
    });
  }
}
