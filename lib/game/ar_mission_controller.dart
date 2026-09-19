// ============================================================
// [v1] AR 미션 상태기계 — 거리·조준만으로 굴러가는 네 미션
// pipeline: 모바일 클라이언트 / 게임 로직 (AR 연출 판정)
// 구현(요약): AR 타당성 검토(2026-08-19)의 "A층" 구현. 네이티브(ARKit)는 마커를
//            바닥에 앵커링하고 10Hz로 거리·조준각만 보내 주고, 무엇을 켜고 언제
//            드러낼지는 전부 여기서 정한다.
//            · HUNT       발자국 추적 — 가까운 자국부터 하나씩 켜지고, 끝에 도깨비불
//            · RESTORE_AR 기억석 복원 — 부재까지 걸어가 하나씩 수습
//            · PHOTO_FIND 문양 스캔   — 가까이서 정면으로 겨눠 머물면 일치율이 오름
//            · FIND       은신 탐지   — 풀 흔들림이 거리에 따라 커지고, 겨누면 드러남
//            ⚠️ 물체 인식(ML)은 쓰지 않는다. 전부 거리와 시선으로 만드는 연출이다.
//            판정 임계값은 전부 상수로 빼 뒀다 — 실기기 튜닝은 들고 나가서 해야 하고,
//            Dart에 있어야 핫리로드로 고칠 수 있다.
// 구현일: 2026-09-16 | 작성: kys (ar-realtime/kys/v1)
// ============================================================
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../widgets/native_ar_view.dart';

/// AI가 생성하는 미션 타입 중 AR로 연출하는 네 가지.
enum ArMissionType { hunt, restore, photo, find }

/// 서버 미션 타입 문자열 → AR 연출. 모르는 타입은 HUNT로 떨어뜨린다
/// (AI는 8종을 순환 생성하는데 AR 연출이 있는 건 이 넷뿐이다).
ArMissionType arMissionTypeOf(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'RESTORE_AR':
      return ArMissionType.restore;
    case 'PHOTO_FIND':
    case 'PATH_TRACE':
      return ArMissionType.photo;
    case 'FIND':
    case 'QUIZ_FIND':
    case 'DIALOGUE_FIND':
      return ArMissionType.find;
    case 'HUNT':
    default:
      return ArMissionType.hunt;
  }
}

// ── 판정 임계값 (실기기 튜닝 대상) ──────────────────────────
/// 발자국이 켜지기 시작하는 거리. 이보다 멀면 기척만.
const double kTrailWakeM = 6.0;

/// 이 거리 안에 들어오면 그 발자국은 완전히 드러난다.
const double kTrailSolidM = 2.2;

/// 부재를 수습하는 거리 — 팔 뻗으면 닿을 만큼 가야 한다.
const double kPartCollectM = 1.2;

/// 문양 스캔이 시작되는 거리. 멀면 특징점이 안 잡힌다는 설정을 거리로 옮긴 것.
const double kScanStartM = 3.0;

/// 스캔이 가장 빠른 거리.
const double kScanBestM = 1.2;

/// 스캔 완료까지 정면으로 머물러야 하는 시간.
const double kScanHoldSec = 2.5;

/// PHOTO_FIND 방향 화살표(힌트)가 나타나기까지 기다리는 시간 — 그 전엔 숨겨서,
/// 진짜 이미지 인식이나 스스로 찾는 시도를 어림짐작 위치로 방해하지 않는다.
const double kPhotoHintDelaySec = 8.0;

/// 숨은 도깨비의 기척이 느껴지기 시작하는 거리.
const double kFindSenseM = 8.0;

/// 이 거리 안에서 겨누면 드러나기 시작한다.
const double kFindRevealM = 3.0;

/// 드러나기까지 겨누고 있어야 하는 시간.
const double kFindHoldSec = 1.8;

/// 한 미션의 진행 상태 — 화면이 이걸 보고 HUD를 그린다.
@immutable
class ArMissionProgress {
  final ArMissionType type;

  /// 수집·점등된 개수.
  final int done;

  /// 목표 개수.
  final int total;

  /// 0~1. 스캔 진행률처럼 연속적인 진행이 있는 미션에서만 의미가 있다.
  final double ratio;

  /// 지금 화면에 띄울 안내 문구.
  final String status;

  /// 미션이 끝났는지.
  final bool complete;

  /// ARKit이 참조 이미지(안내판·현판)를 실제로 인식했는지 — PHOTO_FIND에서만 의미.
  /// true면 "AR이 타깃을 봤다"는 뜻이라 거리·조준 대신 인식으로 완료된 것.
  final bool imageDetected;

  /// 가장 가까운 목표까지의 거리(m). 없으면 null — HUD의 "— m" 자리.
  final double? nearestM;

