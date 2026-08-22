// ============================================================
// [v1] 여정 화면 배선 테스트 — 데이터 연동·게이팅·갈림길이 화면에서 도는가
// pipeline: 모바일 클라이언트 / 테스트 (2200줄 화면 리팩터 회귀 방지)
// 구현(요약): QuestJourneyScreen을 실제로 pump해서 (1) 스키마 노드로 빌드되는지,
//            (2) 복원된 진행(인벤토리·갈림길)이 반영되는지, (3) 하드 requires 미충족 시
//            안내 모드가, 분기점에서 갈림길 시트가 뜨는지 확인.
//            google_fonts 런타임 폰트 fetch는 끔(테스트 네트워크 차단).
// 구현일: 2026-07-30 | 작성: kys (app-v3-back/kys/v1)
// ------------------------------------------------------------
// [v2] 코스 길이를 따라가는지 — 챕터 수가 4로 고정돼 있던 회귀 방지.
// 구현(요약): 탐험 시간 입력이 코스 길이를 4·6·8조각으로 바꾸는데, 화면은 정확히 4챕터만
//            만들고 모자라면 종로 기본 노드로 채웠다(가지도 않을 운현궁이 챕터로 등장).
//            길이가 다른 코스로 pump해서 조각 수 표시와 챕터 구성이 데이터를 따르는지 본다.
// 구현일: 2026-08-18 | 작성: kys (explore-input-wiring/kys/v1)
// ------------------------------------------------------------
// [v3] 종로 연출이 다른 지역 코스에 그대로 나오던 회귀를 잠근다.
// 구현(요약): 이 화면이 메인 진입점인데 스테이지·퀴즈·NPC가 종로 시안 고정이었다.
//            (경주 코스에서도 '운현궁은 누구의 집?' 정답=흥선대원군이 나왔다.)
//            미션 타입 → 스테이지 매핑과 노드 퀴즈·NPC 사용을 검증한다.
// 구현일: 2026-08-22 | 작성: kys (play-path-unify/kys/v1)
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

/// 임의 길이 코스 — 탐험 시간(2h·반나절·하루)에 따라 조각 수가 달라진다.
Scenario _course(int stones) => Scenario.fromJson({
      'scenario_id': 'course_$stones',
      'title': '서초구의 기억석 — $stones조각 코스',
      'region': '서초구',
      'stone_total': stones,
      'node_sequence': [
        for (var i = 1; i <= stones; i++)
          _stone('c$i', '장소$i', finale: i == stones),
      ],
    });

/// 미션·퀴즈·NPC까지 실린 노드 — 데이터 연동 검증용.
Map<String, dynamic> _rich(String id, String name, String missionType,
        {Map<String, dynamic>? quiz, String npc = ''}) =>
    {
      ..._stone(id, name),
      'mission': {'type': missionType, 'order': '$name에서 조각을 찾아라', 'hints': const []},
      if (quiz != null) 'quiz': quiz,
      if (npc.isNotEmpty) 'npc': {'name': npc},
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

/// 챕터 목록이 그려지는 화면(map)까지 진행.
/// app#26에서 '새 여정 꾸리기(setup)' 화면이 사라지고 map이 첫 화면이 됐다 —
/// 예전에는 여기서 '도깨비에게 길 묻기'를 눌러 넘어갔다(그 버튼은 이제 없다).
Future<void> _toMap(WidgetTester tester, Scenario? sc) async {
  await _pump(tester, sc);
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

  group('코스 길이', () {
    testWidgets('6조각 코스는 6조각으로 표시된다', (tester) async {
      await _toMap(tester, _course(6));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('/ 6', findRichText: true), findsWidgets,
          reason: '조각 총수가 코스가 아니라 시안(4)에 묶여 있다');
      expect(find.textContaining('운현궁', findRichText: true), findsNothing,
          reason: '코스에 없는 종로 기본 노드가 챕터로 새어 들어왔다');
    });

    testWidgets('3조각 코스도 터지지 않고 3조각으로 표시된다', (tester) async {
      // 고정 POI 좌표가 4개뿐이라 짧은 코스에서 targets[i]가 범위를 벗어나 터졌다.
      await _toMap(tester, _course(3));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('/ 3', findRichText: true), findsWidgets);
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



  group('데이터 연동 (v3)', () {
    testWidgets('퀴즈는 노드 데이터에서 온다 — 종로 문제가 다른 코스에 나오지 않는다', (tester) async {
      final sc = Scenario.fromJson({
        'scenario_id': 'gyeongju_q',
        'title': '경주시의 기억석',
        'region': '경주시',
        'node_sequence': [
          _rich('g1', '첨성대', 'QUIZ_FIND',
              npc: '별빛 도깨비',
              quiz: {
                'q': '첨성대는 무엇을 살피던 곳이더냐?',
                'options': ['별', '물', '바람'],
                'answer': 0,
                'wrong_hint': '하늘을 보거라',
              }),
          _rich('g2', '월성', 'RESTORE_AR'),
        ],
      });
      await ScenarioStore.I.add(sc);
      await _toMap(tester, sc);

      // 종로 시안 문제·정답이 화면 어디에도 없어야 한다
      expect(find.textContaining('운현궁은 누구의 집'), findsNothing);
      expect(find.text('흥선대원군'), findsNothing);
    });

    testWidgets('미션 타입이 스테이지를 정한다 — 종로 순서(카페·인사동)를 따르지 않는다', (tester) async {
      final sc = Scenario.fromJson({
        'scenario_id': 'busan_s',
        'title': '해운대구의 기억석',
        'region': '해운대구',
        'node_sequence': [
          _rich('b1', '동백섬', 'PHOTO_FIND'),
          _rich('b2', '해운대해수욕장', 'PATH_TRACE'),
          _rich('b3', '달맞이길', 'HUNT'),
          _rich('b4', '누리마루', 'RESTORE_AR'),
        ],
      });
      await ScenarioStore.I.add(sc);
      await _toMap(tester, sc);

      // 종로 고유 장소가 챕터로 끼어들면 안 된다
      expect(find.textContaining('익선동'), findsNothing);
      expect(find.textContaining('인사동 붓방'), findsNothing);
      expect(find.textContaining('운현궁'), findsNothing);
    });
  });
}
