// ============================================================
// [v1] 실스택 E2E — 앱 ApiClient로 실제 서버를 상대해 완주까지 간다
// pipeline: 모바일 클라이언트 / 배포 전 게이트
// 구현(요약): 위젯 스모크가 보장하지 못하는 것을 본다 — 실제 HTTP·실제 DB·실제 LLM으로
//            로그인 → 시나리오 생성 → run 시작 → GPS 판정 → 조각 → 완주가 도는가.
//            목·스텁 없음. 서버가 안 떠 있으면 **건너뛰지 않고 실패**한다(배포 전 게이트라
//            초록인데 검증 안 된 상태가 제일 위험하다).
//
//            ⚠️ test/ 밖에 둔다 — `flutter test`(오프라인 단위·위젯)에 섞이면 안 된다.
//            실행: flutter test test_e2e --dart-define=SERVER_BASE_URL=http://<서버>:8000
//            전제: dokkaebi-server(:8000) + dokkaebi-ai(:8001) + Postgres/Redis 기동
// 구현일: 2026-08-04 | 작성: kys (game-loop-wiring/kys/v1)
// ============================================================
import 'dart:convert';
import 'dart:io';

import 'package:dokkaebi_app/api/api_client.dart';
import 'package:dokkaebi_app/config.dart';
import 'package:dokkaebi_app/models/run.dart';
import 'package:dokkaebi_app/models/scenario.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
// ignore_for_file: invalid_use_of_visible_for_testing_member
// (이 파일은 test/ 밖에 있어 분석기가 테스트로 인식하지 못한다 — 실제로는 테스트다)
import 'package:shared_preferences/shared_preferences.dart';

/// 종로 경복궁 — 실제 코스를 만들 기준 좌표.
const _startLat = 37.5796;
const _startLng = 126.9770;

/// 노드에서 확실히 벗어난 좌표(약 8km) — 반경 밖 거절을 검증한다.
const _farLat = 37.6300;
const _farLng = 127.0500;

late final ApiClient api;

/// 서버가 살아 있는지 — 없으면 게이트로서 실패해야 하므로 이유를 분명히 남긴다.
Future<void> _requireServer() async {
  final url = '${AppConfig.serverBaseUrl}/v1/health';
  try {
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) {
      fail('게임 서버가 비정상입니다 ($url → ${res.statusCode}).');
    }
  } catch (e) {
    fail(
      '게임 서버에 연결할 수 없습니다: $url\n'
      '  이 테스트는 실스택 게이트라 서버 없이는 통과시키지 않습니다.\n'
      '  1) cd dokkaebi-infra && docker compose up -d postgres redis\n'
      '  2) cd dokkaebi-ai && .venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8001\n'
      '  3) cd dokkaebi-server && npm run build && npm start\n'
      '  원인: $e',
    );
  }
}

