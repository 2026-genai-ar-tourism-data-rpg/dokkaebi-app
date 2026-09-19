// ============================================================
// [v1] 네이티브 AR 뷰 Dart 래퍼 — ios/Runner/DokkaebiArView.swift와 짝.
// pipeline: 모바일 클라이언트 / 위젯 (PlatformView 브리지)
// 구현(요약): UiKitView로 ARSCNView를 얹고, 마커 정의를 creationParams로 넘긴 뒤
//            per-view MethodChannel(dokkaebi/ar_view_<id>)로 탭 이벤트를 받는다.
//            dokkaebi/ar_support 채널로 ARKit 지원 여부(시뮬레이터=false)를 먼저 확인.
// 구현일: 2026-08-31 | 작성: 정찬희
// ------------------------------------------------------------
// [v2] 실시간 텔레메트리 + 마커 종류·표시상태 (AR 타당성 검토 2026-08-19의 "A층").
// 구현(요약): 네이티브가 10Hz로 보내는 마커별 거리·조준각을 onTelemetry로 흘린다.
//            미션 상태기계는 ar_mission_controller.dart가 이 스트림을 먹고 돌고,
//            결과를 setMarkerState로 되돌려준다 — 네이티브는 그리기만 한다.
//            그래서 "몇 미터부터 켤지, 몇 초 겨눠야 드러날지" 같은 실기기 튜닝이
//            Dart 핫리로드로 끝난다(Xcode 재빌드 불필요).
// 구현일: 2026-09-16 | 작성: kys (ar-realtime/kys/v1)
// ------------------------------------------------------------
// [v3] 도깨비불 길들이기 지원 — fire 마커, 부호 있는 yaw(좌우 힌트), tracking 상태, 흡수 연출.
// 구현일: 2026-09-19 | 작성: kys (fire-capture/kys/v1)
// ============================================================
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show Factory, kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 마커가 무엇으로 그려지는지. Swift의 ArMarkerKind와 **문자열이 같아야 한다**.
enum ArMarkerKind {
  coin, // HUNT       — 도깨비가 흘리고 간 엽전
  part, // RESTORE_AR — 흩어진 부재
  pattern, // PHOTO_FIND — 벽면 문양
  hidden, // FIND       — 숨은 자리의 풀숲
  beacon, // 범용(구 동작)
  fire, // 도깨비불 길들이기 — 눈높이 불꽃(바닥 스냅 제외)
}

/// 마커 표시 상태. Swift의 ArMarkerState와 **문자열이 같아야 한다**.
enum ArMarkerState { hidden, ghost, solid }

/// AR 세션 시작 시점 카메라 기준 상대 배치(미터). forward=정면, right=오른쪽, down=아래.
class ArMarkerDef {
  final String id;
  final String label;
  final Color color;
  final double forward;
  final double right;
  final double down;
  final ArMarkerKind kind;

  /// 처음 보일지. 숨은 것(FIND)·아직 안 켜진 발자국은 hidden으로 시작한다.
  final ArMarkerState state;

  /// beacon(캐릭터)·coin(엽전)에 붙일 그림(Flutter 에셋 경로). null이면 네이티브 기본 모양.
  final String? image;

  const ArMarkerDef({
    required this.id,
    required this.label,
    required this.color,
    this.forward = 1.6,
    this.right = 0,
    this.down = 0.2,
    this.kind = ArMarkerKind.beacon,
    this.state = ArMarkerState.solid,
    this.image,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'color': color.toARGB32() & 0xFFFFFF,
        'forward': forward,
        'right': right,
        'down': down,
        'kind': kind.name,
        'state': state.name,
        if (image != null) 'image': image,
      };
}

/// 마커 1개의 실시간 관측값 — 네이티브가 10Hz로 보낸다.
class ArMarkerReading {
  /// 카메라에서 마커까지 직선거리(m).
  final double distance;

  /// 화면 정중앙에서 벗어난 각(라디안). 0이면 정확히 겨눈 상태.
  final double aimError;

  /// 부호 있는 수평 각(라디안). +면 목표가 오른쪽 → "오른쪽으로 돌려라". 구 네이티브면 0.
  final double yawDelta;

  const ArMarkerReading({required this.distance, required this.aimError, this.yawDelta = 0});

