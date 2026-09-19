// ============================================================
// [v1] 코스 허브 배선 테스트 — 경로·상태 그래프·게이팅 표시
// pipeline: 모바일 클라이언트 / 테스트 (코스 허브 상태 연동 회귀 방지)
// 구현(요약): ScenarioScreen을 pump해서 (1) playedPath 기준으로 노드가 그려지는지,
//            (2) 단서함·성향 칩이 상태 그래프에서 오는지, (3) 조각 미완 시 피날레 잠금
//            안내가 뜨는지, (4) 하드 requires 노드 탭 → 차단이 아니라 안내 모드인지 확인.
// 구현일: 2026-07-30 | 작성: kys (app-v3-back/kys/v1)
// ------------------------------------------------------------
// [v2] 전 조각 복원 배너(B11) — "종로의 기억" 고정 문구 대신 코스 지역명, 지역명이 없으면 지역을 말하지 않는다.
// 구현일: 2026-09-13 | 작성: ljs (jongno-hardcode-cleanup/ljs/v1)
// ------------------------------------------------------------
// [v3] 장소 누르기(C2) — 끝낸 장소는 요약만, 나머지는 코스 진행 화면을 그 장소부터(장소 단위 화면으로 새지 않음).
// 구현일: 2026-09-17 | 작성: ljs (play-screen-sync/ljs/v1)
// ------------------------------------------------------------
// [v4] 단서는 퀴즈가 쓰는 귀띔만 — 픽스처의 익선동을 퀴즈(S3)로, 퀴즈에 안 쓰이는 단서는 단서함에서 숨는지.
// 구현일: 2026-09-19 | 작성: ljs (quiz-clue/ljs/v1)
// ============================================================
import 'package:dokkaebi_app/models/scenario.dart';
import 'package:dokkaebi_app/screens/quest_journey_screen.dart';
import 'package:dokkaebi_app/screens/quest_play_screen.dart';
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
  bool quiz = false,
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
      if (quiz) ...{
        'strategy': ['S3_RIDDLE_UNLOCK'],
        'quiz': {'q': '?', 'options': ['가', '나', '다', '라'], 'answer': 1},
      },
    };