  const ArMissionProgress({
    required this.type,
    required this.done,
    required this.total,
    required this.status,
    this.ratio = 0,
    this.complete = false,
    this.nearestM,
    this.imageDetected = false,
  });
}

/// 네 미션의 상태기계. 화면은 이걸 ChangeNotifier로 구독하고,
/// 네이티브 텔레메트리를 [onTelemetry]로 흘려 넣기만 하면 된다.
class ArMissionController extends ChangeNotifier {
  ArMissionController({
    required this.type,
    required List<ArMarkerDef> markers,
    this.onCollected,
    this.onComplete,
  }) : _markers = List.unmodifiable(markers);

  final ArMissionType type;
  final List<ArMarkerDef> _markers;

  /// 목표 하나를 획득한 순간(마커 id). 서버 collect 호출은 화면이 판단한다.
  final void Function(String markerId)? onCollected;

  /// 미션 전체 완료.
  final VoidCallback? onComplete;

  ArViewController? _view;
  final Set<String> _done = {};

  /// 미션이 시작된 시각 — PHOTO_FIND 힌트 노출 지연([kPhotoHintDelaySec]) 판정용.
  final DateTime _startedAt = DateTime.now();

  /// 조준을 시작한 시각 — 머무는 시간 판정용.
  final Map<String, DateTime> _aimStart = {};

  /// 마지막으로 네이티브에 보낸 상태 — 같은 값을 반복해 보내지 않으려고 들고 있는다.
  final Map<String, ArMarkerState> _sent = {};

  double _ratio = 0;
  String _status = '둘러보는 중…';
  double? _nearest;
  bool _complete = false;
  bool _imageDetected = false;

  List<ArMarkerDef> get markers => _markers;

  ArMissionProgress get progress => ArMissionProgress(
        type: type,
        done: _done.length,
        total: _markers.length,
        ratio: _ratio,
        status: _status,
        complete: _complete,
        nearestM: _nearest,
        imageDetected: _imageDetected,
      );

  void attach(ArViewController view) => _view = view;

  /// 네이티브 10Hz 텔레메트리 진입점.
  void onTelemetry(Map<String, ArMarkerReading> readings) {
    if (_complete || readings.isEmpty) return;

    _nearest = readings.entries
        .where((e) => !_done.contains(e.key))
        .map((e) => e.value.distance)
        .fold<double?>(null, (a, b) => a == null || b < a ? b : a);

    switch (type) {
      case ArMissionType.hunt:
        _tickHunt(readings);
        break;
      case ArMissionType.restore:
        _tickRestore(readings);
        break;
      case ArMissionType.photo:
        _tickPhoto(readings);
        break;
      case ArMissionType.find:
        _tickFind(readings);
        break;
    }
    notifyListeners();
  }

  /// ARKit Augmented Images가 참조 사진(안내판·현판)을 인식한 순간 — 네이티브 imageDetected.
  ///
  /// 거리·조준은 "그 근처에 있다"까지만 아는데, 이건 "그것을 보고 있다"다. PHOTO_FIND는
  /// 이 한 번으로 찾기 단계가 끝난다(촬영·검증은 화면이 이어서 한다). 다른 미션은 무시.
  void onImageDetected(String referenceName) {
    if (_complete || type != ArMissionType.photo || _imageDetected) return;
    _imageDetected = true;
    final target = _markers.firstWhere((m) => !_done.contains(m.id), orElse: () => _markers.first);
    _push(target.id, ArMarkerState.solid, scale: 1.15);
    _ratio = 1.0;
    _collect(target.id);          // → _finish가 사진 미션용 문구("담아 가거라")를 쓴다
    notifyListeners();
  }

  /// 탭으로 줍는 미션(부재·발자국 끝의 도깨비불)에서 화면이 호출한다.
  void onTapped(String markerId) {
    if (_done.contains(markerId)) return;
    if (type == ArMissionType.restore || type == ArMissionType.hunt) {
      _collect(markerId);
    }
  }

  // ── HUNT — 다가가면 앞쪽 자국이 하나씩 켜진다 ──────────────
  void _tickHunt(Map<String, ArMarkerReading> r) {
    var lit = 0;
    for (final m in _markers) {
      final read = r[m.id];
      if (read == null) continue;
      final d = read.distance;
      final state = d <= kTrailSolidM
          ? ArMarkerState.solid
          : (d <= kTrailWakeM ? ArMarkerState.ghost : ArMarkerState.hidden);
      // 멀수록 흐리고 작게 — 거리 자체가 연출이 된다.
      final t = ((kTrailWakeM - d) / (kTrailWakeM - kTrailSolidM)).clamp(0.0, 1.0);
      _push(m.id, state, scale: 0.6 + 0.4 * t);
      if (state == ArMarkerState.solid) lit++;
    }
    _ratio = _markers.isEmpty ? 0 : lit / _markers.length;
    _status = lit == 0
        ? '기척이 희미하다 — 더 다가가 보거라'
        : (lit >= _markers.length ? '자국이 모두 드러났느니라' : '자국이 이어지는구나 ($lit/${_markers.length})');
    if (lit >= _markers.length && _markers.isNotEmpty) _finish();
  }

