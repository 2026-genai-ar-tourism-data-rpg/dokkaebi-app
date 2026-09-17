// ============================================================
// [v1] GPS 이동 시뮬레이터 — admin 전용, 방향키로 위치를 옮긴다.
// pipeline: 모바일 클라이언트 / 게임 (테스트 전용 위치 주입)
// 구현(요약): 실외로 나가지 않고도 "이동 시작 — GPS 추적" 화면·도착 인증을 테스트하기
//            위한 것. Session.isAdmin일 때만 화면에서 D패드로 조작한다(session.dart 참고).
//            LocationService.current()가 이 값이 있으면 실제 GPS보다 우선한다.
// 구현일: 2026-09-18 | 작성: Claude
// ============================================================
import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart' show Position;
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart' show LatLng;

class GpsSimulator {
  static LatLng? _pos;
  static final _controller = StreamController<LatLng>.broadcast();

  static LatLng? get position => _pos;
  static Stream<LatLng> get stream => _controller.stream;
  static bool get isActive => _pos != null;

  /// 실 GPS 스트림(Geolocator.getPositionStream)과 같은 Position 타입으로 감싼다 —
  /// 지도 화면들이 시뮬레이터든 실 GPS든 같은 구독 코드로 받게 하기 위함.
  static Position toPosition(LatLng p) => Position(
        latitude: p.latitude,
        longitude: p.longitude,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

  /// 시뮬레이션 시작 — 실제 마지막 위치(또는 목표 좌표)에서 이어간다.
  static void start(LatLng at) {
    _pos = at;
    _controller.add(at);
  }

  /// 목표에서 [meters] 떨어진 곳에서 시작 — 도착 인증까지 방향키로 "걸어서" 테스트하기 위함
  /// (목표 좌표 그대로 시작하면 바로 도착 판정이라 이동 테스트가 안 된다).
  static void startNear(LatLng target, {double meters = 80, double bearingDeg = 200}) {
    start(_offset(target, bearingDeg, meters));
  }

  /// 방향키 한 번 = [meters]만큼 그 방위로 전진(0°=북, 90°=동, 180°=남, 270°=서).
  static void move(double bearingDeg, {double meters = 15}) {
    final p = _pos;
    if (p == null) return;
    _pos = _offset(p, bearingDeg, meters);
    _controller.add(_pos!);
  }

  static void stop() {
    _pos = null;
  }

  /// 구면 좌표 오프셋(단거리 근사) — 지구 반지름 기준 방위각·거리로 새 위·경도를 구한다.
  static LatLng _offset(LatLng from, double bearingDeg, double meters) {
    const earthR = 6371000.0;
    final brng = bearingDeg * math.pi / 180;
    final lat1 = from.latitude * math.pi / 180;
    final lng1 = from.longitude * math.pi / 180;
    final angDist = meters / earthR;
    final lat2 = math.asin(math.sin(lat1) * math.cos(angDist) +
        math.cos(lat1) * math.sin(angDist) * math.cos(brng));
    final lng2 = lng1 +
        math.atan2(math.sin(brng) * math.sin(angDist) * math.cos(lat1),
            math.cos(angDist) - math.sin(lat1) * math.sin(lat2));
    return LatLng(latitude: lat2 * 180 / math.pi, longitude: lng2 * 180 / math.pi);
  }
}
