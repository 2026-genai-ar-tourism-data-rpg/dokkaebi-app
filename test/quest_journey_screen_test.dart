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
// ------------------------------------------------------------
// [v4] 이동 단계 실제 GPS 도착 인증 — 가짜 위치·가짜 서버로 분기를 잠근다.
// 구현(요약): 코스가 있으면 걷기 시뮬레이션 대신 서버 판정(verify-location)을 통과해야 소환된다.
//            통과·반경 밖·권한 영구 거부·서버 연결 실패·좌표 없는 장소(확인 없이 진행)·이미 인증한
//            장소·개발자 옵션(장소 좌표 전송)·조각 기록 시 재인증 없음·지도 카드 실제 거리를 검증.
//            코스 없는 데모 모드는 시뮬레이션 그대로라 기존 시뮬레이션 테스트는 데모로 옮겼다.
// 구현일: 2026-09-12 | 작성: ljs (mission-strategy-routing/ljs/v1)
// ============================================================
import 'dart:convert';

import 'package:dokkaebi_app/api/api_client.dart';
import 'package:dokkaebi_app/debug_flags.dart';
import 'package:dokkaebi_app/game/location_service.dart';
import 'package:dokkaebi_app/game/run_session.dart';
import 'package:dokkaebi_app/models/scenario.dart';
import 'package:dokkaebi_app/screens/quest_journey_screen.dart';
import 'package:dokkaebi_app/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const sid = 'jongno_1';

/// 가짜 위치 — 실기기 없이 도착 인증 분기를 검증한다(주입 안 하면 플랫폼 채널을 기다린다).
class _StubLocation extends LocationService {
  const _StubLocation(this.result);
  final LocationResult result;

  @override
  Future<LocationResult> current({Duration timeout = const Duration(seconds: 15)}) async => result;
}

/// 노드 좌표(_stone: 37.57, 126.98) 바로 그 자리.
const _atSpot = _StubLocation(LocationResult.ok(37.57, 126.98, 5.0));

/// 위치를 못 읽는 상태 — 도착 인증까지 가지 않는 테스트의 기본값.
const _noFix = _StubLocation(LocationResult.fail(LocationFailure.timeout));

/// 서버 도착 판정 응답(verify-location).
Map<String, dynamic> _verdict({bool verified = true, String? reason}) => {
      'verified': verified,
      'distance_m': verified ? 8 : 312,
      'required_radius_m': 100,
      'state': verified ? 'GPS_VERIFIED' : 'ARRIVED',
      'npc_spawned': verified,
      'reason': reason,
    };

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// 가짜 게임 서버 — run 열기·조회·도착 판정·조각·완료에 응답하고 받은 요청을 기록한다.
class _FakeQuestServer {
  _FakeQuestServer({
    required this.scenarioId,
    Map<String, dynamic>? verdict,
    this.verifiedNodeIds = const [],
    this.openRunStatus = 200,
  }) : verdict = verdict ?? _verdict();

  final String scenarioId;
  final Map<String, dynamic> verdict;
  final List<String> verifiedNodeIds;
  final int openRunStatus;
  final requests = <http.Request>[];

  /// 경로에 [part]가 들어간 요청 수.
  int count(String part) => requests.where((r) => r.url.path.contains(part)).length;

  RunSession session() =>
      RunSession(api: ApiClient(baseUrl: 'http://test', client: MockClient(_handle)));

  Future<http.Response> _handle(http.Request req) async {
    requests.add(req);
    final path = req.url.path;
    final run = {
      'run_id': 'r1',
      'scenario_id': scenarioId,
      'state': 'IN_PROGRESS',
      'verified_node_ids': verifiedNodeIds,
    };
    if (path == '/v1/runs') {
      return openRunStatus == 200 ? _json(run) : http.Response('error', openRunStatus);
    }
    if (path == '/v1/runs/r1') return _json(run);
    if (path.endsWith('/verify-location')) return _json(verdict);
    if (path.endsWith('/collect')) {
      return _json({
        'fragment_id': 'frag',
        'collected': true,
        'already_collected': false,
        'progress': 1,
        'required': 2,
      });
    }
    if (path.endsWith('/complete')) {
      return _json({
        'state': 'REWARDED',
        'exp_gained': 10,
        'already_rewarded': false,
        'progress': 1,
        'required': 2,
      });
    }
    return http.Response('{}', 404);
  }
}

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

