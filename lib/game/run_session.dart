// ============================================================
// [v1] 플레이 세션 — 서버 run을 앱 전역에서 공유
// pipeline: 모바일 클라이언트 / 게임 (진행도 단일 출처)
// 구현(요약): 시나리오 플레이를 시작하면 서버에 run을 만들고 runId를 들고 있는다.
//            GPS 인증·조각 획득·노드 완료는 전부 이 세션을 거친다.
//            ⚠️ 진행도의 출처는 서버다 — 로컬 ScenarioStore는 화면 표시용 캐시일 뿐이라
//            둘이 어긋나면 서버를 따른다(조각 개수·완주 판정을 서버가 쥐고 있다).
// 구현일: 2026-08-04 | 작성: kys (game-loop-ui/kys/v1)
// ------------------------------------------------------------
// [v2] 코스별 run을 저장해 두고 되살린다 — 다시 들어올 때마다 새 run이 생기던 문제.
// 구현(요약): run을 메모리에만 들고 있어 앱을 다시 켜거나 코스 A→B→A로 오가면 새 run이
//            생겼고, 앞서 모은 조각이 새 run엔 없어 피날레에서 서버가 막았다(화면은 엔딩까지 감).
//            start()가 ScenarioStore에 저장된 run_id를 먼저 서버에서 조회해 이어 쓴다.
//            · 서버에 없음(404)·남의 것(403)·코스 불일치 → 새 run
//            · 통신 실패(타임아웃·5xx) → 새 run을 만들지 않고 실패로 둔다(기록이 갈라지지 않게)
//            · 완료된 run도 그대로 되살린다(완료한 코스는 서버에도 완료로 남긴다)
//            · 같은 코스 start가 겹치면 요청 하나를 같이 기다린다(run 중복 생성 방지)
// 구현일: 2026-09-12 | 작성: ljs (mission-strategy-routing/ljs/v1)
// ------------------------------------------------------------
// [v3] 마지막 실패가 다시 해볼 만한 실패인지(errorRetryable) 알려준다.
// 구현(요약): 코스 진행 화면이 조각 기록 실패를 "다시 시도"로만 막을지, 다시 해도 안 되는 실패
//            (4xx 조건 미충족)라 "기록 없이 계속"도 줄지 가르는 근거. 판정은 ApiException.isRetryable
//            (5xx·요청 과다)을 그대로 쓰고, 응답 자체가 없는 통신 실패는 다시 해볼 만한 실패로 본다.
// 구현일: 2026-09-12 | 작성: ljs (mission-strategy-routing/ljs/v1)
// ============================================================
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/run.dart';
import '../store.dart';

class RunSession extends ChangeNotifier {
  RunSession({ApiClient? api}) : _api = api ?? ApiClient();

  /// 앱 전역 단일 인스턴스. 화면들이 각자 run을 만들면 진행도가 갈라진다.
  static final RunSession I = RunSession();

  /// 저장된 run이 서버에 "없다"고 확정되는 응답 — 이때만 새 run을 연다.
  /// 그 밖의 실패(타임아웃·5xx)에 새로 열면 잠깐 끊겼을 뿐인데 기록이 둘로 갈라진다.
  static const _runGoneStatuses = {403, 404};

  final ApiClient _api;

  QuestRun? _run;
  String? _error;
  bool _errorRetryable = false;
  bool _busy = false;

  /// 진행 중인 start 요청 — 코스 허브와 코스 진행 화면이 거의 동시에 부르면 같이 기다린다.
  String? _startingFor;
  Future<bool>? _starting;

  QuestRun? get run => _run;
  String? get runId => _run?.runId;
  String? get error => _error;

  /// 마지막 실패가 다시 해볼 만한 실패인지 — 통신 끊김·5xx·요청 과다면 true,
  /// 조건 미충족 같은 4xx(다시 보내도 같은 답)면 false.
  bool get errorRetryable => _errorRetryable;
  bool get busy => _busy;
  bool get isActive => _run != null;

  int get progress => _run?.progress ?? 0;
  int get required => _run?.required ?? 0;

  /// 이 노드를 GPS 인증했는지(서버 기준).
  bool isVerified(String nodeId) => _run?.verifiedNodeIds.contains(nodeId) ?? false;

  /// 이 조각을 이미 얻었는지(서버 기준).
  bool hasFragment(String fragmentId) =>
      _run?.collectedFragmentIds.contains(fragmentId) ?? false;

