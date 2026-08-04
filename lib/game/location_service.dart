// ============================================================
// [v1] 위치 서비스 — 권한 요청 + 현재 좌표 획득
// pipeline: 모바일 클라이언트 / 게임 (GPS 인증의 단말 측)
// 구현(요약): 권한 상태를 분기 가능한 결과로 돌려주고, 허용된 경우에만 좌표를 읽는다.
//            거부/영구거부/서비스 꺼짐을 구분한다 — 사용자가 취할 행동이 각각 다르다
//            (다시 요청 / 설정 열기 / 위치 서비스 켜기).
//            정확도(accuracy)를 함께 반환한다 — 서버가 이 값으로 반경을 보정한다.
// 구현일: 2026-08-04 | 작성: kys (game-loop-ui/kys/v1)
// ============================================================
import 'package:geolocator/geolocator.dart';

/// 위치 획득 실패 사유 — 화면이 안내와 다음 행동을 고르는 기준.
enum LocationFailure {
  serviceDisabled,  // 기기 위치 서비스 자체가 꺼짐 → 설정에서 켜야 함
  denied,           // 이번에 거부 → 다시 요청 가능
  deniedForever,    // 영구 거부 → 앱 설정 화면으로 보내야 함
  timeout,          // 신호를 못 잡음(실내·지하)
  unknown,
}

/// 위치 획득 결과 — 성공이면 좌표, 실패면 사유.
class LocationResult {
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final LocationFailure? failure;

  const LocationResult.ok(this.lat, this.lng, this.accuracyM) : failure = null;
  const LocationResult.fail(this.failure)
      : lat = null,
        lng = null,
        accuracyM = null;

  bool get isOk => failure == null;

  /// 사용자에게 보여줄 안내 — 사유별로 다음 행동이 다르다.
  String get message => switch (failure) {
        LocationFailure.serviceDisabled =>
          '기기의 위치 서비스가 꺼져 있느니라. 설정에서 켜다오.',
        LocationFailure.denied =>
          '위치 권한이 있어야 도착을 확인할 수 있느니라.',
        LocationFailure.deniedForever =>
          '위치 권한이 막혀 있느니라. 앱 설정에서 허용해다오.',
        LocationFailure.timeout =>
          'GPS 신호를 잡지 못했느니라. 하늘이 트인 곳으로 나가 보거라.',
        LocationFailure.unknown => '위치를 확인하지 못했느니라.',
        null => '',
      };

  /// 앱 설정 화면으로 보내야 하는 상황인지(영구 거부·서비스 꺼짐).
  bool get needsSettings =>
      failure == LocationFailure.deniedForever ||
      failure == LocationFailure.serviceDisabled;
}

class LocationService {
  /// 테스트에서 갈아끼울 수 있게 주입 지점을 남긴다(실기기 없이 화면 검증).
  final Future<Position> Function()? _positionOverride;
  final Future<bool> Function()? _serviceEnabledOverride;
  final Future<LocationPermission> Function()? _permissionOverride;

  const LocationService({
    Future<Position> Function()? position,
    Future<bool> Function()? serviceEnabled,
    Future<LocationPermission> Function()? permission,
  })  : _positionOverride = position,
        _serviceEnabledOverride = serviceEnabled,
        _permissionOverride = permission;

  /// 현재 위치. 권한이 없으면 요청하고, 그래도 안 되면 사유를 담아 반환한다.
  ///
  /// 예외를 던지지 않는다 — 위치 거부는 '오류'가 아니라 사용자의 선택이고,
  /// 화면은 그에 맞는 안내를 띄워야 하기 때문이다.
  Future<LocationResult> current({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final enabled = await (_serviceEnabledOverride?.call() ??
          Geolocator.isLocationServiceEnabled());
      if (!enabled) return const LocationResult.fail(LocationFailure.serviceDisabled);

      var permission = await (_permissionOverride?.call() ?? Geolocator.checkPermission());
      if (permission == LocationPermission.denied) {
        permission = await (_permissionOverride?.call() ?? Geolocator.requestPermission());
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.fail(LocationFailure.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.fail(LocationFailure.denied);
      }

      // ⚠️ geolocator 12 API — desiredAccuracy/timeLimit.
      //    13+는 locationSettings로 바뀌었지만, 13은 Flutter 3.27+를 요구해서
      //    팀 SDK(3.24.3)에서 빌드가 깨진다(Color.toARGB32 없음).
      //    C7 원칙대로 SDK 업그레이드를 강요하지 않고 패키지를 12에 고정했다.
      final pos = await (_positionOverride?.call() ??
          Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best, // 반경 판정이라 정확도가 곧 통과율
            timeLimit: timeout,
          ));
      return LocationResult.ok(pos.latitude, pos.longitude, pos.accuracy);
    } on Exception {
      // timeLimit 초과·플랫폼 예외 — 신호를 못 잡은 것으로 본다.
      return const LocationResult.fail(LocationFailure.timeout);
    }
  }

  /// 앱 설정 화면 열기(영구 거부 복구용).
  Future<void> openSettings() => Geolocator.openAppSettings();
}
