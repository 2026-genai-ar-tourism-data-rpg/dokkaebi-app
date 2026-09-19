// ============================================================
// [v1] 도깨비불 길들이기 — 제자리에서 폰을 돌려 불꽃 3마리를 모으는 AR 미션 상태기계
// pipeline: 모바일 클라이언트 / 게임 로직 (PHOTO_FIND·PATH_TRACE의 촬영 단계를 대체)
// 구현(요약): 명세 "AR 미션 교체 작업 명세 v1.0 (2026-09-19)".
//   · 왜 교체: 촬영+OCR은 글자·조명·구도에 좌우돼 현장에서 가장 끊기기 쉬웠다. 이 게임은
//     조준각과 시간만 쓴다 — 우리가 통제하는 입력뿐이라 어디서든 같은 난이도.
//   · 규칙: 3마리, 동시에 1마리만 활성, 중앙 조준 ≤6°를 연속 2,000ms 유지하면 수집,
//     800ms 흡수 연출 후 다음 불꽃. 걷기·거리 조건 없음. 제한 시간·게임오버 없음.
//   · 판정은 단조 시계의 실제 경과시간으로 — 프레임을 세지 않는다. 관측이 300ms 이상
//     끊기거나 tracking이 불안정하면 유지 시간을 버린다(누적 정지가 아니라 초기화).
//   · 중단·복원: 모은 불꽃 ID는 저장·복원하고 진행 중이던 게이지만 버린다. 서버 기록
//     (collect)은 상위 화면 담당 — 여기선 "3마리 다 모았다"까지만 알린다.
//   · 이 파일은 센서를 모른다. 관측(조준각·부호 yaw·tracking)과 시계를 주입받아 돈다 —
//     그래서 테스트가 실기기 없이 3회 수집을 끝까지 돌릴 수 있다.
//   · 공용 ArMarkerReading.isAimed(17°)는 건드리지 않는다. 이 게임만의 6°다.
// 구현일: 2026-09-19 | 작성: kys (fire-capture/kys/v1)
// ============================================================
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// 게임 버전 — 로컬 저장 키에 들어간다. 규칙이 바뀌면 올려서 구버전 진행과 섞이지 않게.
const String kFireGameVersion = 'fire_capture_v1';

// ── 튜닝값 (현장 테스트로 조정. 명세 3쪽 초기값) ────────────────
/// 조준 허용 오차 — 카메라 전방과 목표 방향의 3D 각도. 손떨림(2~4°)을 고려해 빡빡한 편.
const double kFireAimToleranceRad = 6 * math.pi / 180;

/// 유효 조준을 이만큼 연속 유지하면 수집.
const int kFireHoldMs = 2000;

/// 수집 후 흡수 연출 시간 — 이 동안 판정 잠금.
const int kFireCaptureMs = 800;

/// 관측이 이 이상 끊기면 유지 시간 초기화(누적 정지가 아님).
const int kFireObserveGapMs = 300;

/// 이 시간 동안 진전이 없으면 방향 힌트를 더 강하게.
const int kFireStalledHintMs = 8000;

/// 목표 수 — 명세 고정값. 마커 배치도 3개 기준(+32°, -26°, +12°).
const int kFireTargetCount = 3;

/// 시작 카메라 기준 상대 방향(도). 이동 없이 좌우 회전만으로 닿는 각도.
const List<double> kFireYawDegrees = [32, -26, 12];

/// 불꽃이 떠 있는 거리(m) — 렌더링 크기용. 판정엔 안 쓴다(거리 조건 없음).
const double kFireDistanceM = 2.4;

enum FireState { intro, seek, hold, capture, sync, done, paused }

/// 좌우 힌트 — 목표가 화면 밖일 때 어느 쪽으로 돌릴지.
enum FireHint { none, left, right, center }

/// 불꽃 하나. id는 명세대로 fire_1~3.
@immutable
class FireTarget {
  final String id;
  final double yawRad;
  const FireTarget(this.id, this.yawRad);

  static List<FireTarget> defaults() => [
        for (var i = 0; i < kFireTargetCount; i++)
          FireTarget('fire_${i + 1}', kFireYawDegrees[i] * math.pi / 180),
      ];
}

/// 네이티브(또는 터치 모드)가 활성 목표에 대해 보내는 관측 1건.
@immutable
class FireObservation {
  /// 카메라 전방 ↔ 목표의 3D 각도(라디안). 0이면 정중앙.
  final double aimErrorRad;

  /// 부호 있는 수평 각(라디안). +면 목표가 오른쪽 → "오른쪽으로 돌려라".
  final double yawDeltaRad;

  /// ARKit tracking이 정상인가. 아니면 유지 시간을 버린다.
  final bool tracking;

  const FireObservation({
    required this.aimErrorRad,
    required this.yawDeltaRad,
    this.tracking = true,
  });
}