/// 위치는 기본으로 "못 읽음" 스텁을 준다 — 코스가 있으면 화면이 실제 GPS를 읽으려 하기 때문.
Future<void> _pump(WidgetTester tester, Scenario? sc,
    {ApiClient? apiClient, RunSession? runSession, LocationService location = _noFix}) async {
  await tester.pumpWidget(MaterialApp(
    home: QuestJourneyScreen(
        scenario: sc, apiClient: apiClient, runSession: runSession, locationService: location),
  ));
  await tester.pump(const Duration(milliseconds: 400));
}

/// 챕터 목록이 그려지는 화면(map)까지 진행.
/// app#26에서 '새 여정 꾸리기(setup)' 화면이 사라지고 map이 첫 화면이 됐다 —
/// 예전에는 여기서 '도깨비에게 길 묻기'를 눌러 넘어갔다(그 버튼은 이제 없다).
Future<void> _toMap(WidgetTester tester, Scenario? sc,
    {ApiClient? apiClient, RunSession? runSession, LocationService location = _noFix}) async {
  await _pump(tester, sc, apiClient: apiClient, runSession: runSession, location: location);
  await tester.pump(const Duration(milliseconds: 500));
}

/// 코스를 저장하고 지도 → 이동 화면을 연 뒤 "GPS 도착 인증"을 누른다(실제 GPS 모드).
Future<void> _tapArrival(WidgetTester tester, Scenario sc, _FakeQuestServer server,
    {ApiClient? apiClient, LocationService location = _atSpot}) async {
  await ScenarioStore.I.add(sc);
  await _toMap(tester, sc, apiClient: apiClient, runSession: server.session(), location: location);
  await tester.tap(find.text('이동 시작 — GPS 추적'));
  await tester.pump(const Duration(milliseconds: 50)); // 이동 화면 진입 + 거리 갱신
  await tester.tap(find.text('GPS 도착 인증'));
  await tester.pump(const Duration(milliseconds: 50)); // 도착 판정 응답
  await tester.pump();
}