  // ── RESTORE_AR — 부재까지 걸어가 하나씩 수습 ───────────────
  void _tickRestore(Map<String, ArMarkerReading> r) {
    for (final m in _markers) {
      if (_done.contains(m.id)) continue;
      final read = r[m.id];
      if (read == null) continue;
      _push(m.id, ArMarkerState.solid, scale: 1.0);
      if (read.distance <= kPartCollectM) _collect(m.id);
    }
    final left = _markers.length - _done.length;
    _ratio = _markers.isEmpty ? 0 : _done.length / _markers.length;
    _status = left == 0 ? '부재를 모두 거두었느니라' : '흩어진 부재 $left점이 남았느니라';
  }

  // ── PHOTO_FIND — 가까이서 정면으로 머물면 일치율이 오른다 ──
  void _tickPhoto(Map<String, ArMarkerReading> r) {
    final target = _markers.firstWhere(
      (m) => !_done.contains(m.id),
      orElse: () => _markers.isEmpty
          ? const ArMarkerDef(id: '', label: '', color: Color(0xFF2E7E76))
          : _markers.first,
    );
    final read = r[target.id];
    if (read == null) return;
    // 힌트(방향 화살표)는 어림짐작 위치일 뿐이다 — 곧바로 보여주면 그 자리를
    // 진짜 타깃인 것처럼 믿게 된다. 스스로 찾을 시간을 준 뒤에만 드러낸다.
    final hintReady =
        DateTime.now().difference(_startedAt).inMilliseconds >= kPhotoHintDelaySec * 1000;
    _push(target.id, hintReady ? ArMarkerState.solid : ArMarkerState.hidden);

    if (read.distance > kScanStartM) {
      _aimStart.remove(target.id);
      _ratio = 0;
      _status = '너무 멀어 문양이 잡히지 않는구나';
      return;
    }
    if (!read.isAimed) {
      _aimStart.remove(target.id);
      _ratio = 0;
      _status = '문양을 화면 한가운데에 두거라';
      return;
    }
    // 가까울수록 빨리 찬다 — 3m에서 1배, 1.2m 이내면 2배.
    final near = ((kScanStartM - read.distance) / (kScanStartM - kScanBestM)).clamp(0.0, 1.0);
    final speed = 1.0 + near;
    final start = _aimStart[target.id] ??= DateTime.now();
    final held = DateTime.now().difference(start).inMilliseconds / 1000.0;
    _ratio = (held * speed / kScanHoldSec).clamp(0.0, 1.0);
    _status = '문양을 새기는 중… ${(_ratio * 100).round()}%';
    if (_ratio >= 1.0) _collect(target.id);
  }

  // ── FIND — 풀이 흔들리고, 겨누고 머물면 드러난다 ───────────
  void _tickFind(Map<String, ArMarkerReading> r) {
    for (final m in _markers) {
      if (_done.contains(m.id)) continue;
      final read = r[m.id];
      if (read == null) continue;
      final d = read.distance;

      if (d > kFindSenseM) {
        _push(m.id, ArMarkerState.hidden);
        _aimStart.remove(m.id);
        _status = '아무 기척도 없구나';
        continue;
      }
      // 가까울수록 풀이 크게 흔들린다 — "숨긴 느낌"은 여기서 나온다.
      final near = ((kFindSenseM - d) / kFindSenseM).clamp(0.0, 1.0);
      _push(m.id, ArMarkerState.ghost, scale: 0.7 + 0.8 * near);

      if (d > kFindRevealM || !read.isAimed) {
        _aimStart.remove(m.id);
        _ratio = 0;
        _status = d > kFindRevealM ? '풀이 흔들린다 — 더 다가가 보거라' : '그 자리를 가만히 응시하거라';
        continue;
      }
      final start = _aimStart[m.id] ??= DateTime.now();
      final held = DateTime.now().difference(start).inMilliseconds / 1000.0;
      _ratio = (held / kFindHoldSec).clamp(0.0, 1.0);
      _status = '무언가 모습을 드러내려 하는구나…';
      if (_ratio >= 1.0) {
        _push(m.id, ArMarkerState.solid, scale: 1.0);
        _collect(m.id);
      }
    }
  }

