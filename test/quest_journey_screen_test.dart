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
// ------------------------------------------------------------
// [v5] 위치 권한이 꺼져 있을 때 — 이미 인증한 장소도 권한은 확인(좌표는 안 읽음), 권한 경고엔
//      설정 열기, 지도 카드는 "위치 설정 필요". 실기기에서 권한을 끄고 같은 장소가 그냥 통과한 회귀.
// 구현일: 2026-09-12 | 작성: ljs (mission-strategy-routing/ljs/v1)
// ------------------------------------------------------------
// [v6] 조각 기록(C1) — 서버 기록이 성공해야 확정·획득 팝업, 5xx는 다시 시도만, 403은 기록 없이 계속,
//      좌표 없는 장소는 기록 시도 안 함, 연타해도 요청 1번, 피날레 기록 실패 시 엔딩으로 안 넘어감.
// 구현일: 2026-09-12 | 작성: ljs (mission-strategy-routing/ljs/v1)
// ------------------------------------------------------------
// [v8] 소환 화면 도깨비 이름표(B13) — 노드 npc 이름이 뜨고 '먹 도깨비 · Lv.7' 고정이 아닌지,
//      npc가 없는 노드는 '먹 도깨비'가 아니라 '도깨비'로 폴백하는지.
// 구현일: 2026-09-12 | 작성: ljs (mission-strategy-routing/ljs/v1)
// ------------------------------------------------------------
// [v7] 조각 획득 팝업(B1·B2) — 종로 시안 고정 문구(「훈(訓)」·1/4·申時·익선동 쿠폰) 대신
//      실제 장소·지역·조각 번호·단서와 서버가 준 보상(경험치·도감·칭호)이 뜨는지,
//      서버에 기록하지 못한 조각은 경험치 대신 그 사실을 알리는지 잠근다.
// 구현일: 2026-09-12 | 작성: ljs (mission-strategy-routing/ljs/v1)
// ------------------------------------------------------------
// [v9] 종로 고정값 걷어내기(B7·B8·B14·C6) — HUD 칭호가 닉네임인지, 예산 없는 코스엔 여비가 안 뜨는지,
//      붓털이 코스에 저장되는지, 퀴즈 정답에 가짜 경험치 태그가 없고 쿠폰은 AI 데이터(correct.coupon)로
//      지급·저장되는지, 발자국 대사가 AI 데이터에서
//      오는지(trailWhisper), 힌트 사다리가 미션에 들어간 순간부터 시간을 세는지.
// 구현일: 2026-09-13 | 작성: ljs (jongno-hardcode-cleanup/ljs/v1)
// ------------------------------------------------------------
// [v10] 퀴즈 귀띔 단서 — 단서를 가져오면 오답 하나가 지워지고 누를 수 없는지, 없으면 어디서 받는지 안내,
//       보상 팝업엔 퀴즈가 쓰는 단서만. 건너뛰기 안내는 이번 퀴즈의 단서만 짚는다.
// 구현일: 2026-09-19 | 작성: ljs (quiz-clue/ljs/v1)
// ------------------------------------------------------------
// [v11] 앞 장소를 끝내고 오면 다음 장소 대화는 선택지부터, 퀴즈는 정답 체크 없이 열리는지(재현 테스트).
// 구현일: 2026-09-19 | 작성: ljs (quiz-reset/ljs/v1)
// ------------------------------------------------------------
// [v12] 쿠폰 보상 제거 — 대화 B·퀴즈 정답이 쿠폰을 주지 않는지. 친밀도 굿 엔딩 — 모자라면 굿 엔딩이
//       잠기고 노멀만 고를 수 있는지, 채우면 굿 엔딩을 고를 수 있는지.
// 구현일: 2026-09-19 | 작성: ljs (coupon-affinity/ljs/v1)
// ============================================================
import 'dart:convert';

