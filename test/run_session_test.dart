// ============================================================
// [v1] 플레이 세션 테스트 — 앱 재시작·코스 전환 후에도 같은 서버 run을 이어 쓰는가
// pipeline: 모바일 클라이언트 / 테스트 (run 중복 생성 회귀 방지)
// 구현(요약): 가짜 서버(MockClient)가 받은 요청을 기록해, start()가 저장된 run_id가 있으면
//            조회만 하고(POST 없음) 서버에 없을 때만 새로 여는지, 통신 실패엔 새로 열지 않는지,
//            완료된 run도 되살리는지, 코스 전환·동시 호출에서 run이 늘지 않는지 확인.
// 구현일: 2026-09-12 | 작성: ljs (mission-strategy-routing/ljs/v1)
// ------------------------------------------------------------
// [v2] 실패 종류(errorRetryable) — 4xx 조건 미충족은 다시 해도 안 되는 실패, 5xx는 다시 해볼 만한 실패.
// 구현일: 2026-09-12 | 작성: ljs (mission-strategy-routing/ljs/v1)
// ============================================================
import 'dart:convert';

import 'package:dokkaebi_app/api/api_client.dart';
import 'package:dokkaebi_app/game/run_session.dart';
import 'package:dokkaebi_app/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _courseA = 'scn_A';
const _courseB = 'scn_B';