  // ── 공통 ───────────────────────────────────────────────
  void _collect(String id) {
    if (!_done.add(id)) return;
    onCollected?.call(id);
    if (_done.length >= _markers.length && _markers.isNotEmpty) _finish();
  }

  void _finish() {
    if (_complete) return;
    _complete = true;
    // 사진 미션의 '완료'는 "찾았다"까지다 — 조각은 촬영·검증을 거쳐 화면이 준다.
    // 여기서 "조각을 찾았느니라"라고 하면 아직 셔터도 안 눌렀는데 끝난 것처럼 읽힌다.
    _status = type == ArMissionType.photo
        ? '찾았구나 — 이제 그것을 담아 가거라'
        : '기억석 조각을 찾았느니라!';
    onComplete?.call();
  }

  /// 같은 상태를 10Hz로 반복 전송하면 채널만 먹는다 — 바뀔 때만 보낸다.
  /// (scale은 연속값이라 상태가 같아도 흐름이 끊기지 않게 함께 실어 보낸다.)
  void _push(String id, ArMarkerState state, {double scale = 1.0}) {
    final changed = _sent[id] != state;
    _sent[id] = state;
    if (changed || state == ArMarkerState.ghost) {
      _view?.setMarkerState(id, state, scale: scale);
    }
  }
}

// ── 미션별 마커 배치 ─────────────────────────────────────────
// 계획서(2026-08-19)의 "미션 JSON → 배치 규칙 한 겹". type·개수가 그대로 파라미터다.
// 한국은 VPS(세계좌표 앵커)가 사실상 없으니 나침반을 쓰지 않고 **세션 시작 시점
// 카메라 기준 상대 배치**로 둔다 — "정면 12m 바닥에서 시작해 저쪽으로 이어지는" 식.

/// 미션 타입과 목표 개수로 마커 배치를 만든다.
///
/// [count]는 AI 미션 JSON의 parts·target_count 등에서 온다(없으면 타입별 기본값).
/// 색은 화면이 테마에서 골라 넘긴다.
List<ArMarkerDef> buildArMarkers({
  required ArMissionType type,
  required Color primary,
  required Color accent,
  int? count,
}) {
  switch (type) {
    case ArMissionType.hunt:
      // 정면으로 이어지는 발자국. 좌우로 조금씩 엇갈려야 걸어온 자취처럼 보인다.
      final n = (count ?? 5).clamp(2, 12);
      return [
        for (var i = 0; i < n; i++)
          ArMarkerDef(
            id: 'step$i',
            label: '자국 ${i + 1}',
            color: primary,
            kind: ArMarkerKind.footprint,
            forward: 1.4 + i * 1.3,
            right: (i.isEven ? -0.22 : 0.22),
            down: 1.35, // 눈높이에서 바닥까지 — 평면을 찾으면 그 높이로 다시 앉는다
            state: ArMarkerState.hidden,
          ),
      ];

    case ArMissionType.restore:
      // 흩어진 부재 — 한 바퀴 둘러봐야 다 보이게 방사형으로 흩는다.
      final n = (count ?? 3).clamp(2, 8);
      return [
        for (var i = 0; i < n; i++)
          ArMarkerDef(
            id: 'part$i',
            label: '부재 ${i + 1}',
            color: i == 0 ? accent : primary,
            kind: ArMarkerKind.part,
            forward: 2.2 + (i % 3) * 1.1,
            right: -1.6 + (3.2 / (n - 1).clamp(1, 7)) * i,
            down: 1.2,
            state: ArMarkerState.solid,
          ),
      ];

    case ArMissionType.photo:
      // 문양 하나. 눈높이 근처 벽면이라 바닥 앵커링에서 제외된다(Swift에서 pattern은 제외).
      return [
        ArMarkerDef(
          id: 'pattern',
          label: '문양',
          color: accent,
          kind: ArMarkerKind.pattern,
          forward: 2.6,
          right: 0,
          down: 0.1,
          // 힌트 화살표는 kPhotoHintDelaySec가 지나야 드러난다(ArMissionController._tickPhoto).
          state: ArMarkerState.hidden,
        ),
      ];

    case ArMissionType.find:
      // 숨은 자리 — 처음엔 안 보인다. 다가가면 풀이 흔들리기 시작한다.
      final n = (count ?? 1).clamp(1, 3);
      return [
        for (var i = 0; i < n; i++)
          ArMarkerDef(
            id: 'hide$i',
            label: '기척',
            color: primary,
            kind: ArMarkerKind.hidden,
            forward: 3.4 + i * 1.6,
            right: i.isEven ? 0.9 : -1.1,
            down: 1.3,
            state: ArMarkerState.hidden,
          ),
      ];
  }
}
