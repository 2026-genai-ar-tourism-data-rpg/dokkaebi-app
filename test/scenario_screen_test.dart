// ============================================================
// [v1] 코스 허브 배선 테스트 — 경로·상태 그래프·게이팅 표시
// pipeline: 모바일 클라이언트 / 테스트 (코스 허브 상태 연동 회귀 방지)
// 구현(요약): ScenarioScreen을 pump해서 (1) playedPath 기준으로 노드가 그려지는지,
//            (2) 단서함·성향 칩이 상태 그래프에서 오는지, (3) 조각 미완 시 피날레 잠금
//            안내가 뜨는지, (4) 하드 requires 노드 탭 → 차단이 아니라 안내 모드인지 확인.
// 구현일: 2026-07-30 | 작성: kys (app-v3-back/kys/v1)
// ============================================================
import 'package:dokkaebi_app/models/scenario.dart';
import 'package:dokkaebi_app/screens/scenario_screen.dart';
import 'package:dokkaebi_app/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const sid = 'jongno_1';

Map<String, dynamic> _n(
  String id,
  String name, {
  List<String> grants = const [],
  List<String> requires = const [],
  String mode = 'none',
  bool finale = false,
  String kind = 'spot',
  Map<String, dynamic>? branch,
}) =>
    {
      'node_id': id,
      'name': name,
      'kind': kind,
      'fragment_id': kind == 'spot' ? 'frag_$id' : '',
      'grants': grants,
      'requires': requires,
      'requires_mode': mode,
      'is_finale': finale,
      'map_x': 126.98,
      'map_y': 37.57,
      'dist_m': 500,
      if (branch != null) 'branch': branch,
    };

Scenario _jongno() => Scenario.fromJson({
      'scenario_id': sid,
      'title': '종로, 잊혀진 글씨의 비밀',
      'region': '종로',
      'node_sequence': [
        _n('n1', '운현궁', grants: ['fragment:글씨조각1', 'clue:申時']),
        _n('n2', '익선동', grants: ['fragment:글씨조각2', 'clue:ㄱ'], requires: ['clue:申時'], mode: 'soft'),
        _n('n4', '광화문',
            requires: ['fragment:글씨조각1', 'fragment:글씨조각2'], mode: 'hard', finale: true),
      ],
    });

/// 기본 테스트 뷰포트(800x600)에선 노드 리스트가 화면 밖이라 빌드조차 안 된다.
/// 코스 허브 전체가 한 번에 올라오도록 세로를 키워 pump.
Future<void> _pump(WidgetTester tester, Scenario sc) async {
  await tester.binding.setSurfaceSize(const Size(520, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: ScenarioScreen(scenario: sc)));
  await tester.pump(const Duration(milliseconds: 400));
}

/// 노드 리스트 행의 제목 텍스트만 집는다.
/// 같은 장소명이 지도 핀(9.0)·다음목표 CTA(20.0)에도 나오므로 행 크기(15.5)로 특정한다.
Finder _rowText(String name) => find.byWidgetPredicate((w) =>
    w is Text && w.data == name && w.style?.fontSize == 15.5);