  /// 시나리오 플레이 시작 — 이 코스에 저장된 run이 있으면 서버에서 되살려 이어 쓰고,
  /// 없거나 서버에 없으면 새로 연다. 완료된 run도 그대로 되살린다(새로 열지 않는다).
  ///
  /// GPS 판정에 쓸 노드 좌표는 서버가 저장된 시나리오에서 읽는다(server#8) —
  /// 앱이 좌표를 함께 보낼 필요가 없다.
  Future<bool> start(String scenarioId) {
    final pending = _starting;
    if (pending != null && _startingFor == scenarioId) return pending;
    final future = _startOrRestore(scenarioId);
    _startingFor = scenarioId;
    _starting = future;
    future.whenComplete(() {
      if (identical(_starting, future)) {
        _startingFor = null;
        _starting = null;
      }
    });
    return future;
  }

  Future<bool> _startOrRestore(String scenarioId) async {
    final savedId = ScenarioStore.I.runIdOf(scenarioId);
    if (savedId != null && _run?.runId == savedId) return true;
    if (savedId != null) {
      final restored = await _restore(savedId, scenarioId);
      if (restored != null) return restored;
    }
    return _guard(() async {
      final run = await _api.startRun(scenarioId);
      _run = run;
      await ScenarioStore.I.setRunId(scenarioId, run.runId);
    });
  }

  /// 저장된 run을 서버에서 되살린다.
  /// true=되살림 · false=통신 실패(새 run을 열지 않는다) · null=서버에 없음·코스 불일치(새로 연다).
  Future<bool?> _restore(String runId, String scenarioId) async {
    var invalid = false;
    final ok = await _guard(() async {
      try {
        final fetched = await _api.getRun(runId);
        if (fetched.scenarioId == scenarioId) {
          _run = fetched;
        } else {
          invalid = true;
        }
      } on ApiException catch (e) {
        if (!_runGoneStatuses.contains(e.statusCode)) rethrow;
        invalid = true;
      }
    });
    if (!ok) return false;
    return invalid ? null : true;
  }

  /// 서버 기준 진행도 재조회 — 앱 복귀·재시작 시 상태 복원.
  Future<bool> refresh() async {
    final id = runId;
    if (id == null) return false;
    return _guard(() async {
      _run = await _api.getRun(id);
    });
  }

  /// GPS 위치 인증. 거절도 정상 응답이라 결과를 그대로 돌려준다(예외 아님).
  ///
  /// 통과하면 서버 진행도를 다시 읽어 verifiedNodeIds를 최신으로 만든다.
  Future<LocationVerdict?> verify({
    required String nodeId,
    required double lat,
    required double lng,
    double? accuracyM,
  }) async {
    final id = runId;
    if (id == null) {
      _error = '플레이가 시작되지 않았느니라.';
      notifyListeners();
      return null;
    }
    LocationVerdict? verdict;
    final ok = await _guard(() async {
      verdict = await _api.verifyLocation(
        runId: id, nodeId: nodeId, lat: lat, lng: lng, accuracyM: accuracyM,
      );
    });
    if (ok && verdict!.verified) await refresh();
    return ok ? verdict : null;
  }

  /// 조각 획득. GPS 미인증·requires 미충족이면 서버가 403으로 막는다.
  Future<CollectResult?> collect(String nodeId) async {
    final id = runId;
    if (id == null) return null;
    CollectResult? result;
    final ok = await _guard(() async {
      result = await _api.collectFragment(runId: id, nodeId: nodeId);
    });
    if (ok) await refresh();
    return ok ? result : null;
  }

  /// 노드 완료·보상. 갈림길에서 고른 갈래가 있으면 함께 보낸다.
  Future<NodeReward?> complete(String nodeId, {String? choiceId}) async {
    final id = runId;
    if (id == null) return null;
    NodeReward? reward;
    final ok = await _guard(() async {
      reward = await _api.completeNode(runId: id, nodeId: nodeId, choiceId: choiceId);
    });
    if (ok) await refresh();
    return ok ? reward : null;
  }

  /// 플레이 종료(시나리오를 벗어날 때) — 다음 시나리오와 진행도가 섞이지 않게.
  void clear() {
    _run = null;
    _error = null;
    notifyListeners();
  }

  /// 공통 실행 래퍼 — busy/error 상태를 한 곳에서 관리한다.
  /// ApiException은 사용자에게 보여줄 message를 이미 갖고 있으므로 그대로 쓴다.
  Future<bool> _guard(Future<void> Function() body) async {
    _busy = true;
    _error = null;
    _errorRetryable = false;
    notifyListeners();
    try {
      await body();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _errorRetryable = e.isRetryable;
      return false;
    } catch (e) {
      _error = '서버와 통신하지 못했느니라. ($e)';
      _errorRetryable = true; // 응답 자체가 없음 — 연결이 돌아오면 될 수 있다
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