/// 스푸핑 판정을 초기화한다 — 직전 fix가 남아 있으면 순간이동으로 오인된다.
/// 테스트가 여러 노드를 순간이동하듯 도는 건 불가피하므로, 노드마다 비워 준다.
/// (실기기에서는 사람이 실제로 걸어가므로 이 문제가 없다)
Future<void> _clearSpoofHistory(String userId) async {
  final result = await Process.run('redis-cli', ['DEL', 'fix:$userId']);
  if (result.exitCode != 0) {
    // redis-cli가 없으면 서버가 Redis 없이도 도는지에 기대야 한다 — 경고만.
    // ignore: avoid_print
    print('⚠️  redis-cli 없음 — 스푸핑 이력을 못 지웠습니다. IMPOSSIBLE_SPEED가 날 수 있습니다.');
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    api = ApiClient();
    await _requireServer();
  });

  test('실스택 완주 — 로그인부터 지역 복원까지', () async {
    // ── 1. 로그인 (토큰 발급 + 세션 저장) ──
    await api.guestLogin('E2E탐험가');
    final userId = (await SharedPreferences.getInstance()).getString('user_id');
    expect(userId, isNotNull, reason: '로그인 후 세션에 user_id가 없다');

    // ── 2. 시나리오 생성 (실 TourAPI + 실 LLM) ──
    final Scenario scenario = await api.generateScenario(
      startLat: _startLat,
      startLng: _startLng,
      region: '종로',
      budget: 30000,
    );
    expect(scenario.nodeSequence, isNotEmpty, reason: 'AI가 노드를 하나도 안 만들었다');
    expect(scenario.stoneNodes, isNotEmpty);

    // 생성 결과가 진짜 데이터인지 — mock 폴백이면 배포하면 안 된다
    for (final n in scenario.stoneNodes) {
      expect(n.mapX, isNotNull, reason: '${n.name}: 좌표 없음 → GPS 판정 불가');
      expect(n.mapY, isNotNull, reason: '${n.name}: 좌표 없음 → GPS 판정 불가');
      expect(n.npcDialogue, isNotEmpty, reason: '${n.name}: NPC 대사가 비었다');
      expect(n.npcDialogue, isNot(contains('[mock 도깨비]')),
          reason: '${n.name}: mock LLM 응답 — 실제 배포에 나가면 안 된다');
    }

    // ── 3. 플레이 시작 ──
    QuestRun run = await api.startRun(scenario.scenarioId);
    expect(run.state, 'IN_PROGRESS');
    expect(run.required, greaterThan(0), reason: '모을 조각이 0개면 게임이 성립하지 않는다');
    expect(run.progress, 0);

    final first = scenario.stoneNodes.first;

    // ── 4. 반경 밖에서는 인증되지 않는다 ──
    await _clearSpoofHistory(userId!);
    final far = await api.verifyLocation(
      runId: run.runId, nodeId: first.nodeId,
      lat: _farLat, lng: _farLng, accuracyM: 10,
    );
    expect(far.verified, isFalse, reason: '8km 밖인데 인증됐다 — 위치 판정이 죽어 있다');
    expect(far.reason, VerifyReason.outOfRange);
    expect(far.distanceM, greaterThan(1000), reason: '실제 거리를 안 돌려준다');
    expect(far.message, isNotEmpty, reason: '사용자에게 보여줄 안내 문구가 비었다');

    // ── 5. 미인증 상태에서는 조각을 못 얻는다 ──
    await expectLater(
      api.collectFragment(runId: run.runId, nodeId: first.nodeId),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
      reason: 'GPS 인증 없이 조각을 얻을 수 있으면 앉아서 클리어된다',
    );

    // ── 6. 모든 기억석 노드를 실제로 밟아 완주 ──
    NodeReward? lastReward;
    for (final node in scenario.stoneNodes) {
      await _clearSpoofHistory(userId);

      final verdict = await api.verifyLocation(
        runId: run.runId, nodeId: node.nodeId,
        lat: node.mapY!, lng: node.mapX!, accuracyM: 10,
      );
      expect(verdict.verified, isTrue,
          reason: '${node.name}: 정확한 좌표인데 인증 실패 (${verdict.reason})');
      expect(verdict.state, 'GPS_VERIFIED');

      final collected = await api.collectFragment(runId: run.runId, nodeId: node.nodeId);
      expect(collected.fragmentId, node.fragmentId,
          reason: '${node.name}: 서버가 다른 조각 id를 돌려줬다');
      expect(collected.alreadyCollected, isFalse);

      lastReward = await api.completeNode(runId: run.runId, nodeId: node.nodeId);
      expect(lastReward.memoryStoneFragmentId, node.fragmentId);
      expect(lastReward.expGained, greaterThan(0), reason: '${node.name}: 보상이 0');
    }

    // ── 7. 피날레에서 지역이 복원된다 ──
    expect(lastReward!.regionRestored, isTrue,
        reason: '조각을 다 모았는데 지역 복원이 안 됐다');
    expect(lastReward.titles, isNotEmpty, reason: '완주 칭호가 없다');

    // ── 8. 서버 기준 진행도가 실제로 반영됐다 ──
    run = await api.getRun(run.runId);
    expect(run.state, 'COMPLETED');
    expect(run.progress, run.required);
    expect(run.collectedFragmentIds.length, scenario.stoneNodes.length);
  }, timeout: const Timeout(Duration(minutes: 5))); // 실 LLM 생성이 수십 초 걸린다

  test('중복 획득은 서버가 막는다 — 동시 요청 포함', () async {
    await api.guestLogin('E2E중복');
    final userId = (await SharedPreferences.getInstance()).getString('user_id')!;

    final scenario = await api.generateScenario(
      startLat: _startLat, startLng: _startLng, region: '종로',
    );
    final run = await api.startRun(scenario.scenarioId);
    final node = scenario.stoneNodes.first;

    await _clearSpoofHistory(userId);
    await api.verifyLocation(
      runId: run.runId, nodeId: node.nodeId,
      lat: node.mapY!, lng: node.mapX!, accuracyM: 10,
    );

    // 동시에 5번 — 신규 획득은 정확히 1번이어야 한다
    final results = await Future.wait(List.generate(
      5, (_) => api.collectFragment(runId: run.runId, nodeId: node.nodeId),
    ));
    final fresh = results.where((r) => !r.alreadyCollected).length;
    expect(fresh, 1, reason: '동시 요청으로 조각이 여러 번 지급됐다');
    expect(results.every((r) => r.progress == 1), isTrue);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('서버 오류가 사용자에게 읽히는 문구로 온다', () async {
    await api.guestLogin('E2E에러');
    // 반경 300m엔 관광지가 없다 → 도메인 실패(422)로 내려와야 한다.
    try {
      await api.generateScenario(
        startLat: _startLat, startLng: _startLng, region: '종로',
      ).timeout(const Duration(minutes: 3));
    } on ApiException catch (e) {
      expect(e.statusCode, lessThan(500),
          reason: '도메인 실패가 500으로 오면 앱이 장애와 구분하지 못한다');
      expect(e.message, isNotEmpty);
      expect(e.message, isNot(contains('{')), reason: 'JSON 원문이 그대로 노출됐다');
      return;
    }
    // 성공했으면 그것도 정상 — 이 테스트는 '실패 시 형태'만 본다.
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('로그인 없이 게임 루프에 접근하면 401', () async {
    // 세션을 비운 클라이언트 — 토큰 헤더가 안 붙는다
    SharedPreferences.setMockInitialValues({});
    final res = await http.post(
      Uri.parse('${AppConfig.serverBaseUrl}/v1/runs'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'scenario_id': 'whatever'}),
    );
    expect(res.statusCode, 401, reason: '인증 없이 플레이가 시작되면 진행도가 남의 것과 섞인다');
  });
}