/// 동선 지도의 맥동 링이 계속 repeat 하므로 pumpAndSettle은 영원히 안 끝난다.
/// 바텀시트 전환이 끝날 만큼만 고정 프레임을 돌린다.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ScenarioStore.I.load();
    await ScenarioStore.I.resetProgress(sid);
  });

  testWidgets('경로상 노드가 모두 그려진다', (tester) async {
    final sc = _jongno();
    await ScenarioStore.I.add(sc);
    await _pump(tester, sc);

    expect(tester.takeException(), isNull);
    expect(find.text('운현궁'), findsWidgets);
    expect(find.text('익선동'), findsWidgets);
    expect(find.text('광화문'), findsWidgets);
  });

  testWidgets('단서함·성향 칩이 상태 그래프에서 온다', (tester) async {
    final sc = _jongno();
    await ScenarioStore.I.add(sc);
    await ScenarioStore.I.completeNodeWithGrants(sid, sc.nodeSequence[0]);
    await ScenarioStore.I.grant(sid, [const StateRef(kind: StateKind.flag, value: '호기심')]);

    await _pump(tester, sc);
    expect(tester.takeException(), isNull);
    expect(find.text('단서함'), findsOneWidget);
    expect(find.text('申時'), findsWidgets); // 단서 칩
    expect(find.text('호기심'), findsWidgets); // 성향 칩
    expect(find.textContaining('성향'), findsWidgets);
  });

  testWidgets('조각이 덜 모이면 피날레 잠금 안내가 뜬다', (tester) async {
    final sc = _jongno();
    await ScenarioStore.I.add(sc);
    await ScenarioStore.I.completeNodeWithGrants(sid, sc.nodeSequence[0]); // 1/2

    await _pump(tester, sc);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('피날레는 조각이 다 모여야'), findsOneWidget);
    // 피날레 requires는 조각1·조각2 → 조각1만 있으니 1개 남음
    // (stoneTotal은 피날레 노드 자신도 세므로 그걸로 계산하면 안 된다)
    expect(find.textContaining('1조각 남았다'), findsOneWidget);
  });

  testWidgets('조각을 다 모으면 잠금 안내가 사라진다', (tester) async {
    final sc = _jongno();
    await ScenarioStore.I.add(sc);
    await ScenarioStore.I.completeNodeWithGrants(sid, sc.nodeSequence[0]);
    await ScenarioStore.I.completeNodeWithGrants(sid, sc.nodeSequence[1]);

    await _pump(tester, sc);
    expect(find.textContaining('피날레는 조각이 다 모여야'), findsNothing);
  });

  testWidgets('하드 requires 미충족 노드를 눌러도 차단이 아니라 안내 모드', (tester) async {
    final sc = _jongno();
    await ScenarioStore.I.add(sc);

    await _pump(tester, sc);
    // 피날레(광화문) 노드 행을 탭 — 조각 0개
    await tester.tap(_rowText('광화문'));
    await _settle(tester);

    // 안내 시트: 획득처를 짚어주는 문구 + 남은 것 칩
    expect(find.text('길을 짚어 주마'), findsOneWidget);
    expect(find.textContaining('얻어 오거라'), findsOneWidget);
    expect(find.textContaining('들러야 할 곳'), findsOneWidget);
    // 플레이 화면으로 넘어가지 않았다
    expect(find.text('진행판으로'), findsOneWidget);
  });

  testWidgets('부분 스킵이면 가진 것을 인정한다 (D2)', (tester) async {
    final sc = _jongno();
    await ScenarioStore.I.add(sc);
    await ScenarioStore.I.completeNodeWithGrants(sid, sc.nodeSequence[0]); // 조각1만

    await _pump(tester, sc);
    await tester.tap(_rowText('광화문'));
    await _settle(tester);

    expect(find.text('아직 이르니라'), findsOneWidget);
    expect(find.textContaining('잘 챘구나'), findsOneWidget);
    expect(find.text('이미 지닌 것'), findsOneWidget);
  });

  group('갈림길', () {
    Scenario branching() => Scenario.fromJson({
          'scenario_id': sid,
          'title': 't',
          'region': '종로',
          'is_branching': true,
          'route_tree': {
            'entry_node_id': 'n1',
            'branch_points': ['n1'],
            'nodes': {
              'n1': {
                'next': 'n2',
                'choices': [
                  {'choice_id': 'main', 'label': '본래 길 — 익선동', 'next_node_id': 'n2'},
                  {'choice_id': 'b1', 'label': '샛길 — 탑골공원', 'next_node_id': 'alt'},
                ],
              },
              'n2': {'next': 'n4'},
              'alt': {'next': 'n4'},
              'n4': {'next': null},
            },
          },
          'node_sequence': [
            _n('n1', '운현궁', branch: {
              'prompt': '갈림길이로다. 어느 길로 가려느냐?',
              'options': [
                {'choice_id': 'main', 'label': '본래 길 — 익선동', 'next_node_id': 'n2'},
                {'choice_id': 'b1', 'label': '샛길 — 탑골공원', 'next_node_id': 'alt'},
              ],
            }),
            _n('n2', '익선동'),
            _n('alt', '탑골공원'),
            _n('n4', '광화문', finale: true),
          ],
        });

    testWidgets('미선택이면 기본 갈래만 목록에 뜬다', (tester) async {
      final sc = branching();
      await ScenarioStore.I.add(sc);
      await _pump(tester, sc);

      expect(find.text('익선동'), findsWidgets);
      expect(find.text('탑골공원'), findsNothing);
      expect(find.text('갈림길'), findsWidgets); // 헤더 배지
    });

    testWidgets('갈림길 노드를 누르면 선택 시트가 뜨고, 고르면 그 갈래로 바뀐다', (tester) async {
      final sc = branching();
      await ScenarioStore.I.add(sc);
      await _pump(tester, sc);

      await tester.tap(_rowText('운현궁'));
      await _settle(tester);
      expect(find.textContaining('어느 길로 가려느냐'), findsOneWidget);

      await tester.tap(find.text('샛길 — 탑골공원').last);
      await _settle(tester);

      expect(ScenarioStore.I.choicesOf(sid), {'n1': 'b1'});
      expect(find.text('탑골공원'), findsWidgets);
      expect(find.text('익선동'), findsNothing);
    });
  });
}
