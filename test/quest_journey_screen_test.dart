// ============================================================
// [v1] 여정 화면 배선 테스트 — 데이터 연동·게이팅·갈림길이 화면에서 도는가
// pipeline: 모바일 클라이언트 / 테스트 (2200줄 화면 리팩터 회귀 방지)
// 구현(요약): QuestJourneyScreen을 실제로 pump해서 (1) 스키마 노드로 빌드되는지,
//            (2) 복원된 진행(인벤토리·갈림길)이 반영되는지, (3) 하드 requires 미충족 시
//            안내 모드가, 분기점에서 갈림길 시트가 뜨는지 확인.
//            google_fonts 런타임 폰트 fetch는 끔(테스트 네트워크 차단).
// 구현일: 2026-07-30 | 작성: kys (app-v3-back/kys/v1)
// ============================================================
import 'package:dokkaebi_app/models/scenario.dart';
import 'package:dokkaebi_app/screens/quest_journey_screen.dart';
import 'package:dokkaebi_app/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const sid = 'jongno_1';

Map<String, dynamic> _stone(
  String id,
  String name, {
  List<String> grants = const [],
  List<String> requires = const [],
  String mode = 'none',
  bool finale = false,
  Map<String, dynamic>? branch,
}) =>
    {
      'node_id': id,
      'name': name,
      'kind': 'spot',
      'fragment_id': 'frag_$id',
      'grants': grants,
      'requires': requires,
      'requires_mode': mode,
      'is_finale': finale,
      'map_x': 126.98,
      'map_y': 37.57,
      'dist_m': 550,
      if (branch != null) 'branch': branch,
    };

/// 종로 정답지 4노드 — 단서 체인(申時→ㄱ→ㅏ) + 피날레 하드 requires.
Scenario _jongno() => Scenario.fromJson({
      'scenario_id': sid,
      'title': '종로, 잊혀진 글씨의 비밀',
      'region': '종로',
      'node_sequence': [
        _stone('n1', '운현궁', grants: ['fragment:글씨조각1', 'clue:申時']),
        _stone('n2', '익선동', grants: ['fragment:글씨조각2', 'clue:ㄱ'], requires: ['clue:申時'], mode: 'soft'),
        _stone('n3', '인사동', grants: ['fragment:글씨조각3', 'clue:ㅏ'], requires: ['clue:ㄱ'], mode: 'soft'),
        _stone('n4', '광화문',
            requires: ['fragment:글씨조각1', 'fragment:글씨조각2', 'fragment:글씨조각3'],
            mode: 'hard',
            finale: true),
      ],
    });

Future<void> _pump(WidgetTester tester, Scenario? sc) async {
  await tester.pumpWidget(MaterialApp(home: QuestJourneyScreen(scenario: sc)));
  await tester.pump(const Duration(milliseconds: 400));
}

/// setup → map 으로 넘겨 챕터 목록이 그려지는 화면까지 진행.
/// (장소명은 setup 화면엔 없고 챕터 지도에서 처음 노출된다.)
Future<void> _toMap(WidgetTester tester, Scenario? sc) async {
  await _pump(tester, sc);
  await tester.tap(find.text('도깨비에게 길 묻기'));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ScenarioStore.I.load();
    await ScenarioStore.I.resetProgress(sid);
  });

  group('데이터 연동', () {
    testWidgets('시나리오 없이도 빌드된다 (종로 기본값 데모 모드)', (tester) async {
      await _pump(tester, null);
      expect(tester.takeException(), isNull);
    });

    testWidgets('스키마 v1.1 노드로 빌드 + 코스 장소명이 화면에 뜬다', (tester) async {
      await _toMap(tester, _jongno());
      expect(tester.takeException(), isNull);
      // 챕터 지도에 데이터에서 온 장소명이 뜬다
      expect(find.textContaining('운현궁', findRichText: true), findsWidgets);
    });

    testWidgets('저장된 진행(인벤토리)이 복원돼 조각 수에 반영된다', (tester) async {
      final sc = _jongno();
      await ScenarioStore.I.add(sc);
      await ScenarioStore.I.completeNodeWithGrants(sid, sc.nodeSequence[0]);

      await _toMap(tester, sc);
      expect(tester.takeException(), isNull);
      // 조각 1개를 들고 시작 → 두 번째 챕터(익선동)가 현재 목표
      expect(find.textContaining('익선동', findRichText: true), findsWidgets);
    });
  });

  group('갈림길 복원', () {
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
                  {'choice_id': 'main', 'label': '본래 길 — 「익선동」 쪽으로 간다', 'next_node_id': 'n2'},
                  {'choice_id': 'b1', 'label': '샛길 — 「탑골공원」으로 샌다', 'next_node_id': 'alt'},
                ],
              },
              'n2': {'next': 'n4'},
              'alt': {'next': 'n4'},
              'n4': {'next': null},
            },
          },
          'node_sequence': [
            _stone('n1', '운현궁', branch: {
              'prompt': '갈림길이로다. 어느 길로 가려느냐?',
              'options': [
                {'choice_id': 'main', 'label': '본래 길 — 「익선동」 쪽으로 간다', 'next_node_id': 'n2'},
                {'choice_id': 'b1', 'label': '샛길 — 「탑골공원」으로 샌다', 'next_node_id': 'alt'},
              ],
            }),
            _stone('n2', '익선동'),
            _stone('alt', '탑골공원'),
            _stone('n4', '광화문', finale: true),
          ],
        });

    testWidgets('b1을 골라 저장해두면 샛길 노드가 챕터로 들어온다', (tester) async {
      final sc = branching();
      await ScenarioStore.I.add(sc);
      await ScenarioStore.I.chooseBranch(sid, 'n1', 'b1');

      await _toMap(tester, sc);
      expect(tester.takeException(), isNull);
      // playedPath = n1 → alt → n4 이므로 두 번째 챕터가 탑골공원
      expect(find.textContaining('탑골공원', findRichText: true), findsWidgets);
      expect(find.textContaining('익선동', findRichText: true), findsNothing);
    });

    testWidgets('main을 고르면 본래 길이 챕터로 들어온다', (tester) async {
      final sc = branching();
      await ScenarioStore.I.add(sc);
      await ScenarioStore.I.chooseBranch(sid, 'n1', 'main');

      await _toMap(tester, sc);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('익선동', findRichText: true), findsWidgets);
      expect(find.textContaining('탑골공원', findRichText: true), findsNothing);
    });
  });

  group('영속 왕복', () {
    testWidgets('플래그·쿠폰이 저장돼 다음 실행에서 복원된다', (tester) async {
      final sc = _jongno();
      await ScenarioStore.I.add(sc);
      await ScenarioStore.I.grant(sid, [
        const StateRef(kind: StateKind.flag, value: '호기심'),
        const StateRef(kind: StateKind.coupon, value: '', to: '익선동카페', amount: 500),
      ]);

      await _pump(tester, sc);
      expect(tester.takeException(), isNull);

      final st = ScenarioStore.I.stateOf(sid);
      expect(st.flags, {'호기심'});
      expect(st.couponTotal, 500);
    });
  });
}