import 'package:dokkaebi_app/api/api_client.dart';
import 'package:dokkaebi_app/debug_flags.dart';
import 'package:dokkaebi_app/game/location_service.dart';
import 'package:dokkaebi_app/game/run_session.dart';
import 'package:dokkaebi_app/models/scenario.dart';
import 'package:dokkaebi_app/screens/ar_search_screen.dart';
import 'package:dokkaebi_app/screens/quest_journey_screen.dart';
import 'package:dokkaebi_app/session.dart';
import 'package:dokkaebi_app/store.dart';
import 'package:dokkaebi_app/widgets/memory_sequence_game.dart';
import 'package:dokkaebi_app/widgets/memory_stone_restore.dart';
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

  /// 권한·서비스 확인 — 신호 없음(timeout)은 권한 문제가 아니므로 통과로 본다.
  @override
  Future<LocationFailure?> checkAccess() async =>
      result.failure == LocationFailure.timeout ? null : result.failure;
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
    this.expGained = 10,
    this.dexEntry,
    this.titles = const [],
  }) : verdict = verdict ?? _verdict();

  final String scenarioId;
  final Map<String, dynamic> verdict;
  final List<String> verifiedNodeIds;
  final int openRunStatus;

  /// 노드 완료(complete)가 돌려줄 보상 — 획득 팝업이 이 값을 그대로 보여줘야 한다.
  final int expGained;
  final String? dexEntry;
  final List<String> titles;
  final requests = <http.Request>[];

  /// 조각 기록(collect) 응답 코드 — 테스트 도중 바꿔 "다시 시도" 성공을 흉내낸다.
  int collectStatus = 200;

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
      if (collectStatus == 403) {
        return http.Response(jsonEncode({'message': '먼저 그 자리에 당도해야 하느니라. (GPS 미인증)'}), 403,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (collectStatus != 200) return http.Response('error', collectStatus);
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
        'exp_gained': expGained,
        'already_rewarded': false,
        if (dexEntry != null) 'dex_entry': dexEntry,
        'titles': titles,
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
    {ApiClient? apiClient, RunSession? runSession, LocationService location = _noFix, String? startNodeId}) async {
  await tester.pumpWidget(MaterialApp(
    home: QuestJourneyScreen(
        scenario: sc,
        apiClient: apiClient,
        runSession: runSession,
        locationService: location,
        startNodeId: startNodeId),
  ));
  await tester.pump(const Duration(milliseconds: 400));
}

/// 챕터 목록이 그려지는 화면(map)까지 진행.
/// app#26에서 '새 여정 꾸리기(setup)' 화면이 사라지고 map이 첫 화면이 됐다 —
/// 예전에는 여기서 '도깨비에게 길 묻기'를 눌러 넘어갔다(그 버튼은 이제 없다).
Future<void> _toMap(WidgetTester tester, Scenario? sc,
    {ApiClient? apiClient, RunSession? runSession, LocationService location = _noFix, String? startNodeId}) async {
  await _pump(tester, sc,
      apiClient: apiClient, runSession: runSession, location: location, startNodeId: startNodeId);
  await tester.pump(const Duration(milliseconds: 500));
}

/// 코스를 저장하고 지도 → 이동 화면을 연 뒤 "GPS 도착 인증"을 누른다(실제 GPS 모드).
Future<void> _tapArrival(WidgetTester tester, Scenario sc, _FakeQuestServer server,
    {ApiClient? apiClient, LocationService location = _atSpot, String? startNodeId}) async {
  await ScenarioStore.I.add(sc);
  await _toMap(tester, sc,
      apiClient: apiClient, runSession: server.session(), location: location, startNodeId: startNodeId);
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
      // 첫 챕터 완료 후, 복원된 분기의 다음 장소를 챕터 카드로 확인한다.
      // 지도 장소명은 이제 네이티브 카카오맵 마커라 Flutter Text가 아니다.
      await ScenarioStore.I.completeNodeWithGrants(sid, sc.nodeSequence[0]);

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
      // 첫 챕터 완료 후, 복원된 분기의 다음 장소를 챕터 카드로 확인한다.
      // 지도 장소명은 이제 네이티브 카카오맵 마커라 Flutter Text가 아니다.
      await ScenarioStore.I.completeNodeWithGrants(sid, sc.nodeSequence[0]);

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

  // 실기기 제보 — 이동 화면 지도가 손으로 움직이지 않았다(오버레이 정합 때문에 제스처를 막아 뒀다).
  // 이제 움직일 수 있고, 움직이면 내 위치 따라가기를 끄고 "내 위치"로 되돌린다.
  group('이동 화면 지도 조작', () {
    Future<void> toGpsScreen(WidgetTester tester) async {
      final sc = _course(2);
      await ScenarioStore.I.add(sc);
      await _toMap(tester, sc, location: _atSpot);
      await tester.tap(find.text('이동 시작 — GPS 추적'));
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('지도를 손으로 만지면 따라가기가 꺼지고 «내 위치» 버튼이 나온다', (tester) async {
      await toGpsScreen(tester);
      expect(find.text('내 위치'), findsNothing, reason: '처음엔 내 위치를 따라간다');

      await tester.tapAt(const Offset(40, 300)); // 지도 위(칩·카드·목표 핀을 피한 자리)
      await tester.pump();

      expect(find.text('내 위치'), findsOneWidget);
    });

    testWidgets('«내 위치»를 누르면 다시 따라가기로 돌아간다', (tester) async {
      await toGpsScreen(tester);
      await tester.tapAt(const Offset(40, 300));
      await tester.pump();

      await tester.tap(find.text('내 위치'));
      await tester.pump();

      expect(find.text('내 위치'), findsNothing);
      expect(tester.takeException(), isNull);
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

    testWidgets('선택지 B는 쿠폰 없이 답만 듣는다', (tester) async {
      final sc = _busan();
      final client = MockClient((req) async => http.Response('서버 오류', 500));
      await _toDialogue(tester, sc, apiClient: ApiClient(client: client));

      expect(find.text('보상 듣기'), findsOneWidget);
      expect(find.text('쿠폰+100'), findsNothing);
      await tester.tap(find.text('"보상은 무엇이오?"'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('셈부터 빠르구나'), findsOneWidget);
      expect(find.textContaining('쿠폰'), findsNothing);
      expect(ScenarioStore.I.stateOf(sc.scenarioId).coupons, isEmpty);
      expect(ScenarioStore.I.stateOf(sc.scenarioId).flags, {'실리'}, reason: '성향 플래그는 그대로 남는다');
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

    /// 대화(C) → 지령 → 사냥 화면까지 진행.
    Future<void> toHunt(WidgetTester tester) async {
      await _toDialogue(tester, _huntCourse());
      await tester.tap(find.text('"그냥 빨리 찾겠소."'));
      await tester.pump();
      await tester.tap(find.text('계속 — 지령 받기'));
      await tester.pump();
      await tester.tap(find.text('지령 받기 — 사냥 시작'));
      await tester.pump();
    }

    // 계획 C6 — 힌트 사다리가 미션에 들어간 순간부터 시간을 세야 "멈춰 있으면 힌트1"(idle60)이 제때 열린다.
    testWidgets('힌트 — 사냥 화면에서 60초 멈춰 있다가 힌트 창을 열면 이미 힌트1이 열려 있다', (tester) async {
      await toHunt(tester);
      await tester.pump(const Duration(seconds: 61));

      await tester.tap(find.text('힌트'));
      await tester.pump();

      expect(find.text('"그늘은 해가 드는 반대편이니라."'), findsOneWidget,
          reason: '힌트 창을 연 순간이 아니라 미션에 들어간 순간부터 멈춘 시간을 세야 한다');
      expect(find.textContaining('아직 귀띔할 때가 아니니라'), findsNothing);
    });

    testWidgets('힌트 — 미션에 막 들어와 창을 열면 힌트1은 아직 닫혀 있다', (tester) async {
      await toHunt(tester);

      await tester.tap(find.text('힌트'));
      await tester.pump();

      expect(find.textContaining('아직 귀띔할 때가 아니니라'), findsOneWidget);
    });

    // 계획 B7 — 붓털이 화면 지역 변수라 재진입하면 3개로 돌아가던 것.
    testWidgets('붓털 — 붓털로 힌트를 열면 줄어든 개수가 코스에 저장된다', (tester) async {
      final sc = _huntCourse();
      await toHunt(tester);
      await tester.tap(find.text('힌트'));
      await tester.pump();

      await tester.tap(find.text('붓털 1개로 열기'));
      await tester.pump();

      expect(ScenarioStore.I.brushOf(sc.scenarioId), ScenarioStore.defaultBrush - 1,
          reason: '저장하지 않으면 다시 들어올 때 붓털이 되돌아온다');
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

    // 실기기 재현: 도착 인증 → iOS 설정에서 위치 권한 끔(앱 강제 종료) → 다시 열어 같은 장소 도착 인증
    // → 서버에 인증 기록이 있어 위치를 안 보고 통과했다. 권한은 확인하고, 좌표는 읽지 않는다.
    testWidgets('이미 인증한 장소라도 위치 권한이 막혀 있으면 설정 열기를 보여주고 멈춘다', (tester) async {
      final sc = quizCourse();
      await ScenarioStore.I.setRunId(sc.scenarioId, 'r1'); // 앱이 다시 열려 같은 run을 되살린 상황
      final server = _FakeQuestServer(scenarioId: sc.scenarioId, verifiedNodeIds: const ['q1']);
      await _tapArrival(tester, sc, server,
          location: const _StubLocation(LocationResult.fail(LocationFailure.deniedForever)));
      await tester.pump(const Duration(milliseconds: 1600));

      expect(find.textContaining('위치 권한이 막혀'), findsOneWidget);
      expect(find.text('설정 열기'), findsOneWidget);
      expect(find.text('다시 확인'), findsOneWidget);
      expect(find.text('말 걸기'), findsNothing);
      expect(server.count('verify-location'), 0);
    });

    testWidgets('이미 인증한 장소는 권한만 켜져 있으면 GPS 신호가 없어도 진행한다', (tester) async {
      final sc = quizCourse();
      await ScenarioStore.I.setRunId(sc.scenarioId, 'r1');
      final server = _FakeQuestServer(scenarioId: sc.scenarioId, verifiedNodeIds: const ['q1']);
      await _tapArrival(tester, sc, server, location: _noFix);
      await tester.pump(const Duration(milliseconds: 1600));

      expect(server.count('verify-location'), 0);
      expect(find.text('말 걸기'), findsOneWidget);
    });

    testWidgets('이동 화면에 위치 권한 경고가 뜨면 설정 열기도 함께 보여준다', (tester) async {
      final sc = quizCourse();
      final server = _FakeQuestServer(scenarioId: sc.scenarioId);
      await ScenarioStore.I.add(sc);
      await _toMap(tester, sc,
          runSession: server.session(),
          location: const _StubLocation(LocationResult.fail(LocationFailure.deniedForever)));
      await tester.tap(find.text('이동 시작 — GPS 추적'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('위치 권한이 막혀'), findsOneWidget, reason: '같은 경고가 두 번 뜨면 안 된다');
      expect(find.text('설정 열기'), findsOneWidget,
          reason: '도착 인증을 누르기 전에도 권한 경고에 행동 버튼이 있어야 한다');
    });

    testWidgets('위치 권한이 막혀 있으면 지도 카드에 위치 설정 필요로 보인다', (tester) async {
      await _toMap(tester, _course(3),
          location: const _StubLocation(LocationResult.fail(LocationFailure.deniedForever)));

      expect(find.textContaining('위치 설정 필요'), findsOneWidget);
      expect(find.textContaining('거리 확인 중'), findsNothing);
    });

    // 계획 C1 — 조각은 서버 기록이 성공해야 확정된다(실패하면 공통 팝업으로 멈추고 다시 시도).
    // 소환 화면에서 대화(C) → 시험 → 정답까지 진행해 "계속하기"만 남긴다.
    Future<void> answerQuiz(WidgetTester tester) async {
      await tester.tap(find.text('말 걸기'));
      await tester.pump();
      await tester.tap(find.text('"그냥 빨리 찾겠소."'));
      await tester.pump();
      await tester.tap(find.text('계속 — 도깨비의 시험'));
      await tester.pump();
      await tester.tap(find.text('별'));
      await tester.pump();
    }

    Future<void> toQuizContinue(WidgetTester tester, Scenario sc, _FakeQuestServer server) async {
      await _tapArrival(tester, sc, server);
      await tester.pump(const Duration(milliseconds: 1600));
      await answerQuiz(tester);
    }

    testWidgets('조각 기록 — 서버에 기록되어야 조각이 확정되고 획득 팝업이 뜬다', (tester) async {
      final sc = quizCourse();
      final server = _FakeQuestServer(scenarioId: sc.scenarioId);
      await toQuizContinue(tester, sc, server);

      await tester.tap(find.text('계속하기'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(server.count('/collect'), 1);
      expect(server.count('/complete'), 1);
      expect(find.text('획 득'), findsOneWidget);
      expect(ScenarioStore.I.doneOf(sc.scenarioId), ['q1']);
    });

    testWidgets('조각 기록 — 서버 5xx면 확정하지 않고 다시 시도만 준다, 다시 시도에 성공하면 확정', (tester) async {
      final sc = quizCourse();
      final server = _FakeQuestServer(scenarioId: sc.scenarioId)..collectStatus = 500;
      await toQuizContinue(tester, sc, server);

      await tester.tap(find.text('계속하기'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('조각을 기록하지 못했느니라'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.text('기록 없이 계속'), findsNothing,
          reason: '다시 해볼 만한 실패엔 기록 없이 계속을 주지 않는다');
      expect(find.text('획 득'), findsNothing);
      expect(ScenarioStore.I.doneOf(sc.scenarioId), isEmpty);

      server.collectStatus = 200;
      await tester.tap(find.text('다시 시도'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('획 득'), findsOneWidget);
      expect(ScenarioStore.I.doneOf(sc.scenarioId), ['q1']);
    });

    testWidgets('조각 기록 — 다시 해도 안 되는 실패(403)면 기록 없이 계속을 준다', (tester) async {
      final sc = quizCourse();
      final server = _FakeQuestServer(scenarioId: sc.scenarioId)..collectStatus = 403;
      await toQuizContinue(tester, sc, server);

      await tester.tap(find.text('계속하기'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('당도해야'), findsOneWidget);

      await tester.tap(find.text('기록 없이 계속'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('획 득'), findsOneWidget);
      expect(server.count('/complete'), 0);
      expect(ScenarioStore.I.doneOf(sc.scenarioId), ['q1']);
    });

    testWidgets('조각 기록 — 좌표 없는 장소를 건너뛰었으면 서버 기록을 시도하지 않는다', (tester) async {
      final sc = quizCourse();
      final server = _FakeQuestServer(
          scenarioId: sc.scenarioId,
          verdict: _verdict(verified: false, reason: 'NODE_HAS_NO_COORDS'));
      await _tapArrival(tester, sc, server);
      await tester.tap(find.text('위치 확인 없이 진행'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await answerQuiz(tester);

      await tester.tap(find.text('계속하기'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(server.count('/collect'), 0);
      expect(server.count('/complete'), 0);
      expect(find.text('획 득'), findsOneWidget);
    });

    testWidgets('조각 기록 — 기록 중에 버튼을 연타해도 서버 요청은 한 번이다', (tester) async {
      final sc = quizCourse();
      final server = _FakeQuestServer(scenarioId: sc.scenarioId);
      await toQuizContinue(tester, sc, server);

      await tester.tap(find.text('계속하기'));
      await tester.tap(find.text('계속하기'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(server.count('/collect'), 1);
      expect(server.count('/complete'), 1);
    });

    testWidgets('조각 기록 — 피날레 기록이 실패하면 엔딩으로 넘어가지 않는다', (tester) async {
      final sc = Scenario.fromJson({
        'scenario_id': 'finale_only',
        'title': '종로구의 기억석',
        'region': '종로구',
        'node_sequence': [_stone('f1', '광화문', finale: true)],
      });
      final server = _FakeQuestServer(scenarioId: sc.scenarioId)..collectStatus = 500;
      await _tapArrival(tester, sc, server);
      await tester.pump(const Duration(milliseconds: 1600)); // 수호 정령 소환 → 'appear'
      await tester.tap(find.text('말 걸기'));
      await tester.pump();

      await tester.tap(find.text('"이곳의 기억을 계속 지킬게."')); // 엔딩 데이터가 없는 코스의 기본 갈래
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('조각을 기록하지 못했느니라'), findsOneWidget);
      expect(find.text('처음부터 다시'), findsNothing, reason: '엔딩 화면으로 넘어가면 안 된다');
      expect(ScenarioStore.I.endingOf(sc.scenarioId), isNull);
    });

    // 계획 B1·B2 — 획득 팝업은 종로 시안 고정 문구가 아니라 그 챕터·서버 보상을 보여준다.
    Scenario clueCourse() => Scenario.fromJson({
          'scenario_id': 'gyeongju_reward',
          'title': '경주시의 기억석',
          'region': '경주시',
          'node_sequence': [
            {
              ..._rich('q1', '첨성대', 'QUIZ_FIND', quiz: {
                'q': '첨성대는 무엇을 살피던 곳이더냐?',
                'options': ['별', '물', '바람'],
                'answer': 0,
                'wrong_hint': '하늘을 보거라',
              }),
              'clue': '별빛',
            },
            // 별빛은 월성 퀴즈의 귀띔 — 퀴즈에 쓰이는 단서라야 획득 팝업에 뜬다.
            {
              ..._rich('q2', '월성', 'QUIZ_FIND',
                  quiz: {'q': '?', 'options': ['가', '나', '다'], 'answer': 0, 'wrong_hint': ''}),
              'strategy': ['S3_RIDDLE_UNLOCK'],
              'requires': ['clue:별빛'],
              'requires_mode': 'soft',
            },
          ],
        });

    testWidgets('획득 팝업 — 종로 고정 문구 대신 실제 장소·지역·조각 번호·단서가 뜬다', (tester) async {
      final sc = clueCourse();
      await toQuizContinue(tester, sc, _FakeQuestServer(scenarioId: sc.scenarioId));

      await tester.tap(find.text('계속하기'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('「첨성대」의 기억석 조각'), findsOneWidget);
      expect(find.text('경주시의 기억석 · 1/2 조각'), findsOneWidget);
      expect(find.text('단서 「별빛」'), findsOneWidget);
      // 코드로 그린 한자 조각 대신 조각 그림 — 큰 그림 1 + 모은 조각 칸 2(모은 1·남은 1).
      expect(
          find.byWidgetPredicate((w) =>
              w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == kMemoryFragmentAsset),
          findsNWidgets(3));
      expect(find.byKey(const ValueKey('frag-slot-0-true')), findsOneWidget, reason: '첨성대 조각은 모았다');
      expect(find.byKey(const ValueKey('frag-slot-1-false')), findsOneWidget, reason: '남은 조각은 흐리게');
      expect(find.text('글씨조각 「훈(訓)」'), findsNothing);
      expect(find.textContaining('申時'), findsNothing);
      expect(find.textContaining('익선동'), findsNothing);
    });

    testWidgets('획득 팝업 — 경험치·도감·칭호는 서버가 준 값을 보여준다', (tester) async {
      final sc = clueCourse();
      final server = _FakeQuestServer(
          scenarioId: sc.scenarioId, expGained: 25, dexEntry: '별빛 도깨비', titles: const ['첫 조각']);
      await toQuizContinue(tester, sc, server);

      await tester.tap(find.text('계속하기'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('+25'), findsOneWidget);
      expect(find.text('+50'), findsNothing, reason: '시안 고정 경험치');
      expect(find.text('«별빛 도깨비»'), findsOneWidget);
      expect(find.text('첫 조각'), findsOneWidget);
    });

    testWidgets('획득 팝업 — 기록 없이 계속한 조각은 경험치 대신 서버에 안 남았다고 알린다', (tester) async {
      final sc = clueCourse();
      final server = _FakeQuestServer(scenarioId: sc.scenarioId)..collectStatus = 403;
      await toQuizContinue(tester, sc, server);

      await tester.tap(find.text('계속하기'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('기록 없이 계속'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('획 득'), findsOneWidget);
      expect(find.textContaining('서버에 남지 않았'), findsOneWidget);
      expect(find.text('경험치'), findsNothing);
    });

    // 계획 B13 — 소환 화면 이름표가 '먹 도깨비 · Lv.7' 고정이라, 대화한 도깨비와
    // 미션 완료 후 도감에 쌓이는 도깨비(노드 npc.name)가 서로 달라 보였다.
    testWidgets('소환 화면 이름표 — 그 장소 노드의 도깨비 이름이 뜬다', (tester) async {
      final sc = Scenario.fromJson({
        'scenario_id': 'gyeongju_npc',
        'title': '경주시의 기억석',
        'region': '경주시',
        'node_sequence': [
          _rich('q1', '첨성대', 'QUIZ_FIND', npc: '서책 도깨비'),
          _rich('q2', '월성', 'RESTORE_AR'),
        ],
      });
      await _tapArrival(tester, sc, _FakeQuestServer(scenarioId: sc.scenarioId));
      await tester.pump(const Duration(milliseconds: 1600)); // 소환 대기 → 등장

      expect(find.text('서책 도깨비'), findsOneWidget);
      expect(find.text('먹 도깨비 · Lv.7'), findsNothing);
      expect(find.textContaining('먹 기운'), findsNothing);
    });

    testWidgets('소환 화면 이름표 — npc가 없는 노드는 먹 도깨비가 아니라 도깨비', (tester) async {
      final sc = quizCourse(); // npc 없는 코스
      await _tapArrival(tester, sc, _FakeQuestServer(scenarioId: sc.scenarioId));
      await tester.pump(const Duration(milliseconds: 1600));

      expect(find.text('도깨비'), findsOneWidget);
      expect(find.textContaining('먹 도깨비'), findsNothing);
    });

    // 계획 B8 — 퀴즈 경험치 태그(+30)는 서버 지급액과 달라 뺐고, 쿠폰은 AI 데이터가 있을 때만 준다.
    testWidgets('퀴즈 정답 — 경험치 태그는 없고, AI 쿠폰 데이터가 없으면 쿠폰도 없다', (tester) async {
      final sc = quizCourse(); // answer 원자(correct.coupon) 없는 코스
      await toQuizContinue(tester, sc, _FakeQuestServer(scenarioId: sc.scenarioId));

      expect(find.text('"옳거니! 안목이 있구나."'), findsOneWidget);
      expect(find.text('경험치 +30'), findsNothing);
      expect(find.textContaining('쿠폰 +'), findsNothing, reason: '데이터에 없는 쿠폰을 박아 주지 않는다');
    });

    // 예전 AI가 퀴즈 원자에 담아 보내던 정답 보상 쿠폰 — 쿠폰 보상을 없애 앱이 쓰지 않는다.
    Scenario couponQuizCourse() => Scenario.fromJson({
          'scenario_id': 'gyeongju_quiz_coupon',
          'title': '경주시의 기억석',
          'region': '경주시',
          'node_sequence': [
            {
              ..._rich('q1', '첨성대', 'QUIZ_FIND', quiz: {
                'q': '첨성대는 무엇을 살피던 곳이더냐?',
                'options': ['별', '물', '바람'],
                'answer': 0,
                'wrong_hint': '하늘을 보거라',
              }),
              'actions': [
                {'a': 'answer', 'quiz': {'answer_idx': 0, 'correct': {'exp': 30, 'coupon': 200}}},
              ],
            },
            _rich('q2', '월성', 'RESTORE_AR'),
          ],
        });

    testWidgets('퀴즈 정답 — 예전 코스에 정답 쿠폰이 있어도 보여 주지도 지급하지도 않는다', (tester) async {
      final sc = couponQuizCourse();
      await toQuizContinue(tester, sc, _FakeQuestServer(scenarioId: sc.scenarioId));

      expect(find.text('"옳거니! 안목이 있구나."'), findsOneWidget);
      expect(find.textContaining('쿠폰'), findsNothing, reason: '쿠폰 보상은 없앴다');

      await tester.tap(find.text('계속하기'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('가방에 넣기 — 지도로'), findsOneWidget);
      expect(find.text('+200원'), findsNothing, reason: '획득 팝업에 쿠폰 줄이 없다');
      expect(ScenarioStore.I.stateOf(sc.scenarioId).coupons, isEmpty);
    });
  });

  // 계획 B7 — 지도 HUD의 칭호·여비 고정값.
  group('HUD', () {
    Scenario hudCourse({int? budget}) => Scenario.fromJson({
          'scenario_id': 'hud_course',
          'title': '경주시의 기억석',
          'region': '경주시',
          if (budget != null) 'budget': budget,
          'node_sequence': [_stone('u1', '첨성대'), _stone('u2', '월성', finale: true)],
        });

    testWidgets('칭호 자리에 닉네임이 뜬다 — 글지기 견습 고정값이 아니다', (tester) async {
      Session.nickname = '달빛산책자';
      addTearDown(() => Session.nickname = null);
      await _toMap(tester, hudCourse());

      expect(find.text('달빛산책자'), findsOneWidget);
      expect(find.text('글지기 견습'), findsNothing);
      expect(find.text('글'), findsNothing, reason: '칭호 첫 글자를 박아 둔 아바타 원도 없다');
      expect(find.text('제 1 장 진행 중'), findsOneWidget, reason: '장 번호는 아바타 점 대신 이 줄에 남는다');
    });

    testWidgets('닉네임이 없으면 탐험가로 보인다', (tester) async {
      Session.nickname = null;
      await _toMap(tester, hudCourse());

      expect(find.text('탐험가'), findsOneWidget);
    });

    testWidgets('코스에 예산이 없으면 여비를 보여주지 않는다', (tester) async {
      await _toMap(tester, hudCourse());

      expect(find.text('20000'), findsNothing, reason: '사용자가 정한 적 없는 데모 여비다');
    });

    testWidgets('코스에 예산이 있으면 그 예산이 여비로 보인다', (tester) async {
      await _toMap(tester, hudCourse(budget: 30000));

      expect(find.text('30000'), findsOneWidget);
    });

    testWidgets('붓털은 코스에 저장된 개수로 시작한다', (tester) async {
      final sc = hudCourse();
      await ScenarioStore.I.add(sc);
      await ScenarioStore.I.setBrush(sc.scenarioId, 1);
      await _toMap(tester, sc);

      expect(find.text('붓털 1'), findsOneWidget);
    });
  });

  // 계획 B14 — 발자국 대사가 모든 코스에 종로 대본 4줄(먹내음·처마)로 고정돼 있었다.
  group('엽전 귀띔(trailWhisper)', () {
    const steps = ['돌담 모퉁이', '느티나무 아래', '우물터'];

    test('첫 엽전 전엔 자취 묘사를, 주울 때마다 방금 닿은 지점을, 끝에선 거두라는 말을 붙인다', () {
      expect(trailWhisper(clue: '엽전 몇 닢이 동쪽으로 흩어져 있다', steps: steps, step: 0, total: 3),
          '"엽전 몇 닢이 동쪽으로 흩어져 있다"');
      expect(trailWhisper(steps: steps, step: 1, total: 3), '"돌담 모퉁이"');
      expect(trailWhisper(steps: steps, step: 2, total: 3), '"느티나무 아래"');
      expect(trailWhisper(steps: steps, step: 3, total: 3), '"우물터 — 저기 빛나는 것을 거두거라."');
    });

    test('자취 묘사·지점이 없으면 종로 대본이 아닌 기본 문구를 쓴다', () {
      final lines = [for (var i = 0; i <= 3; i++) trailWhisper(step: i, total: 3)];

      expect(lines.first, contains('엽전이 이어져'));
      expect(lines.last, contains('빛나는 것을 거두거라'));
      for (final line in lines) {
        expect(line, isNot(contains('먹내음')));
        expect(line, isNot(contains('처마')));
      }
    });
  });

  // 수집 단계(S1·S6)가 떠 있는 조각(종로 한자 '宮') 탭이라 AR 엽전 줍기와 같은 '모으기'로 보였다
  // → 빛 순서 기억하기 미니게임. 대상 이름·개수는 tap 원자에서 온다.
  group('수집 단계 — 빛 순서 기억하기', () {
    Scenario gatherCourse() => Scenario.fromJson({
          'scenario_id': 'gyeongju_gather_test',
          'title': '경주시의 기억석',
          'region': '경주시',
          'node_sequence': [
            {
              ..._stone('g1', '무열왕릉비'),
              'strategy': const ['S6_COUNT_COLLECT'],
              'actions': const [
                {'a': 'tap', 'target': '비몸', 'count': [0, 4]},
              ],
              'mission': {'type': 'COLLECT', 'order': '비몸을 찾아라', 'hints': const []},
            },
            _stone('g2', '첨성대', finale: true),
          ],
        });

    Future<void> toGather(WidgetTester tester) async {
      await _toDialogue(tester, gatherCourse());
      await tester.tap(find.text('"그냥 빨리 찾겠소."'));
      await tester.pump();
      await tester.tap(find.text('계속 — 지령 받기'));
      await tester.pump();
      await tester.tap(find.text('지령 받기 — 수집 시작'));
      await tester.pump();
    }

    /// 화면에서 빛나는 조각을 차례로 읽는다(무작위 순서) — 빛남 600ms·쉼 250ms.
    Future<List<int>> readSequence(WidgetTester tester, int n) async {
      await tester.pump(const Duration(milliseconds: 750)); // 시작 지연 700 + 여유
      final seq = <int>[];
      for (var step = 0; step < n; step++) {
        for (var i = 0; i < n; i++) {
          final scale = tester.widget<AnimatedScale>(
              find.descendant(of: find.byKey(ValueKey('seq-tile-$i')), matching: find.byType(AnimatedScale)));
          if (scale.scale > 1) seq.add(i);
        }
        await tester.pump(const Duration(milliseconds: 850));
      }
      return seq;
    }

    testWidgets('떠 있는 조각 대신 미니게임이 뜨고, 대상 이름·개수는 데이터에서 온다', (tester) async {
      await toGather(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(MemorySequenceGame), findsOneWidget);
      expect(find.text('비몸의 기억'), findsOneWidget);
      expect(find.byKey(const ValueKey('seq-tile-3')), findsOneWidget, reason: 'tap 원자 개수 4');
      expect(find.byKey(const ValueKey('seq-tile-4')), findsNothing);
      expect(find.text('宮'), findsNothing, reason: '종로 시안 한자 조각이 아니다');
      expect(find.text('돌아와 조각을 살피다'), findsNothing, reason: '맞히기 전엔 못 넘어간다');
    });

    testWidgets('빛난 순서대로 누르면 조각을 살피러 갈 수 있다', (tester) async {
      await toGather(tester);
      final seq = await readSequence(tester, 4);
      expect(seq, hasLength(4));

      for (final i in seq) {
        await tester.tap(find.byKey(ValueKey('seq-tile-$i')));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('돌아와 조각을 살피다'), findsOneWidget);
    });
  });

  // 모든 장소에 같은 기본 캐릭터 한 장이 떴다 — 이름(npc.name)에 맞는 도깨비 그림으로.
  group('장소 도깨비 그림', () {
    Finder assetImage(String path) => find.byWidgetPredicate(
        (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == path);

    Scenario npcCourse({String npc = ''}) => Scenario.fromJson({
          'scenario_id': 'npc_art_course',
          'title': '해운대구의 기억석',
          'region': '해운대구',
          'node_sequence': [
            _rich('a1', '동백섬', 'RESTORE_AR', npc: npc),
            _stone('a2', '해운대해수욕장', finale: true),
          ],
        });

    testWidgets('소환 화면 — 그 장소 도깨비의 전신이 뜬다', (tester) async {
      final sc = npcCourse(npc: '숯불 도깨비');
      await _tapArrival(tester, sc, _FakeQuestServer(scenarioId: sc.scenarioId));
      await tester.pump(const Duration(milliseconds: 1600)); // 스캔 → 등장

      expect(tester.takeException(), isNull);
      expect(assetImage('assets/game/characters/food_sutbul/full_idle.webp'), findsOneWidget);
      expect(assetImage('assets/game/characters/base_youth/full_idle.webp'), findsNothing,
          reason: '기본 도깨비가 아니라 이 장소의 숯불 도깨비');
    });

    testWidgets('대화 화면 — 그 도깨비의 말하는 상반신', (tester) async {
      await _toDialogue(tester, npcCourse(npc: '숯불 도깨비'));

      expect(tester.takeException(), isNull);
      expect(assetImage('assets/game/characters/food_sutbul/bust_talk.webp'), findsOneWidget);
    });

    testWidgets('이름이 없는 장소는 기본 소년 도깨비로 폴백한다', (tester) async {
      await _toDialogue(tester, npcCourse());

      expect(tester.takeException(), isNull);
      expect(assetImage('assets/game/characters/base_youth/bust_talk.webp'), findsOneWidget);
    });
  });

  // 계획 A1·B3·B4 — 피날레·엔딩이 코스와 무관하게 세종대왕·훈민정음·종로였다.
  // 재료는 AI가 피날레 노드에 붙여 준다(ai #64 attach_endings).
  group('피날레·엔딩', () {
    Scenario finaleCourse() => Scenario.fromJson({
          'scenario_id': 'gyeongju_finale',
          'title': '경주시의 기억석',
          'region': '경주시',
          'node_sequence': [
            {
              ..._stone('f1', '월성', finale: true),
              'npc': {'name': '수호 도깨비'},
              'mission': {
                'type': 'DIALOGUE_COLLECT',
                'order': '월성에서 기억석을 복원하라',
                'hints': const [],
                'villain_line': '작은 것들은 곧 잊히는 법이지.',
                'guardian_line': '아니다. 기억은 누군가 다시 찾을 때 살아나느니라.',
              },
              'final_restore_dialogue': '월성에서 모은 조각이 하나의 경주시 기억석으로 이어졌느니라.',
              'endings': {
                'A': {
                  'id': 'A',
                  'choice_text': '이곳의 기억을 계속 지킬게.',
                  'ending': '굿 엔딩',
                  'npc_dialogue': ['그 마음이 경주시의 기억을 오래 지켜 줄 것이니라.'],
                  'rewards': {
                    'title': '경주시의 기억 복원자',
                    'garden_item_final': '경주시 기억석',
                    'unlock': '경주시의 기억이 복원되었습니다.',
                  },
                },
                'B': {
                  'id': 'B',
                  'choice_text': '이제 일상으로 돌아가고 싶어.',
                  'ending': '노멀 엔딩',
                  'npc_dialogue': ['쉬고 싶은 마음도 당연하니라.'],
                  'rewards': {'title': '경주시의 기억 복원자', 'garden_item_final': '경주시 기억석'},
                },
              },
              'final_rewards_common': {
                'region_stone': {'name': '경주시 기억석', 'desc': '경주시의 기억을 모아 복원한 기억석'},
              },
            },
          ],
        });

    /// 엔딩 갈래를 고른 뒤 복원 연출을 끝까지 보고 '계속'으로 엔딩 화면에 간다.
    Future<void> throughRestore(WidgetTester tester) async {
      await tester.pump(kRestoreDuration);
      await tester.tap(find.text('계속'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }

    /// 도착 인증 → 소환 → "말 걸기"까지 눌러 피날레 화면을 연다.
    Future<void> toFinale(WidgetTester tester, Scenario sc, _FakeQuestServer server) async {
      await _tapArrival(tester, sc, server);
      await tester.pump(const Duration(milliseconds: 1600)); // 소환 연출
      await tester.tap(find.text('말 걸기'));
      await tester.pump();
    }

    /// 장소 둘 + 피날레 — 두 장소를 끝낸 채 피날레로. 굿 엔딩 기준 = 장소 2곳의 절반 = 친밀도 1.
    Future<Scenario> afterTwoPlaces({required int affinity}) async {
      final finale = finaleCourse().nodeSequence.single.toJson();
      final sc = Scenario.fromJson({
        'scenario_id': 'gyeongju_affinity',
        'title': '경주시의 기억석',
        'region': '경주시',
        'node_sequence': [_stone('p1', '첨성대'), _stone('p2', '대릉원'), finale],
      });
      await ScenarioStore.I.add(sc);
      await ScenarioStore.I.completeNodeWithGrants(sc.scenarioId, sc.nodeSequence[0]);
      await ScenarioStore.I.completeNodeWithGrants(sc.scenarioId, sc.nodeSequence[1]);
      if (affinity > 0) {
        await ScenarioStore.I.grant(sc.scenarioId, [StateRef(kind: StateKind.affinity, value: '', amount: affinity)]);
      }
      return sc;
    }

    testWidgets('친밀도가 모자라면 굿 엔딩이 잠기고 노멀 엔딩만 고를 수 있다', (tester) async {
      final sc = await afterTwoPlaces(affinity: 0);
      await toFinale(tester, sc, _FakeQuestServer(scenarioId: sc.scenarioId));

      expect(find.byKey(const ValueKey('good-ending-locked')), findsOneWidget);
      expect(find.text('도깨비들의 사연을 더 들어야 굿 엔딩이 열리느니라 · 친밀도 0/1'), findsOneWidget);
      await tester.tap(find.text('이곳의 기억을 계속 지킬게.'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MemoryStoneRestore), findsNothing, reason: '잠긴 굿 엔딩은 눌러도 넘어가지 않는다');

      await tester.tap(find.text('이제 일상으로 돌아가고 싶어.'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await throughRestore(tester);
      expect(ScenarioStore.I.endingOf(sc.scenarioId), 'normal');
    });

    testWidgets('친밀도가 기준 이상이면 굿 엔딩을 고를 수 있다', (tester) async {
      final sc = await afterTwoPlaces(affinity: 1);
      await toFinale(tester, sc, _FakeQuestServer(scenarioId: sc.scenarioId));

      expect(find.byKey(const ValueKey('good-ending-locked')), findsNothing);
      expect(find.byKey(const ValueKey('good-ending-need')), findsNothing);
      await tester.tap(find.text('이곳의 기억을 계속 지킬게.'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await throughRestore(tester);
      expect(ScenarioStore.I.endingOf(sc.scenarioId), 'good');
    });

    testWidgets('피날레 화면 — 세종대왕 대신 그 코스의 수호 도깨비와 복원 대사가 뜬다', (tester) async {
      final sc = finaleCourse();
      await toFinale(tester, sc, _FakeQuestServer(scenarioId: sc.scenarioId));

      expect(find.text('수호 도깨비'), findsWidgets);
      expect(find.text('월성에서 모은 조각이 하나의 경주시 기억석으로 이어졌느니라.'), findsOneWidget);
      expect(find.text('"작은 것들은 곧 잊히는 법이지."'), findsOneWidget, reason: '망각귀 대사(villain_line)');
      expect(find.text('이곳의 기억을 계속 지킬게.'), findsOneWidget);
      expect(find.text('이제 일상으로 돌아가고 싶어.'), findsOneWidget);
      expect(find.text('세종대왕'), findsNothing);
      expect(find.textContaining('글씨조각 3/4'), findsNothing);
      expect(find.textContaining('이순신'), findsNothing, reason: '근거 없는 사이드 퀘스트는 삭제했다');
    });

    testWidgets('피날레 화면 — 수호 도깨비 그림이 뜬다', (tester) async {
      final sc = finaleCourse();
      await toFinale(tester, sc, _FakeQuestServer(scenarioId: sc.scenarioId));

      expect(
          find.byWidgetPredicate((w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName == 'assets/game/characters/guardian_suho/full_idle.webp'),
          findsWidgets, reason: '화면 전환 중엔 소환 화면과 피날레 화면이 함께 그려진다 — 둘 다 수호 도깨비');
      expect(find.byWidgetPredicate((w) => w is Image && w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/game/characters/base_youth/full_idle.webp'), findsNothing);
    });

    testWidgets('엔딩 화면 — 고른 갈래의 대사·지역 기억석과 서버 칭호를 보여준다', (tester) async {
      final sc = finaleCourse();
      final server = _FakeQuestServer(
          scenarioId: sc.scenarioId, expGained: 500, titles: const ['경주시의 기억을 되찾은 자']);
      await toFinale(tester, sc, server);

      await tester.tap(find.text('이곳의 기억을 계속 지킬게.'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await throughRestore(tester);

      expect(find.text('복 원 · 굿 엔딩'), findsOneWidget);
      expect(find.text('경주시 기억석 복원'), findsOneWidget);
      expect(find.text('그 마음이 경주시의 기억을 오래 지켜 줄 것이니라.'), findsOneWidget);
      expect(find.text('경주시의 기억을 되찾은 자'), findsOneWidget, reason: '칭호는 서버가 준 값');
      expect(find.text('경주시의 기억이 복원되었습니다.'), findsOneWidget);
      expect(find.text('+500'), findsOneWidget);
      expect(find.text('종로 글씨 기억석 복원'), findsNothing);
      expect(find.text('訓'), findsNothing);
      expect(find.text('집현전 붓'), findsNothing);
      expect(find.text('다음 지역 — 북촌 해금'), findsNothing);
      expect(ScenarioStore.I.endingOf(sc.scenarioId), 'good');
    });

    testWidgets('엔딩을 고르면 바로 엔딩이 아니라 조각이 모이는 복원 연출이 먼저 뜬다', (tester) async {
      final sc = finaleCourse();
      await toFinale(tester, sc, _FakeQuestServer(scenarioId: sc.scenarioId));

      await tester.tap(find.text('이곳의 기억을 계속 지킬게.'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MemoryStoneRestore), findsOneWidget);
      expect(find.text('복 원 · 굿 엔딩'), findsNothing, reason: '엔딩은 연출 뒤');
      expect(find.text('「경주시 기억석」'), findsOneWidget, reason: '피날레 노드의 region_stone 이름');

      await throughRestore(tester);
      await tester.pump(const Duration(seconds: 1)); // 화면 전환(크로스페이드)이 끝나야 연출 화면이 빠진다
      expect(find.byType(MemoryStoneRestore), findsNothing);
      expect(find.text('복 원 · 굿 엔딩'), findsOneWidget);
      expect(
          find.byWidgetPredicate((w) =>
              w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == kMemoryStoneAsset),
          findsOneWidget,
          reason: '엔딩의 기억석은 완성체 그림');
    });

    testWidgets('엔딩 화면 — 처음부터 다시·코스 목록으로 두 버튼은 같은 너비다', (tester) async {
      final sc = finaleCourse();
      await toFinale(tester, sc, _FakeQuestServer(scenarioId: sc.scenarioId));
      await tester.tap(find.text('이곳의 기억을 계속 지킬게.'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await throughRestore(tester);

      Size box(String label) =>
          tester.getSize(find.ancestor(of: find.text(label), matching: find.byType(Container)).first);
      expect(box('처음부터 다시').width, box('코스 목록으로').width);
    });

    testWidgets('엔딩 화면 — 다른 갈래를 고르면 노멀 엔딩 대사가 뜬다', (tester) async {
      final sc = finaleCourse();
      await toFinale(tester, sc, _FakeQuestServer(scenarioId: sc.scenarioId));

      await tester.tap(find.text('이제 일상으로 돌아가고 싶어.'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await throughRestore(tester);

      expect(find.text('복 원 · 노멀 엔딩'), findsOneWidget);
      expect(find.text('쉬고 싶은 마음도 당연하니라.'), findsOneWidget);
      expect(find.text('그 마음이 경주시의 기억을 오래 지켜 줄 것이니라.'), findsNothing);
      expect(ScenarioStore.I.endingOf(sc.scenarioId), 'normal');
    });
  });

  // C2 — 코스 상세에서 누른 장소부터 코스 진행 화면을 연다. 진행은 "모은 조각 수"가 아니라
  // "끝낸 장소"로 센다 — 조각 수로 세면 뒤 장소를 먼저 끝냈을 때 엉뚱한 장소가 차례가 된다.
  group('시작 장소', () {
    testWidgets('고른 장소부터 열린다 — 앞 장소가 안 끝났어도', (tester) async {
      final sc = _course(3);
      await ScenarioStore.I.add(sc);
      await _toMap(tester, sc, startNodeId: 'c2');

      expect(find.text('제 2 장 진행 중'), findsOneWidget);
    });

    testWidgets('피날레를 골라도 다른 조각이 남았으면 안 끝난 첫 장소부터', (tester) async {
      final sc = _course(3);
      await ScenarioStore.I.add(sc);
      await _toMap(tester, sc, startNodeId: 'c3');

      expect(find.text('제 1 장 진행 중'), findsOneWidget);
    });

    testWidgets('뒤 장소만 끝났으면 안 끝난 첫 장소가 차례다', (tester) async {
      final sc = _course(3);
      await ScenarioStore.I.add(sc);
      await ScenarioStore.I.completeNodeWithGrants(sc.scenarioId, sc.nodeSequence[1]);
      await _toMap(tester, sc);

      expect(find.text('제 1 장 진행 중'), findsOneWidget,
          reason: '조각 1개를 "다음은 2장"으로 세면 이미 끝낸 장소를 다시 하게 된다');
    });

    // 인사동이 퀴즈 — 익선동의 ㄱ이 그 귀띔. 운현궁의 申時는 어느 퀴즈에도 안 쓰인다(예전 코스 모양).
    Scenario clueChain() => Scenario.fromJson({
          'scenario_id': 'clue_chain',
          'title': '종로구의 기억석',
          'region': '종로구',
          'node_sequence': [
            _stone('k1', '운현궁', grants: ['fragment:frag_k1', 'clue:申時']),
            _stone('k2', '익선동', grants: ['fragment:frag_k2', 'clue:ㄱ']),
            {
              ..._stone('k3', '인사동', grants: ['fragment:frag_k3'], requires: ['clue:ㄱ'], mode: 'soft'),
              'strategy': ['S3_RIDDLE_UNLOCK'],
              'quiz': {'q': '?', 'options': ['가', '나', '다'], 'answer': 0},
            },
            _stone('k4', '광화문', finale: true),
          ],
        });

    testWidgets('퀴즈 장소로 건너뛰면 그 퀴즈의 귀띔만 알리고, 확인하면 그 장소부터 진행한다', (tester) async {
      final sc = clueChain();
      await ScenarioStore.I.add(sc);
      await _toMap(tester, sc, startNodeId: 'k3');

      expect(find.text('앞 장소의 귀띔 없이 왔느니라'), findsOneWidget);
      expect(find.text('단서 「ㄱ」'), findsOneWidget);
      expect(find.text('단서 「申時」'), findsNothing, reason: '어느 퀴즈도 쓰지 않는 단서');
      expect(find.text('익선동'), findsWidgets);

      await tester.tap(find.text('그래도 여기부터'));
      await tester.pump();

      expect(find.text('앞 장소의 귀띔 없이 왔느니라'), findsNothing);
      expect(find.text('제 3 장 진행 중'), findsOneWidget);
    });

    testWidgets('퀴즈가 아닌 장소로 건너뛰거나 귀띔을 이미 받았으면 안내가 없다', (tester) async {
      final sc = clueChain();
      await ScenarioStore.I.add(sc);
      await _toMap(tester, sc, startNodeId: 'k2'); // 운현궁을 건너뛰었지만 익선동은 퀴즈가 아니다
      expect(find.text('앞 장소의 귀띔 없이 왔느니라'), findsNothing);
      expect(find.text('제 2 장 진행 중'), findsOneWidget);

      await ScenarioStore.I.completeNodeWithGrants(sc.scenarioId, sc.nodeSequence[1]); // ㄱ을 받음
      await _toMap(tester, sc, startNodeId: 'k3');
      expect(find.text('앞 장소의 귀띔 없이 왔느니라'), findsNothing);
    });

    testWidgets('건너뛴 장소를 끝내면 다음 차례는 안 끝난 첫 장소로 돌아간다', (tester) async {
      Map<String, dynamic> quizNode(String id, String name) => _rich(id, name, 'QUIZ_FIND', quiz: {
            'q': '$name에서 무엇을 살피더냐?',
            'options': ['별', '물', '바람'],
            'answer': 0,
            'wrong_hint': '하늘을 보거라',
          });
      final sc = Scenario.fromJson({
        'scenario_id': 'jump_course',
        'title': '경주시의 기억석',
        'region': '경주시',
        'node_sequence': [quizNode('j1', '첨성대'), quizNode('j2', '대릉원'), _rich('j3', '월성', 'RESTORE_AR')],
      });
      final server = _FakeQuestServer(scenarioId: sc.scenarioId);
      await _tapArrival(tester, sc, server, startNodeId: 'j2');
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

      expect(ScenarioStore.I.doneOf(sc.scenarioId), ['j2']);

      await tester.tap(find.text('가방에 넣기 — 지도로'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('제 1 장 진행 중'), findsOneWidget,
          reason: '2장을 먼저 끝냈으면 다음은 3장이 아니라 안 끝난 1장이다');
    });
  });

  // quiz-clue/ljs/v1 — 퀴즈 바로 앞 장소가 준 단서를 가져오면 오답 하나가 지워진다.
  group('퀴즈 귀띔 단서', () {
    const giverClue = 'clue:대릉원 시험의 귀띔';
    Map<String, dynamic> quizNode(String id, String name, {required String requires, List<String> grants = const []}) => {
          ..._rich(id, name, 'QUIZ_FIND', quiz: {
            'q': '$name에 잠든 이는 누구더냐?',
            'options': ['신라 왕', '고려 왕', '조선 왕', '백제 왕'],
            'answer': 0,
            'wrong_hint': '천 년 전을 보거라',
          }),
          'strategy': ['S3_RIDDLE_UNLOCK'],
          'grants': ['fragment:frag_$id', ...grants],
          'requires': [requires],
          'requires_mode': 'soft',
        };
    Scenario clueQuiz({List<String> quizGrants = const []}) => Scenario.fromJson({
          'scenario_id': 'clue_quiz',
          'title': '경주시의 기억석',
          'region': '경주시',
          'node_sequence': [
            _stone('g1', '첨성대', grants: ['fragment:frag_g1', giverClue]),
            quizNode('g2', '대릉원', requires: giverClue, grants: quizGrants),
            quizNode('g3', '월성', requires: 'clue:월성 시험의 귀띔'),
            _stone('g4', '불국사', finale: true),
          ],
        });

    /// 대릉원(g2)부터 열어 도착 → 대화 → 시험 화면까지. 건너뛰기 안내가 뜨면 닫고 간다.
    Future<void> toQuiz(WidgetTester tester, Scenario sc) async {
      final server = _FakeQuestServer(scenarioId: sc.scenarioId);
      await ScenarioStore.I.add(sc);
      await _toMap(tester, sc, runSession: server.session(), location: _atSpot, startNodeId: 'g2');
      if (find.text('그래도 여기부터').evaluate().isNotEmpty) {
        await tester.tap(find.text('그래도 여기부터'));
        await tester.pump();
      }
      await tester.tap(find.text('이동 시작 — GPS 추적'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('GPS 도착 인증'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.tap(find.text('말 걸기'));
      await tester.pump();
      await tester.tap(find.text('"그냥 빨리 찾겠소."'));
      await tester.pump();
      await tester.tap(find.text('계속 — 도깨비의 시험'));
      await tester.pump();
    }

    testWidgets('귀띔을 가져오면 오답 하나가 지워지고 누를 수 없다', (tester) async {
      final sc = clueQuiz(quizGrants: const ['clue:월성 시험의 귀띔']);
      await ScenarioStore.I.add(sc);
      await ScenarioStore.I.completeNodeWithGrants(sc.scenarioId, sc.nodeSequence[0]); // 첨성대 → 귀띔
      await toQuiz(tester, sc);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('quiz-clue-held')), findsOneWidget);
      expect(find.text('단서 「대릉원 시험의 귀띔」 — 오답 하나를 지웠느니라.'), findsOneWidget);
      final gone = sc.nodeById('g2')!.quiz!.eliminatedFor('g2')!;
      expect(find.byKey(ValueKey('quiz-eliminated-${gone + 1}')), findsOneWidget);
      expect(find.text('귀띔으로 지움'), findsOneWidget);

      await tester.tap(find.text(sc.nodeById('g2')!.quiz!.options[gone]));
      await tester.pump();
      expect(find.textContaining('페널티는 없다'), findsNothing, reason: '지운 보기는 눌러도 오답 처리되지 않는다');

      await tester.tap(find.text('신라 왕'));
      await tester.pump();
      await tester.tap(find.text('계속하기'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      // 대릉원이 준 단서는 다음 퀴즈(월성)의 귀띔 — 보상 팝업에 쓰임과 함께 뜬다.
      expect(find.text('단서 「월성 시험의 귀띔」'), findsOneWidget);
      expect(find.text('다음 장소 시험에서 오답 하나를 지워 주느니라.'), findsOneWidget);
    });

    testWidgets('귀띔 없이 오면 지우지 않고 어디서 받는지 알려 준다', (tester) async {
      final sc = clueQuiz();
      await toQuiz(tester, sc);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('quiz-clue-missing')), findsOneWidget);
      expect(find.text('첨성대에 들렀다면 오답 하나를 지워 주는 귀띔을 받았을 것이니라.'), findsOneWidget);
      for (var i = 1; i <= 4; i++) {
        expect(find.byKey(ValueKey('quiz-eliminated-$i')), findsNothing);
      }
    });

    testWidgets('앞 장소를 끝내고 오면 다음 장소 대화는 인사부터, 퀴즈는 정답 체크 없이 열린다', (tester) async {
      final sc = clueQuiz(quizGrants: const ['clue:월성 시험의 귀띔']);
      await ScenarioStore.I.add(sc);
      await ScenarioStore.I.completeNodeWithGrants(sc.scenarioId, sc.nodeSequence[0]);
      await toQuiz(tester, sc); // 대릉원 퀴즈
      await tester.tap(find.text('신라 왕'));
      await tester.pump();
      await tester.tap(find.text('계속하기'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('가방에 넣기 — 지도로'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 다음 장소(월성) — 대릉원에서 받은 귀띔을 들고 퀴즈까지
      await tester.tap(find.text('이동 시작 — GPS 추적'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('GPS 도착 인증'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.tap(find.text('말 걸기'));
      await tester.pump();
      expect(find.text('"그냥 빨리 찾겠소."'), findsOneWidget, reason: '앞 장소에서 고른 답이 남으면 선택지가 안 뜬다');
      expect(find.text('계속 — 도깨비의 시험'), findsNothing);
      await tester.tap(find.text('"그냥 빨리 찾겠소."'));
      await tester.pump();
      await tester.tap(find.text('계속 — 도깨비의 시험'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('월성에 잠든 이는 누구더냐?'), findsOneWidget);
      expect(find.byKey(const ValueKey('quiz-clue-held')), findsOneWidget);
      expect(find.text('정답!'), findsNothing, reason: '앞 퀴즈의 정답 상태가 남으면 정답이 체크된 채 열린다');
      expect(find.text('계속하기'), findsNothing);
    });

    testWidgets('퀴즈에 안 쓰이는 단서는 보상 팝업에 뜨지 않는다 — 예전 코스', (tester) async {
      final sc = clueQuiz(quizGrants: const ['clue:三影']);
      await toQuiz(tester, sc);
      await tester.tap(find.text('신라 왕'));
      await tester.pump();
      await tester.tap(find.text('계속하기'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('가방에 넣기 — 지도로'), findsOneWidget);
      expect(find.text('단서 「三影」'), findsNothing);
    });
  });

  // 사진 미션 — 코스 진행 화면이 팀원의 AR 탐색 화면(실제 카메라 + 서버 사진 판정)을 연다.
  // 예전엔 그림 위에서 타이머만 도는 사진 화면이었다.
  group('사진 미션 → AR 탐색 화면', () {
    Scenario photoCourse() => Scenario.fromJson({
          'scenario_id': 'photo_ar_course',
          'title': '천안시의 기억석',
          'region': '천안시',
          'node_sequence': [
            {
              ..._stone('p1', '명락사'),
              'mission': {
                'type': 'PHOTO_FIND',
                'order': '명락사 현판을 담아라',
                'hints': const [],
                'photo_targets': ['청룡동 명락사 현판'],
              },
            },
            _stone('p2', '성거산', finale: true),
          ],
        });

    Future<void> toPhotoCta(WidgetTester tester, Scenario sc) async {
      await _toDialogue(tester, sc);
      await tester.tap(find.text('"그냥 빨리 찾겠소."'));
      await tester.pump();
      await tester.tap(find.text('계속 — 지령 받기'));
      await tester.pump();
      await tester.tap(find.text('지령 받기 — 사진 인증 시작'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // 화면 전환
    }

    testWidgets('사진 인증을 시작하면 AR 탐색 화면이 촬영 대상과 함께 열린다', (tester) async {
      await toPhotoCta(tester, photoCourse());

      final ar = tester.widget<ArSearchScreen>(find.byType(ArSearchScreen));
      expect(ar.nodeId, 'p1');
      expect(ar.photoTargets, ['청룡동 명락사 현판']);
      expect(ar.missionType, 'PHOTO_FIND');
      expect(find.text('셔터를 누르면 도깨비가 살펴본다'), findsNothing, reason: '예전 그림 사진 화면이 아니다');
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('AR 화면에서 통과하고 돌아오면 조각 확정으로 이어진다', (tester) async {
      final sc = photoCourse();
      await toPhotoCta(tester, sc);

      Navigator.of(tester.element(find.byType(ArSearchScreen))).pop(true);
      await settle(tester);

      expect(ScenarioStore.I.doneOf(sc.scenarioId), ['p1']);
      expect(find.text('획 득'), findsOneWidget);
    });

    testWidgets('뒤로 나왔다가 다시 들어가 통과해도 조각이 확정된다', (tester) async {
      final sc = photoCourse();
      await toPhotoCta(tester, sc);
      Navigator.of(tester.element(find.byType(ArSearchScreen))).pop(false);
      await settle(tester);

      await tester.tap(find.text('지령 받기 — 사진 인증 시작'));
      await settle(tester);
      Navigator.of(tester.element(find.byType(ArSearchScreen))).pop(true);
      await settle(tester);

      expect(ScenarioStore.I.doneOf(sc.scenarioId), ['p1']);
      expect(find.text('획 득'), findsOneWidget);
    });

    testWidgets('통과하지 않고 뒤로 나오면 조각을 주지 않고 지령 화면에 남는다', (tester) async {
      final sc = photoCourse();
      await toPhotoCta(tester, sc);

      Navigator.of(tester.element(find.byType(ArSearchScreen))).pop(false);
      await settle(tester);

      expect(ScenarioStore.I.doneOf(sc.scenarioId), isEmpty);
      expect(find.text('획 득'), findsNothing);
      expect(find.text('지령 받기 — 사진 인증 시작'), findsOneWidget, reason: '다시 찍으러 들어갈 수 있어야 한다');
    });
  });
}
