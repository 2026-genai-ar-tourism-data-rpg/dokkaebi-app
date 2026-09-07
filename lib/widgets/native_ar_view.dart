// ============================================================
// [v1] 네이티브 AR 뷰 Dart 래퍼 — ios/Runner/DokkaebiArView.swift와 짝.
// pipeline: 모바일 클라이언트 / 위젯 (PlatformView 브리지)
// 구현(요약): UiKitView로 ARSCNView를 얹고, 마커 정의를 creationParams로 넘긴 뒤
//            per-view MethodChannel(dokkaebi/ar_view_<id>)로 탭 이벤트를 받는다.
//            dokkaebi/ar_support 채널로 ARKit 지원 여부(시뮬레이터=false)를 먼저 확인.
// 구현일: 2026-08-31 | 작성: 정찬희
// ============================================================
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// AR 세션 시작 시점 카메라 기준 상대 배치(미터). forward=정면, right=오른쪽, down=아래.
class ArMarkerDef {
  final String id;
  final String label;
  final Color color;
  final double forward;
  final double right;
  final double down;
  const ArMarkerDef({
    required this.id,
    required this.label,
    required this.color,
    this.forward = 1.6,
    this.right = 0,
    this.down = 0.2,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'color': color.toARGB32() & 0xFFFFFF,
        'forward': forward,
        'right': right,
        'down': down,
      };
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

/// 실제 ARKit 뷰. isArSupported()가 true일 때만 사용할 것 — 아니면 UiKitView 생성이
/// 실패하거나 빈 화면만 나온다(iOS 네이티브 팩토리가 그 기기에서 등록될 이유가 없으므로).
class NativeArView extends StatefulWidget {
  final List<ArMarkerDef> markers;
  final ValueChanged<String> onMarkerTapped;
  final VoidCallback? onError;
  const NativeArView({
    super.key,
    required this.markers,
    required this.onMarkerTapped,
    this.onError,
  });

  @override
  State<NativeArView> createState() => _NativeArViewState();
}

class _NativeArViewState extends State<NativeArView> {
  MethodChannel? _viewChannel;

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('dokkaebi/ar_view_$id');
    channel.setMethodCallHandler(_handleNativeCall);
    _viewChannel = channel;
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'markerTapped':
        widget.onMarkerTapped(call.arguments as String);
        return;
      case 'sessionError':
        widget.onError?.call();
        return;
      case 'markersPlaced':
        return; // 진행 로그용 — 현재 UI는 별도 반응 없음
    }
  }

  @override
  void dispose() {
    _viewChannel?.invokeMethod('dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UiKitView(
      viewType: 'dokkaebi/ar_view',
      creationParams: {'markers': widget.markers.map((m) => m.toMap()).toList()},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }
}