  /// 조준으로 인정할지 — 시야 중앙 약 17°(0.3rad) 안.
  bool get isAimed => aimError <= 0.30;
}

const _kArSupportChannel = MethodChannel('dokkaebi/ar_support');

/// 이 기기가 실제 ARKit 월드 트래킹을 지원하는지. 시뮬레이터·구형 기기·Android는 false
/// (Android는 아직 네이티브 구현이 없어 항상 false — 폴백 경로로 빠진다).
Future<bool> isArSupported() async {
  // 웹을 먼저 거른다 — dart:io의 Platform은 웹에서 값을 읽는 순간 터진다.
  // (웹 빌드는 컴파일까지는 통과하므로 이 가드가 없으면 런타임에야 드러난다.)
  if (kIsWeb) return false;
  if (!Platform.isIOS) return false;
  try {
    return (await _kArSupportChannel.invokeMethod<bool>('isSupported')) ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}

/// 네이티브 뷰를 Dart에서 조종하는 손잡이. onReady로 받아 미션 상태기계가 들고 쓴다.
class ArViewController {
  MethodChannel? _channel;

  bool get isReady => _channel != null;

  /// 마커의 표시 상태·크기를 바꾼다. scale은 배율(풀숲 흔들림 강도 등).
  Future<void> setMarkerState(String id, ArMarkerState state, {double scale = 1.0}) async {
    final ch = _channel;
    if (ch == null) return;
    try {
      await ch.invokeMethod('setMarkerState', {'id': id, 'state': state.name, 'scale': scale});
    } on MissingPluginException {
      // 네이티브가 없는 환경(테스트·폴백) — 무시한다.
    } on PlatformException {
      // 뷰가 이미 내려갔을 수 있다. 연출 실패가 플레이를 막아선 안 된다.
    }
  }

  /// 흡수 연출 후 마커 제거 — 도깨비불 수집 순간. 이후 텔레메트리에서도 빠진다.
  /// 흡수 연출 — [image]를 주면 그 자리에 소용돌이 그림(회전·축소·페이드)이 뜬다.
  Future<void> absorbMarker(String id, {String? image}) async {
    final ch = _channel;
    if (ch == null) return;
    try {
      await ch.invokeMethod('absorbMarker', image == null ? id : {'id': id, 'image': image});
    } on MissingPluginException {
      // 네이티브가 없는 환경 — 무시.
    } on PlatformException {
      // 뷰가 이미 내려갔을 수 있다.
    }
  }

  /// 지금 카메라 화면(AR 오버레이 포함)을 JPEG base64로 찍는다. 촬영 미션의 '셔터'.
  /// 갤러리 사진을 쓸 수 없게 하는 장치이기도 하다 — 검증에 보내는 건 항상 이 스냅샷이다.
  Future<String?> snapshot() async {
    final ch = _channel;
    if (ch == null) return null;
    try {
      return await ch.invokeMethod<String>('snapshot');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> removeMarker(String id) async {
    final ch = _channel;
    if (ch == null) return;
    try {
      await ch.invokeMethod('removeMarker', id);
    } on MissingPluginException {
      // 위와 같음.
    } on PlatformException {
      // 위와 같음.
    }
  }
}

/// 실제 ARKit 뷰. isArSupported()가 true일 때만 사용할 것 — 아니면 UiKitView 생성이
/// 실패하거나 빈 화면만 나온다(iOS 네이티브 팩토리가 그 기기에서 등록될 이유가 없으므로).
class NativeArView extends StatefulWidget {
  final List<ArMarkerDef> markers;
  final ValueChanged<String> onMarkerTapped;
  final VoidCallback? onError;

  /// 마커별 실시간 거리·조준각(10Hz). 미션 연출의 입력.
  final ValueChanged<Map<String, ArMarkerReading>>? onTelemetry;

  /// 바닥 평면을 찾은 순간(월드 Y). 실외에선 안 올 수도 있다 — 없어도 진행된다.
  final ValueChanged<double>? onPlaneFound;

  /// 네이티브 채널이 열린 직후 — 이 컨트롤러로 마커 상태를 지시한다.
  final ValueChanged<ArViewController>? onReady;

  /// ARKit Augmented Images 참조 사진 URL(TourAPI). 네이티브가 내려받아 등록하고,
  /// 카메라에 그 사진과 같은 면이 잡히면 onImageDetected가 온다. 비평면 사진은 그냥 안 잡힌다.
  final List<String> referenceImages;

  /// 참조 이미지 인식(인자=참조 이름/URL). PHOTO_FIND의 "AR이 타깃을 봤다" 신호.
  final ValueChanged<String>? onImageDetected;

  /// 네이티브가 마커를 놓은 직후. 그 전에 보낸 상태 지시는 받을 마커가 없어 사라졌다.
  final VoidCallback? onMarkersPlaced;

  /// ARKit tracking 품질(true=normal). 불안정하면 도깨비불 게이지를 버린다.
  final ValueChanged<bool>? onTrackingChanged;

  /// 세로 화면 가로 시야각(°) — 세션 시작 후 1회. HUD가 조준 원을 실제 각도 크기로 그릴 때 쓴다.
  final ValueChanged<double>? onCameraFov;

  /// 두 손가락 확대·축소를 감싼 Flutter 위젯(ar_search_screen._zoomable)까지
  /// 올려 보낼지. 기본은 false — UiKitView는 기본적으로 자기 영역의 제스처를
  /// 네이티브가 먼저 가져가므로, 이걸 켜야 ScaleGestureRecognizer가 경쟁에 끼어
  /// 밖의 GestureDetector.onScaleUpdate가 실제로 불린다. 마커 탭(onMarkerTapped)은
  /// 그대로 네이티브가 받는다 — 켜져도 한 손가락 탭 인식은 바뀌지 않는다.
  final bool enablePinchZoom;

  const NativeArView({
    super.key,
    required this.markers,
    required this.onMarkerTapped,
    this.onError,
    this.onTelemetry,
    this.onPlaneFound,
    this.onReady,
    this.referenceImages = const [],
    this.onImageDetected,
    this.enablePinchZoom = false,
    this.onMarkersPlaced,
    this.onTrackingChanged,
    this.onCameraFov,
  });

  @override
  State<NativeArView> createState() => _NativeArViewState();
}

class _NativeArViewState extends State<NativeArView> {
  final ArViewController _controller = ArViewController();

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('dokkaebi/ar_view_$id');
    channel.setMethodCallHandler(_handleNativeCall);
    _controller._channel = channel;
    widget.onReady?.call(_controller);
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'markerTapped':
        widget.onMarkerTapped(call.arguments as String);
        return;
      case 'sessionError':
        widget.onError?.call();
        return;
      case 'telemetry':
        final cb = widget.onTelemetry;
        if (cb == null) return;
        final raw = (call.arguments as List?) ?? const [];
        final out = <String, ArMarkerReading>{};
        for (final e in raw) {
          final m = (e as Map).cast<Object?, Object?>();
          final id = m['id'] as String?;
          if (id == null) continue;
          out[id] = ArMarkerReading(
            distance: (m['dist'] as num?)?.toDouble() ?? 0,
            aimError: (m['aim'] as num?)?.toDouble() ?? 0,
            yawDelta: (m['dyaw'] as num?)?.toDouble() ?? 0,
          );
        }
        cb(out);
        return;
      case 'planeFound':
        widget.onPlaneFound?.call((call.arguments as num?)?.toDouble() ?? 0);
        return;
      case 'imageDetected':
        widget.onImageDetected?.call((call.arguments ?? '').toString());
        return;
      case 'markerAnchored':
        return; // 마커가 인식된 이미지 위치로 옮겨졌다 — 텔레메트리에 자연히 반영된다
      case 'markersPlaced':
        widget.onMarkersPlaced?.call();
        return;
      case 'trackingState':
        // 회전만 하는 불꽃 게임엔 limited(특징점 부족·빠른 움직임)도 방향은 믿을 만하다 —
        // 초기화·재위치·notAvailable만 "불안정".
        final a = call.arguments;
        String state, reason = '';
        if (a is Map) {
          state = (a['state'] ?? 'normal').toString();
          reason = (a['reason'] ?? '').toString();
        } else {
          state = (a ?? 'normal').toString();
        }
        final ok = state == 'normal' ||
            (state == 'limited' && (reason == 'excessiveMotion' || reason == 'insufficientFeatures'));
        widget.onTrackingChanged?.call(ok);
        return;
      case 'cameraFov':
        final a = call.arguments;
        final fovx = a is Map ? (a['fovx'] as num?)?.toDouble() : null;
        if (fovx != null) widget.onCameraFov?.call(fovx);
        return;
    }
  }

  @override
  void dispose() {
    _controller._channel?.invokeMethod('dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UiKitView(
      viewType: 'dokkaebi/ar_view',
      creationParams: {
        'markers': widget.markers.map((m) => m.toMap()).toList(),
        'referenceImages': widget.referenceImages,
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
      gestureRecognizers: widget.enablePinchZoom
          ? {Factory<OneSequenceGestureRecognizer>(() => ScaleGestureRecognizer())}
          : const <Factory<OneSequenceGestureRecognizer>>{},
    );
  }
}
