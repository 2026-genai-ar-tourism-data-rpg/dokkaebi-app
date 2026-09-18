// ============================================================
// [v1] AR 미션 상태기계 — 거리·조준만으로 굴러가는 네 미션
// pipeline: 모바일 클라이언트 / 게임 로직 (AR 연출 판정)
// 구현(요약): AR 타당성 검토(2026-08-19)의 "A층" 구현. 네이티브(ARKit)는 마커를
//            바닥에 앵커링하고 10Hz로 거리·조준각만 보내 주고, 무엇을 켜고 언제
//            드러낼지는 전부 여기서 정한다.
//            · HUNT       엽전 줍기 — 다가가면 반짝이고, 탭하거나 바로 앞까지 가면 줍는다(v2)
//            · RESTORE_AR 기억석 복원 — 부재까지 걸어가 하나씩 수습
//            · PHOTO_FIND 문양 스캔   — 가까이서 정면으로 겨눠 머물면 일치율이 오름
//            · FIND       은신 탐지   — 풀 흔들림이 거리에 따라 커지고, 겨누면 드러남
//            ⚠️ 물체 인식(ML)은 쓰지 않는다. 전부 거리와 시선으로 만드는 연출이다.
//            판정 임계값은 전부 상수로 빼 뒀다 — 실기기 튜닝은 들고 나가서 해야 하고,
//            Dart에 있어야 핫리로드로 고칠 수 있다.
// 구현일: 2026-09-16 | 작성: kys (ar-realtime/kys/v1)
// ------------------------------------------------------------
// [v2] HUNT 발자국 → 도깨비가 흘리고 간 엽전 줍기.
// 구현(요약): 다가가면 엽전이 흐릿하게 보이다가 반짝이고, 반짝일 때 탭하거나 바로 앞까지
//            가면 줍는다(주운 엽전은 사라진다). 다 주우면 완료. 전엔 다 켜지기만 하면 끝났다.
//            가까울수록 크게(coinScaleFor) — 크기가 바뀌면 상태가 같아도 다시 보낸다.
//            엽전은 허리께 높이에 떠 있고(바닥이면 발밑이라 폰을 숙여야 보였다) 2.4m 앞부터 놓는다.
//            뷰가 붙기 전 지시는 기록하지 않고, 마커 배치 직후 resync로 다시 보낸다.
// 구현일: 2026-09-18 | 작성: ljs (npc-character-set/ljs/v1)
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
/// 엽전이 흐릿하게 보이기 시작하는 거리. 이보다 멀면 기척만.
const double kTrailWakeM = 6.0;

/// 이 거리 안에 들어오면 엽전이 반짝인다 — 이때부터 탭으로 주울 수 있다.
const double kTrailSolidM = 2.2;

/// 이 거리까지 가면 탭하지 않아도 줍는다(AR에서 작은 물체 탭이 빗나가도 막히지 않게).
const double kCoinPickM = 1.2;

/// 엽전 원근 — 가장 먼(kTrailWakeM) 엽전과 줍기 직전(kCoinPickM) 엽전의 크기 배율.
/// admin 방향키 이동은 폰이 실제로 안 움직여 화면 원근이 없으니 이 배율이 곧 원근이다.
const double kCoinScaleFar = 0.5;
const double kCoinScaleNear = 1.8;

/// 크기 배율이 이만큼 바뀌어야 네이티브에 다시 보낸다(10Hz 채널 낭비 방지).
const double _kScaleEpsilon = 0.02;

/// 거리 → 엽전 크기 배율. 가까울수록 크다(kCoinScaleFar~kCoinScaleNear).
double coinScaleFor(double distanceM) {
  final t = ((kTrailWakeM - distanceM) / (kTrailWakeM - kCoinPickM)).clamp(0.0, 1.0);
  return kCoinScaleFar + (kCoinScaleNear - kCoinScaleFar) * t;
}

/// HUNT 엽전 그림(Flutter 에셋) — 네이티브가 판에 붙인다.
const String kCoinImageAsset = 'assets/game/ar/coin_drop_game.webp';

/// 부재를 수습하는 거리 — 팔 뻗으면 닿을 만큼 가야 한다.
const double kPartCollectM = 1.2;

/// 문양 스캔이 시작되는 거리. 멀면 특징점이 안 잡힌다는 설정을 거리로 옮긴 것.
const double kScanStartM = 3.0;

/// 스캔이 가장 빠른 거리.
const double kScanBestM = 1.2;