/// 챕터 지도 → 이동 → 도착 인증 → 소환 → "말 걸기"까지 실제로 눌러서 진행.
/// 코스가 있으면 실제 GPS 모드(가짜 위치·가짜 서버로 통과), 없으면 데모 시뮬레이션.
Future<void> _toDialogue(WidgetTester tester, Scenario? sc, {ApiClient? apiClient}) async {
  if (sc == null) {
    await _toMap(tester, null, apiClient: apiClient);
    await tester.tap(find.text('이동 시작 — GPS 추적'));
    await tester.pump();
    await tester.tap(find.text('걷기 시작 (GPS 시뮬레이션)'));
    // gpsDist 550 → 48/tick(130ms)씩 감소, 30 이하까지 넉넉히 펌프.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.tap(find.text('GPS 도착 인증'));
    await tester.pump(); // screen='summon', summonPhase='scan'
  } else {
    await _tapArrival(tester, sc, _FakeQuestServer(scenarioId: sc.scenarioId),
        apiClient: apiClient);
  }
  await tester.pump(const Duration(milliseconds: 1600)); // summonTimer(1500ms) → 'appear'
  await tester.tap(find.text('말 걸기'));
  await tester.pump();
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

  // 실기기·시뮬레이터 양쪽에서 "걷기 시작 (GPS 시뮬레이션)"이 탭에 반응하지 않는
  // 현상을 재현·격리하기 위한 테스트 — 입력 주입(합성 터치) 문제인지 위젯 자체
  // 버그인지 UI 탐색 없이 가른다.
  group('GPS 시뮬레이션', () {
    // 코스가 있으면 실제 GPS 모드라 걷기 버튼이 없다 — 시뮬레이션은 데모 모드(코스 없음)에만 남는다.
    testWidgets('이동 시작 → 걷기 시작을 누르면 거리가 줄고 걷는 중으로 바뀐다', (tester) async {
      await _toMap(tester, null);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('이동 시작 — GPS 추적'));
      await tester.pump();
      expect(find.text('걷기 시작 (GPS 시뮬레이션)'), findsOneWidget);

      await tester.tap(find.text('걷기 시작 (GPS 시뮬레이션)'));
      await tester.pump(const Duration(milliseconds: 140));

      expect(find.text('걷는 중…'), findsOneWidget);
    });
  });

  // NPC 이름(_npcName)은 이미 노드 데이터를 쓰는데 말풍선(_npcLines)은 종로 시안
  // "운현궁" 대사가 고정으로 박혀 있었다 — 이름은 맞는데 내용이 딴 지역 얘기였다.
  group('첫 대사 (dialogue)', () {
    Map<String, dynamic> _dialogueNode(String id, String name,
            {String npcDialogue = '', bool finale = false}) =>
        {
          'node_id': id,
          'name': name,
          'kind': 'spot',
          'fragment_id': 'frag_$id',
          'grants': const [],
          'requires': const [],
          'requires_mode': 'none',
          'is_finale': finale,
          'map_x': 129.16,
          'map_y': 35.16,
          'dist_m': 550,
          'npc_dialogue': npcDialogue,
          'mission': {'type': 'RESTORE_AR', 'order': '$name에서 조각을 찾아라', 'hints': const []},
        };

    Scenario _busan() => Scenario.fromJson({
          'scenario_id': 'busan_dialogue_test',
          'title': '해운대구의 기억석',
          'region': '해운대구',
          'node_sequence': [
            _dialogueNode('b1', '동백섬', npcDialogue: '"이곳 동백섬의 기운이 심상치 않구나. 살펴보거라."'),
            _dialogueNode('b2', '해운대해수욕장', finale: true),
          ],
        });

    testWidgets('실제 코스 노드는 AI가 지은 대사를 보여준다 — 운현궁이 아니다', (tester) async {
      await _toDialogue(tester, _busan());
      expect(tester.takeException(), isNull);
      expect(find.textContaining('동백섬의 기운이 심상치 않구나'), findsOneWidget);
      // 말풍선이 고정 종로 대사로 안 돌아갔는지(헤더 라벨 "운현궁 · 첫 번째 기억"은
      // 이 버그와 무관한 별개 하드코딩이라 여기서는 안 건드린다).
      expect(find.textContaining('허허, 운현궁에 발을 들였구나'), findsNothing);
    });

    testWidgets('데모 모드(코스 데이터 없음)는 기존 시안 대사로 폴백한다', (tester) async {
      await _toDialogue(tester, null);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('운현궁에 발을 들였구나'), findsOneWidget);
    });

    // 선택지 자체(A/B/C)·플래그·쿠폰·엔딩 분기는 그대로 유지 — A/B("사연이오?"/"보상은?")를
    // 골랐을 때 NPC의 답변만 dialogueTurn(실제 도깨비 대화 엔진)으로 받아온다.
    testWidgets('선택지 A를 고르면 dialogueTurn이 준 실제 답을 보여준다', (tester) async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/v1/dialogue/turn')) {
          return http.Response(
            jsonEncode({
              'response': '허허, 이곳 동백섬은 옛적 도깨비들이 모여 쉬던 자리였다느니라.',
              'choices': [], 'grants': [], 'done': false,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 200);
      });

      await _toDialogue(tester, _busan(), apiClient: ApiClient(client: client));
      await tester.tap(find.text('"그게 무슨 사연이오?"'));
      await tester.pump(); // _dialogueLoading = true, 선택지 숨김
      await tester.pump(const Duration(milliseconds: 50)); // dialogueTurn 응답 대기

      expect(tester.takeException(), isNull);
      expect(find.textContaining('옛적 도깨비들이 모여 쉬던 자리'), findsOneWidget);
      // 원래 고정 답변(폴백 문구)으로 안 떨어졌는지 확인.
      expect(find.textContaining('마음이 곧은 자로군'), findsNothing);
    });

    testWidgets('dialogueTurn이 실패하면 기존 고정 답변으로 폴백한다', (tester) async {
      final client = MockClient((req) async => http.Response('서버 오류', 500));

      await _toDialogue(tester, _busan(), apiClient: ApiClient(client: client));
      await tester.tap(find.text('"그게 무슨 사연이오?"'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('마음이 곧은 자로군'), findsOneWidget);
    });
  });

  // mission-strategy-routing/ljs/v1 4번 작업 — 사냥 화면이 strategy의 defeat 원자에서
  // 몬스터 이름·마릿수를 가져오는지. 미러링으로 실기기 라이브 확인이 막혀서 대신
  // 자동화로 검증(원인: iPhone 미러링 세션이 멎어 탭이 실기기에 전달되지 않음).
  group('사냥 화면 데이터 연동', () {
    Map<String, dynamic> _huntNode(String id, String name, {bool finale = false}) => {
          'node_id': id,
          'name': name,
          'kind': 'spot',
          'fragment_id': 'frag_$id',
          'grants': const [],
          'requires': const [],
          'requires_mode': 'none',
          'is_finale': finale,
          'map_x': 126.90,
          'map_y': 37.52,
          'dist_m': 400,
          'strategy': const ['S2_HUNT_GATHER'],
          'actions': const [
            {'a': 'defeat', 'object': '성난 물귀신', 'count': [0, 4]},
            {'a': 'tap', 'target': '글씨조각', 'count': [0, 1]},
          ],
          'mission': {'type': 'HUNT', 'order': '$name에서 물귀신을 처치하라', 'hints': const []},
        };

    Scenario _huntCourse() => Scenario.fromJson({
          'scenario_id': 'yeongdeungpo_hunt_test',
          'title': '영등포구의 기억석',
          'region': '영등포구',
          'node_sequence': [
            _huntNode('h1', '한강공원'),
            _huntNode('h2', '여의도', finale: true),
          ],
        });

    testWidgets('defeat 원자의 몬스터 이름·마릿수가 뜬다 — 먹그림자/5 하드코딩 아님', (tester) async {
      await _toDialogue(tester, _huntCourse());

      // C(바로 진행) — dialogueTurn을 안 타는 선택지라 API 스텁 없이 진행 가능.
      await tester.tap(find.text('"그냥 빨리 찾겠소."'));
      await tester.pump();
      expect(find.text('계속 — 지령 받기'), findsOneWidget);
      await tester.tap(find.text('계속 — 지령 받기'));
      await tester.pump();

      expect(find.text('지령 받기 — 사냥 시작'), findsOneWidget);
      await tester.tap(find.text('지령 받기 — 사냥 시작'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('성난 물귀신 처치'), findsOneWidget);
      expect(find.text('먹그림자 처치'), findsNothing);
      expect(find.textContaining('/ 4', findRichText: true), findsOneWidget);
      expect(find.textContaining('/ 5', findRichText: true), findsNothing);
    });
  });

  // mission-strategy-routing/ljs/v1 — 이동 단계를 실제 GPS 도착 인증으로 바꾼 것(계획 0-2).
  group('실제 GPS 도착 인증', () {
    Scenario quizCourse() => Scenario.fromJson({
          'scenario_id': 'gyeongju_arrival',
          'title': '경주시의 기억석',
          'region': '경주시',
          'node_sequence': [
            _rich('q1', '첨성대', 'QUIZ_FIND', quiz: {
              'q': '첨성대는 무엇을 살피던 곳이더냐?',
              'options': ['별', '물', '바람'],
              'answer': 0,
              'wrong_hint': '하늘을 보거라',
            }),
            _rich('q2', '월성', 'RESTORE_AR'),
          ],
        });

    testWidgets('서버 판정을 통과하면 소환으로 넘어간다 — 걷기 시뮬레이션은 없다', (tester) async {
      final sc = quizCourse();
      final server = _FakeQuestServer(scenarioId: sc.scenarioId);
      await ScenarioStore.I.add(sc);
      await _toMap(tester, sc, runSession: server.session(), location: _atSpot);
      await tester.tap(find.text('이동 시작 — GPS 추적'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('걷기 시작 (GPS 시뮬레이션)'), findsNothing);

      await tester.tap(find.text('GPS 도착 인증'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 1600));

      expect(tester.takeException(), isNull);
      expect(server.count('verify-location'), 1);
      expect(find.text('말 걸기'), findsOneWidget);
    });

    testWidgets('반경 밖이면 사유와 다시 확인만 보이고 소환되지 않는다', (tester) async {
      final sc = quizCourse();
      final server = _FakeQuestServer(
          scenarioId: sc.scenarioId, verdict: _verdict(verified: false, reason: 'OUT_OF_RANGE'));
      await _tapArrival(tester, sc, server);
      await tester.pump(const Duration(milliseconds: 1600));

      expect(find.textContaining('312m 떨어져'), findsOneWidget);
      expect(find.text('다시 확인'), findsOneWidget);
      expect(find.text('말 걸기'), findsNothing);
    });

    testWidgets('위치 권한이 영구 거부면 설정 열기를 보여주고 서버에 묻지 않는다', (tester) async {
      final sc = quizCourse();
      final server = _FakeQuestServer(scenarioId: sc.scenarioId);
      await _tapArrival(tester, sc, server,
          location: const _StubLocation(LocationResult.fail(LocationFailure.deniedForever)));

      expect(find.text('설정 열기'), findsOneWidget);
      expect(find.text('다시 확인'), findsOneWidget);
      expect(server.count('verify-location'), 0);
    });

    testWidgets('서버에 연결되지 않으면 다시 확인 때 run부터 다시 연다', (tester) async {
      final sc = quizCourse();
      final server = _FakeQuestServer(scenarioId: sc.scenarioId, openRunStatus: 500);
      await _tapArrival(tester, sc, server);

      expect(find.textContaining('플레이 시작에 실패'), findsOneWidget);
      expect(find.text('다시 확인'), findsOneWidget);
      expect(server.count('verify-location'), 0);
      expect(server.count('/v1/runs'), 2, reason: '화면 진입 때 1번 + 도착 인증 때 다시 열기 1번');
    });

    testWidgets('좌표 없는 장소라고 하면 위치 확인 없이 진행할 수 있다', (tester) async {
      final sc = quizCourse();
      final server = _FakeQuestServer(
          scenarioId: sc.scenarioId,
          verdict: _verdict(verified: false, reason: 'NODE_HAS_NO_COORDS'));
      await _tapArrival(tester, sc, server);
      expect(find.textContaining('서버에 기록되지 않느니라'), findsOneWidget);

      await tester.tap(find.text('위치 확인 없이 진행'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));

      expect(find.text('말 걸기'), findsOneWidget);
    });

    testWidgets('이미 도착 인증한 장소는 다시 묻지 않는다 — 서버 run 기록 기준', (tester) async {
      final sc = quizCourse();
      await ScenarioStore.I.setRunId(sc.scenarioId, 'r1'); // 앱 재시작 후 같은 run을 되살리는 상황
      final server = _FakeQuestServer(scenarioId: sc.scenarioId, verifiedNodeIds: const ['q1']);
      await _tapArrival(tester, sc, server);
      await tester.pump(const Duration(milliseconds: 1600));

      expect(server.count('verify-location'), 0);
      expect(find.text('말 걸기'), findsOneWidget);
    });

    testWidgets('개발자 옵션을 켜면 실제 위치 대신 장소 좌표로 도착 인증을 요청한다', (tester) async {
      DebugFlags.skipGpsVerify = true;
      addTearDown(() => DebugFlags.skipGpsVerify = false);
      final sc = quizCourse();
      final server = _FakeQuestServer(scenarioId: sc.scenarioId);
      await _tapArrival(tester, sc, server,
          location: const _StubLocation(LocationResult.ok(0.0, 0.0, 5.0))); // 실제 위치는 아주 먼 곳

      final verify = server.requests.singleWhere((r) => r.url.path.endsWith('/verify-location'));
      final body = jsonDecode(verify.body) as Map<String, dynamic>;
      expect(body['lat'], 37.57);
      expect(body['lng'], 126.98);
      expect(body.containsKey('accuracy_m'), isFalse);
    });

    testWidgets('조각을 기록할 때는 위치 인증을 다시 요청하지 않는다', (tester) async {
      final sc = quizCourse();
      final server = _FakeQuestServer(scenarioId: sc.scenarioId);
      await _tapArrival(tester, sc, server);
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.tap(find.text('말 걸기'));
      await tester.pump();
      await tester.tap(find.text('"그냥 빨리 찾겠소."'));
      await tester.pump();
      await tester.tap(find.text('계속 — 도깨비의 시험'));
      await tester.pump();
      await tester.tap(find.text('별'));
      await tester.pump();
      await tester.tap(find.text('계속하기'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(server.count('verify-location'), 1, reason: '도착 때 한 번뿐이어야 한다');
      expect(server.count('/collect'), 1);
      expect(server.count('/complete'), 1);
    });

    testWidgets('지도 카드 거리는 코스 출발점이 아니라 지금 위치 기준이다', (tester) async {
      // 노드(37.57, 126.98)에서 북쪽으로 위도 0.01° ≈ 1.1km 떨어진 곳.
      await _toMap(tester, _course(3),
          location: const _StubLocation(LocationResult.ok(37.58, 126.98, 5.0)));

      expect(find.textContaining('까지 1.1km'), findsOneWidget);
      expect(find.textContaining('까지 550m'), findsNothing,
          reason: '코스 출발점 기준 거리(dist_m)가 남아 있다');
    });
  });
}