/// 화면이 그리는 스냅샷.
@immutable
class FireProgress {
  final FireState state;
  final int collected;
  final int total;

  /// 지금 겨눠야 할 불꽃. 다 모았으면 null.
  final String? activeId;

  /// 유지 게이지 0~1.
  final double holdRatio;

  /// 조준 원 안에 있는가(= HOLD 중).
  final bool aimed;
  final FireHint hint;

  /// 8초간 진전 없음 — 힌트를 크게.
  final bool stalled;
  final String status;

  const FireProgress({
    required this.state,
    required this.collected,
    required this.total,
    required this.activeId,
    required this.holdRatio,
    required this.aimed,
    required this.hint,
    required this.stalled,
    required this.status,
  });
}

/// 도깨비불 3마리 수집 상태기계.
///
/// 시계([now])와 관측([observe])을 주입받는다. 화면은 [progress]를 구독하고,
/// [onCaptured]·[onAllCaptured]로 연출·서버 기록을 잇는다.
class FireCaptureController extends ChangeNotifier {
  FireCaptureController({
    List<FireTarget>? targets,
    DateTime Function()? now,
    Set<String> restoredCollected = const {},
    this.onCaptured,
    this.onAllCaptured,
  })  : _targets = List.unmodifiable(targets ?? FireTarget.defaults()),
        _now = now ?? DateTime.now,
        _collected = {...restoredCollected};

  final List<FireTarget> _targets;
  final DateTime Function() _now;
  final Set<String> _collected;

  /// 불꽃 하나 수집된 순간(id).
  final void Function(String id)? onCaptured;

  /// 3마리 전부 — 상위가 서버 collect를 부른다. 정확히 한 번만 불린다.
  final VoidCallback? onAllCaptured;

  FireState _state = FireState.intro;
  DateTime? _holdStart;
  DateTime? _captureStart;
  DateTime? _lastObserved;
  DateTime? _lastProgress;
  double _holdRatio = 0;
  bool _aimedNow = false;
  FireHint _hint = FireHint.none;
  bool _allFired = false;
  String _status = '골목에 흩어진 불빛 세 마리를 모아 주세요';

  List<FireTarget> get targets => _targets;
  Set<String> get collectedIds => Set.unmodifiable(_collected);
  FireState get state => _state;

  FireTarget? get activeTarget {
    for (final t in _targets) {
      if (!_collected.contains(t.id)) return t;
    }
    return null;
  }

  FireProgress get progress => FireProgress(
        state: _state,
        collected: _collected.length,
        total: _targets.length,
        activeId: activeTarget?.id,
        holdRatio: _holdRatio,
        aimed: _aimedNow,
        hint: _hint,
        stalled: _isStalled(),
        status: _status,
      );

  // ── 전이 ────────────────────────────────────────────────
  /// INTRO → SEEK. 복원된 진행이 이미 완료면 곧장 SYNC로.
  void start() {
    if (_state != FireState.intro) return;
    if (activeTarget == null) {
      _enterSync();
      return;
    }
    _state = FireState.seek;
    _lastProgress = _now();
    _status = '잠든 초롱을 깨워줘';
    notifyListeners();
  }

  /// 백그라운드·권한 창·힌트 화면 — 판정 정지. 게이지는 버린다(명세: PAUSED→SEEK).
  void pause() {
    if (_state == FireState.done || _state == FireState.sync || _state == FireState.intro) return;
    if (_state == FireState.paused) return;
    _state = FireState.paused;
    _resetHold();
    _holdRatio = 0;          // 게이지도 버린다 — 복귀 후 화면에 옛 게이지가 남으면 안 된다
    notifyListeners();
  }

  void resume() {
    if (_state != FireState.paused) return;
    // capture 중 멈췄으면 그 불꽃은 이미 수집 집합에 있다 → 다음 목표부터.
    _state = activeTarget == null ? FireState.sync : FireState.seek;
    if (_state == FireState.sync) _fireAllOnce();
    _lastObserved = null;
    _lastProgress = _now();
    notifyListeners();
  }

  /// 서버 기록 성공 — 화면 복귀.
  void markSynced() {
    if (_state != FireState.sync) return;
    _state = FireState.done;
    _status = '초롱이 깨어났어요';
    notifyListeners();
  }

  /// 서버 기록 실패 — 결과는 보존, 기록만 재시도(상태는 sync에 머문다).
  void markSyncFailed() {
    if (_state != FireState.sync) return;
    _status = '기록에 실패했어요 — 다시 시도해 주세요';
    notifyListeners();
  }

