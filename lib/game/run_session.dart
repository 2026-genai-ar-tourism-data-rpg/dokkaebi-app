// ============================================================
// [v1] 플레이 세션 — 서버 run을 앱 전역에서 공유
// pipeline: 모바일 클라이언트 / 게임 (진행도 단일 출처)
// 구현(요약): 시나리오 플레이를 시작하면 서버에 run을 만들고 runId를 들고 있는다.
//            GPS 인증·조각 획득·노드 완료는 전부 이 세션을 거친다.
//            ⚠️ 진행도의 출처는 서버다 — 로컬 ScenarioStore는 화면 표시용 캐시일 뿐이라
//            둘이 어긋나면 서버를 따른다(조각 개수·완주 판정을 서버가 쥐고 있다).
// 구현일: 2026-08-04 | 작성: kys (game-loop-ui/kys/v1)
// ============================================================
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/run.dart';

class RunSession extends ChangeNotifier {
  RunSession({ApiClient? api}) : _api = api ?? ApiClient();

  /// 앱 전역 단일 인스턴스. 화면들이 각자 run을 만들면 진행도가 갈라진다.
  static final RunSession I = RunSession();

  final ApiClient _api;

  QuestRun? _run;
  String? _error;
  bool _busy = false;

  QuestRun? get run => _run;
  String? get runId => _run?.runId;
  String? get error => _error;
  bool get busy => _busy;
  bool get isActive => _run != null;

  int get progress => _run?.progress ?? 0;
  int get required => _run?.required ?? 0;

  /// 이 노드를 GPS 인증했는지(서버 기준).
  bool isVerified(String nodeId) => _run?.verifiedNodeIds.contains(nodeId) ?? false;

  /// 이 조각을 이미 얻었는지(서버 기준).
  bool hasFragment(String fragmentId) =>
      _run?.collectedFragmentIds.contains(fragmentId) ?? false;

  /// 시나리오 플레이 시작. 이미 같은 시나리오를 돌고 있으면 그대로 이어 간다.
  Future<bool> start(String scenarioId) async {
    if (_run?.scenarioId == scenarioId && !_run!.isCompleted) return true;
    return _guard(() async {
      _run = await _api.startRun(scenarioId);
    });
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
    notifyListeners();
    try {
      await body();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = '서버와 통신하지 못했느니라. ($e)';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