/// 스캔 완료까지 정면으로 머물러야 하는 시간.
const double kScanHoldSec = 2.5;

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

  /// 조준을 시작한 시각 — 머무는 시간 판정용.
  final Map<String, DateTime> _aimStart = {};

  /// 마지막으로 네이티브에 보낸 상태 — 같은 값을 반복해 보내지 않으려고 들고 있는다.
  final Map<String, ArMarkerState> _sent = {};
  final Map<String, double> _sentScale = {};

  /// HUNT: 지금 반짝이는(탭으로 주울 수 있는) 엽전 — 네이티브 전송 기록과 따로 든다.
  final Set<String> _shining = {};

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

  /// 네이티브가 마커를 막 놓았을 때 화면이 부른다. 그 전에 보낸 지시는 받을 마커가 없어
  /// 사라졌으니, 보낸 기록을 비워 다음 텔레메트리에 지금 상태를 다시 보내게 한다.
  void resync() {
    _sent.clear();
    _sentScale.clear();
  }

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

  /// 탭으로 줍는 미션(부재·엽전)에서 화면이 호출한다.
  void onTapped(String markerId) {
    if (_done.contains(markerId)) return;
    if (type == ArMissionType.restore) {
      _collect(markerId);
    } else if (type == ArMissionType.hunt) {
      // 반짝이는(가까운) 엽전만 줍는다 — 멀리서 흐릿한 걸 탭해 건너뛰지 못하게.
      if (_shining.contains(markerId)) {
        _pickCoin(markerId);
      } else {
        _status = '더 가까이 가야 주울 수 있느니라';
      }
      notifyListeners();
    }
  }

  // ── HUNT — 다가가면 엽전이 반짝이고, 탭하거나 바로 앞까지 가면 줍는다 ──
  void _tickHunt(Map<String, ArMarkerReading> r) {
    var shining = 0;
    for (final m in _markers) {
      if (_done.contains(m.id)) continue;
      final read = r[m.id];
      if (read == null) continue;
      final d = read.distance;
      if (d <= kCoinPickM) {
        _pickCoin(m.id);
        continue;
      }
      final state = d <= kTrailSolidM
          ? ArMarkerState.solid
          : (d <= kTrailWakeM ? ArMarkerState.ghost : ArMarkerState.hidden);
      // 멀수록 흐리고 작게, 가까울수록 크게 — 거리 자체가 원근 연출이 된다.
      _push(m.id, state, scale: coinScaleFor(d));
      if (state == ArMarkerState.solid) {
        _shining.add(m.id);
        shining++;
      } else {
        _shining.remove(m.id);
      }
    }
    if (_complete) return; // 방금 마지막 엽전을 주웠다 — _finish 문구를 덮지 않는다
    _ratio = _markers.isEmpty ? 0 : _done.length / _markers.length;
    final count = '${_done.length}/${_markers.length}';
    _status = shining > 0
        ? '엽전이 반짝이는구나 — 주워 보거라 ($count)'
        : (_done.isEmpty ? '엽전 기척이 희미하다 — 더 다가가 보거라' : '도깨비가 흘린 엽전이 이어지는구나 ($count)');
  }

  /// 엽전 하나를 줍는다 — 사라지게 하고 센다(다 주우면 _collect가 완료시킨다).
  void _pickCoin(String id) {
    _shining.remove(id);
    _push(id, ArMarkerState.hidden);
    _collect(id);
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
    _push(target.id, ArMarkerState.solid);

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

  /// 같은 상태를 10Hz로 반복 전송하면 채널만 먹는다 — 상태나 크기가 바뀔 때만 보낸다.
  /// (전엔 ghost일 때만 크기를 다시 보내, 반짝이는(solid) 엽전은 다가가도 커지지 않았다.)
  void _push(String id, ArMarkerState state, {double scale = 1.0}) {
    // 뷰가 아직 없으면 보내지도 기록하지도 않는다 — 기록만 남으면 뷰가 붙은 뒤 상태가 같아
    // 다시 안 보내, 마커가 끝까지 숨은 채로 남았다(admin 이동은 뷰보다 먼저 거리를 보낸다).
    if (_view == null) return;
    final prevScale = _sentScale[id];
    final changed = _sent[id] != state || prevScale == null || (prevScale - scale).abs() > _kScaleEpsilon;
    _sent[id] = state;
    _sentScale[id] = scale;
    if (changed) {
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
      // 정면으로 이어지는 엽전. 좌우로 조금씩 엇갈려야 도깨비가 흘리고 간 자취처럼 보인다.
      final n = (count ?? 5).clamp(2, 12);
      return [
        for (var i = 0; i < n; i++)
          ArMarkerDef(
            id: 'step$i',
            label: '엽전 ${i + 1}',
            color: primary,
            kind: ArMarkerKind.coin,
            image: kCoinImageAsset,
            // 첫 엽전이 폰을 들고만 있어도 화면에 들어오는 거리부터.
            forward: 2.4 + i * 1.3,
            right: (i.isEven ? -0.22 : 0.22),
            down: 0.9, // 눈높이에서 허리께 — 평면을 찾으면 네이티브가 바닥+띄움 높이로 옮긴다
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
          state: ArMarkerState.solid,
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