  // ── 관측 ────────────────────────────────────────────────
  /// 활성 목표에 대한 관측. 네이티브 10Hz 또는 터치 모드 타이머가 부른다.
  void observe(FireObservation obs) {
    final now = _now();
    _tickCapture(now);
    if (_state != FireState.seek && _state != FireState.hold) {
      _lastObserved = now;
      return;
    }

    // 관측 공백 — 누적을 멈추는 게 아니라 버린다(명세). 이번 관측부터 다시 센다.
    final last = _lastObserved;
    final gapped = last != null && now.difference(last).inMilliseconds > kFireObserveGapMs;
    _lastObserved = now;

    _hint = _hintFor(obs.yawDeltaRad);

    // 공백·추적 불안정 = "유지 시간 초기화". 관측 자체를 버리는 게 아니다 — 초기화한 뒤
    // 이번 관측을 정상 평가해서, 조준 중이면 여기서 새 hold가 시작된다. (초기 구현은 이
    // 관측을 삼켜서 수집 연출 800ms 뒤 첫 관측이 늘 낭비됐다.)
    if (gapped && _state == FireState.hold) _toSeek();
    if (!obs.tracking) {
      if (_state == FireState.hold) _toSeek();
      _aimedNow = false;
      _holdRatio = 0;
      _status = '잠시 멈춰 주변을 비춰 주세요';
      notifyListeners();
      return;
    }

    final aimed = obs.aimErrorRad <= kFireAimToleranceRad;
    _aimedNow = aimed;
    if (!aimed) {
      if (_state == FireState.hold) _toSeek();
      _holdRatio = 0;
      _status = _hintText(_hint);
      notifyListeners();
      return;
    }

    // 조준 안 — HOLD. 시작 시각을 잡고 실제 경과로 게이지를 채운다.
    if (_state == FireState.seek) {
      _state = FireState.hold;
      _holdStart = now;
    }
    final held = now.difference(_holdStart!).inMilliseconds;
    _holdRatio = (held / kFireHoldMs).clamp(0.0, 1.0);
    _status = '좋아요, ${((kFireHoldMs - held) / 1000).clamp(0, 2).toStringAsFixed(1)}초만 유지하세요';
    if (held >= kFireHoldMs) _capture(now);
    notifyListeners();
  }

  /// 시간만 흘려보낼 때(관측 없이) — 흡수 연출 종료 판정용. 화면 타이머가 부른다.
  void tick() {
    if (_tickCapture(_now())) notifyListeners();
  }

  // ── 내부 ────────────────────────────────────────────────
  void _capture(DateTime now) {
    final t = activeTarget;
    if (t == null || _state == FireState.capture) return;
    // 원자적 전환 — 같은 프레임에 관측이 반복돼도 두 번 세지 않는다.
    _collected.add(t.id);
    _state = FireState.capture;
    _captureStart = now;
    _lastProgress = now;
    _resetHold();
    _holdRatio = 1;
    _status = '불꽃이 초롱으로 들어갔어요';
    onCaptured?.call(t.id);
  }

  /// CAPTURE → SEEK(다음 불꽃) 또는 SYNC. 800ms 지났을 때만. 전이가 있었으면 true.
  bool _tickCapture(DateTime now) {
    if (_state != FireState.capture) return false;
    final start = _captureStart;
    if (start == null || now.difference(start).inMilliseconds < kFireCaptureMs) return false;
    _holdRatio = 0;
    if (activeTarget == null) {
      _enterSync();
    } else {
      _state = FireState.seek;
      _status = '잠든 초롱을 깨워줘';
    }
    return true;
  }

  void _enterSync() {
    _state = FireState.sync;
    _status = '기록 중…';
    _fireAllOnce();
  }

  void _fireAllOnce() {
    if (_allFired) return;
    _allFired = true;
    onAllCaptured?.call();
  }

  void _toSeek() {
    _state = FireState.seek;
    _resetHold();
  }

  void _resetHold() {
    _holdStart = null;
    _aimedNow = false;
  }

  bool _isStalled() {
    final p = _lastProgress;
    if (p == null || (_state != FireState.seek && _state != FireState.hold)) return false;
    return _now().difference(p).inMilliseconds >= kFireStalledHintMs;
  }

  static FireHint _hintFor(double yawDelta) {
    if (yawDelta.abs() <= kFireAimToleranceRad) return FireHint.center;
    return yawDelta > 0 ? FireHint.right : FireHint.left;
  }

  static String _hintText(FireHint h) {
    switch (h) {
      case FireHint.left:
        return '왼쪽으로 천천히 비춰요';
      case FireHint.right:
        return '오른쪽으로 천천히 비춰요';
      case FireHint.center:
        return '조금만 더 가운데로';
      case FireHint.none:
        return '잠든 초롱을 깨워줘';
    }
  }
}

/// 로컬 저장 키 — userId + runId + nodeId + 게임 버전. 로그아웃·다른 run과 섞이지 않게.
String fireProgressKey({required String userId, required String runId, required String nodeId}) =>
    'fire:$kFireGameVersion:$userId:$runId:$nodeId';