/// 서버 run 응답(POST /v1/runs · GET /v1/runs/{id} 공통 필드).
http.Response _runResponse(String runId, String scenarioId, {String state = 'IN_PROGRESS'}) =>
    http.Response(
      jsonEncode({
        'run_id': runId,
        'scenario_id': scenarioId,
        'state': state,
        'progress': 0,
        'required': 4,
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// 새 run 열기 응답 — run_id는 코스 ID로 만든다(어느 코스의 run인지 테스트에서 바로 보이게).
http.Response _openNewRun(http.Request req) {
  final scenarioId = (jsonDecode(req.body) as Map<String, dynamic>)['scenario_id'] as String;
  return _runResponse('run-$scenarioId', scenarioId);
}

/// 받은 요청을 "METHOD /path"로 기록하는 가짜 서버.
class _FakeServer {
  _FakeServer(this.respond);

  final http.Response Function(http.Request req) respond;
  final calls = <String>[];

  /// 메모리에 run이 없는 새 세션 — 앱을 막 켠 상태와 같다.
  RunSession newSession() => RunSession(
        api: ApiClient(
          baseUrl: 'http://test',
          client: MockClient((req) async {
            calls.add('${req.method} ${req.url.path}');
            return respond(req);
          }),
        ),
      );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ScenarioStore.I.load();
  });

  group('서버 run 저장·복원', () {
    test('저장된 run이 없으면 새로 열고 번호를 저장한다', () async {
      final server = _FakeServer(_openNewRun);
      final session = server.newSession();

      expect(await session.start(_courseA), isTrue);
      expect(server.calls, ['POST /v1/runs']);
      expect(ScenarioStore.I.runIdOf(_courseA), 'run-scn_A');
    });

    test('앱을 다시 켜면 저장된 run을 조회해 이어 쓴다 — 새로 열지 않는다', () async {
      await ScenarioStore.I.setRunId(_courseA, 'r1');
      await ScenarioStore.I.load(); // 앱 재시작 시뮬 — 저장소에서 다시 읽는다
      final server = _FakeServer((_) => _runResponse('r1', _courseA));
      final session = server.newSession();

      expect(await session.start(_courseA), isTrue);
      expect(server.calls, ['GET /v1/runs/r1']);
      expect(session.runId, 'r1');
    });

    test('서버에 run이 없으면(404) 새로 열고 번호를 바꾼다', () async {
      await ScenarioStore.I.setRunId(_courseA, 'r1');
      final server = _FakeServer((req) => req.method == 'GET'
          ? http.Response('{"message":"not found"}', 404)
          : _openNewRun(req));
      final session = server.newSession();

      expect(await session.start(_courseA), isTrue);
      expect(server.calls, ['GET /v1/runs/r1', 'POST /v1/runs']);
      expect(ScenarioStore.I.runIdOf(_courseA), 'run-scn_A');
    });

    test('저장된 run이 다른 코스 것이면 새로 연다', () async {
      await ScenarioStore.I.setRunId(_courseA, 'r1');
      final server = _FakeServer((req) => req.method == 'GET'
          ? _runResponse('r1', _courseB)
          : _openNewRun(req));
      final session = server.newSession();

      expect(await session.start(_courseA), isTrue);
      expect(server.calls, ['GET /v1/runs/r1', 'POST /v1/runs']);
      expect(session.runId, 'run-scn_A');
    });

    test('통신 실패(500)면 새로 열지 않고 저장된 번호를 지킨다', () async {
      await ScenarioStore.I.setRunId(_courseA, 'r1');
      final server = _FakeServer((_) => http.Response('error', 500));
      final session = server.newSession();

      expect(await session.start(_courseA), isFalse);
      expect(server.calls, ['GET /v1/runs/r1']);
      expect(session.isActive, isFalse);
      expect(session.error, isNotNull);
      expect(ScenarioStore.I.runIdOf(_courseA), 'r1');
    });

    test('완료된 run도 그대로 되살린다 — 다시 열어도 새 run을 만들지 않는다', () async {
      await ScenarioStore.I.setRunId(_courseA, 'r1');
      final server = _FakeServer((_) => _runResponse('r1', _courseA, state: 'COMPLETED'));
      final session = server.newSession();

      expect(await session.start(_courseA), isTrue);
      expect(await session.start(_courseA), isTrue); // 같은 실행 중 코스를 다시 열기
      expect(server.calls, ['GET /v1/runs/r1']);
      expect(session.run!.isCompleted, isTrue);
    });

    test('코스 A→B→A로 오가도 A의 run을 이어 쓴다', () async {
      final server = _FakeServer((req) => req.method == 'GET'
          ? _runResponse('run-scn_A', _courseA)
          : _openNewRun(req));
      final session = server.newSession();

      await session.start(_courseA);
      await session.start(_courseB);
      await session.start(_courseA);

      expect(server.calls, ['POST /v1/runs', 'POST /v1/runs', 'GET /v1/runs/run-scn_A']);
      expect(session.runId, 'run-scn_A');
    });

    test('같은 코스 start가 겹쳐도 run은 하나만 연다', () async {
      final server = _FakeServer(_openNewRun);
      final session = server.newSession();

      final results = await Future.wait([session.start(_courseA), session.start(_courseA)]);

      expect(results, [true, true]);
      expect(server.calls, ['POST /v1/runs']);
    });
  });

  group('실패 종류', () {
    test('조건 미충족(4xx) 실패는 다시 해도 안 되는 실패로 표시한다', () async {
      final server = _FakeServer((req) => req.url.path == '/v1/runs'
          ? _openNewRun(req)
          : http.Response(jsonEncode({'message': '먼저 그 자리에 당도해야 하느니라.'}), 403,
              headers: {'content-type': 'application/json; charset=utf-8'}));
      final session = server.newSession();
      await session.start(_courseA);

      expect(await session.collect('n1'), isNull);
      expect(session.errorRetryable, isFalse);
      expect(session.error, contains('당도'));
    });

    test('통신 실패·5xx는 다시 해볼 만한 실패로 표시한다', () async {
      final server = _FakeServer((req) =>
          req.url.path == '/v1/runs' ? _openNewRun(req) : http.Response('error', 500));
      final session = server.newSession();
      await session.start(_courseA);

      expect(await session.collect('n1'), isNull);
      expect(session.errorRetryable, isTrue);
    });
  });
}