Scenario _jongno() => Scenario.fromJson({
      'scenario_id': sid,
      'title': '종로, 잊혀진 글씨의 비밀',
      'region': '종로',
      'node_sequence': [
        _n('n1', '운현궁', grants: ['fragment:글씨조각1', 'clue:申時']),
        // 익선동은 퀴즈 — 운현궁의 申時가 그 귀띔. 익선동이 주는 ㄱ은 어느 퀴즈에도 안 쓰인다.
        _n('n2', '익선동', grants: ['fragment:글씨조각2', 'clue:ㄱ'], requires: ['clue:申時'], mode: 'soft', quiz: true),
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

  testWidgets("'모은 것'의 기억석 조각은 식별자가 아니라 '첫째 조각 · 장소'로 부른다", (tester) async {
    final sc = Scenario.fromJson({
      'scenario_id': 'gwanak_labels',
      'title': '관악구의 기억석',
      'region': '관악구',
      'node_sequence': [
        {..._n('g1', '자매공원'), 'fragment_id': '관악구_stone_1of2', 'stone_no': 1},
        {..._n('g2', '관악산', finale: true), 'fragment_id': '관악구_stone_2of2', 'stone_no': 2},
      ],
    });
    await ScenarioStore.I.add(sc);
    await ScenarioStore.I.completeNodeWithGrants(sc.scenarioId, sc.nodeSequence[0]);

    await _pump(tester, sc);
    expect(tester.takeException(), isNull);
    expect(find.text('첫째 조각 · 자매공원'), findsOneWidget);
    expect(find.text('관악구_stone_1of2'), findsNothing);
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

  testWidgets('퀴즈에 안 쓰이는 단서는 단서함에 없다', (tester) async {
    final sc = _jongno();
    await ScenarioStore.I.add(sc);
    await ScenarioStore.I.completeNodeWithGrants(sid, sc.nodeSequence[0]);
    await ScenarioStore.I.completeNodeWithGrants(sid, sc.nodeSequence[1]);

    await _pump(tester, sc);
    expect(tester.takeException(), isNull);
    expect(sc.quizClues, {'申時'});
    expect(find.text('申時'), findsWidgets);
    expect(find.text('ㄱ'), findsNothing, reason: '어느 퀴즈도 쓰지 않는 단서');
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

    // [v2] 갈림길은 대화 안에서 고른다(ai#24 개편) — 노드를 눌렀을 때 시트가 먼저 뜨면
    //      도깨비가 갈림길을 모른 채 말하게 되고, 선택 축이 둘로 갈린다.
    testWidgets('갈림길 노드를 눌러도 시트가 먼저 뜨지 않는다 — 대화가 길을 묻는다', (tester) async {
      final sc = branching();
      await ScenarioStore.I.add(sc);
      await _pump(tester, sc);

      await tester.tap(_rowText('운현궁'));
      await _settle(tester);

      // 시트 대신 플레이(대화) 화면으로 들어간다.
      expect(find.textContaining('어느 길로 가려느냐'), findsNothing);
      expect(ScenarioStore.I.choicesOf(sid), isEmpty);
    });

    testWidgets('갈래가 정해지면 동선이 그 길로 바뀐다', (tester) async {
      final sc = branching();
      await ScenarioStore.I.add(sc);
      // 대화에서 'b1'을 고르면 플레이 화면이 이 값을 저장한다(그 뒤 동작을 검증).
      await ScenarioStore.I.chooseBranch(sid, 'n1', 'b1');
      await _pump(tester, sc);

      expect(ScenarioStore.I.choicesOf(sid), {'n1': 'b1'});
      expect(find.text('탑골공원'), findsWidgets);
      expect(find.text('익선동'), findsNothing);
    });
  });

  // 계획 B11 — 전 조각 복원 배너가 어느 코스든 "종로의 기억이 되살아났다"였다.
  group('복원 배너', () {
    Scenario restored(String region) => Scenario.fromJson({
          'scenario_id': 'restored_course',
          'title': '기억석 코스',
          'region': region,
          'node_sequence': [_n('r1', '첨성대'), _n('r2', '월성', finale: true)],
        });

    Future<void> completeAll(Scenario sc) async {
      await ScenarioStore.I.add(sc);
      for (final n in sc.nodeSequence) {
        await ScenarioStore.I.completeNodeWithGrants(sc.scenarioId, n);
      }
    }

    testWidgets('조각을 다 모으면 그 코스 지역명으로 복원을 알린다', (tester) async {
      final sc = restored('경주시');
      await completeAll(sc);
      await _pump(tester, sc);

      expect(find.text('기억석 복원 완료 — 경주시의 기억이 되살아났다.'), findsOneWidget);
      expect(find.textContaining('종로의 기억'), findsNothing);
    });

    testWidgets('지역명이 비어 있으면 지역을 말하지 않는다', (tester) async {
      final sc = restored('');
      await completeAll(sc);
      await _pump(tester, sc);

      expect(find.text('기억석 복원 완료 — 잊혀진 기억이 되살아났다.'), findsOneWidget);
    });
  });

  // C2 — 코스 상세에서 누른 장소가 코스 진행 화면과 어긋나지 않게 열린다.
  // 예전엔 지금 차례인 장소만 코스 진행 화면이고, 나머지는 따로 노는 장소 단위 화면으로 갔다.
  group('장소 누르기', () {
    testWidgets('끝낸 장소를 누르면 다시 플레이하지 않고 얻은 것만 보여준다', (tester) async {
      final sc = _jongno();
      await ScenarioStore.I.add(sc);
      await ScenarioStore.I.completeNodeWithGrants(sid, sc.nodeSequence[0]);
      await _pump(tester, sc);

      await tester.tap(_rowText('운현궁'));
      await _settle(tester);

      expect(find.text('이미 되찾은 기억'), findsOneWidget);
      expect(find.text('✓ 단서 「申時」'), findsOneWidget);
      expect(find.byType(QuestJourneyScreen), findsNothing);
      expect(find.byType(QuestPlayScreen), findsNothing);
    });

    testWidgets('아직 차례가 아닌 장소를 누르면 코스 진행 화면이 그 장소부터 열린다', (tester) async {
      final sc = _jongno();
      await ScenarioStore.I.add(sc);
      await _pump(tester, sc);

      await tester.tap(_rowText('익선동')); // 지금 차례는 운현궁
      await _settle(tester);

      expect(find.byType(QuestPlayScreen), findsNothing);
      final journey = tester.widget<QuestJourneyScreen>(find.byType(QuestJourneyScreen));
      expect(journey.startNodeId, 'n2');
    });

    testWidgets('막힌 피날레를 누르면 코스 진행 화면을 열지 않고 안내만 한다', (tester) async {
      final sc = _jongno();
      await ScenarioStore.I.add(sc);
      await _pump(tester, sc);

      await tester.tap(_rowText('광화문'));
      await _settle(tester);

      expect(find.byType(QuestJourneyScreen), findsNothing);
      expect(find.text('진행판으로'), findsOneWidget);
    });
  });
}
