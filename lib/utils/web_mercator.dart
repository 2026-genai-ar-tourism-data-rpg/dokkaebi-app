// ============================================================
// [v1] kakao_maps_flutter 0.2.2의 iOS 네이티브 구현을 직접 확인한 결과,
//      toScreenPoint는 무조건 {dx:null, dy:null}만 반환하는 스텁이고
//      CameraUpdate.fromBounds는 네이티브 디코더가 position/zoomLevel만
//      읽어서 항상 E004(Invalid cameraUpdate arguments)로 실패한다 —
//      둘 다 재시도·지연으로 고칠 수 없는 구조적 버그(패키지 미구현).
//      그래서 화면 좌표 변환·카메라 맞춤을 패키지에 맡기지 않고
//      표준 Web Mercator 타일 좌표계로 직접 계산한다. 카카오맵 SDK의
//      zoomLevel(관찰된 범위 1~21)은 이 타일 줌 규약과 같다고 보고 구현했다.
// 구현일: 2026-09-12 | 작성: ljs (explore-radius-first/ljs/v1)
// ------------------------------------------------------------
// [v2] fitBounds에 insets 추가 — 이동 화면은 위에 추적 칩, 아래에 거리 카드가 지도를 덮는다.
//      뷰 전체 기준으로 맞추면 내 위치 마커가 카드 뒤에 들어가 "GPS가 안 잡힌다"로 보였다.
//      가려지는 부분을 빼고 맞춘 뒤, 그 영역의 한가운데가 되도록 카메라 중심을 옮긴다.
// 구현일: 2026-09-16 | 작성: ljs (gps-map-gestures/ljs/v1)
// ============================================================
import 'dart:math' as math;
import 'dart:ui';

import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

const double _tileSize = 256.0;

/// 지구 둘레(m, WGS84 장반경 기준) — 위도별 미터/픽셀 환산에 쓴다.
const double _earthCircumferenceM = 2 * math.pi * 6378137.0;

double _lngToWorldX(double lng) => (lng + 180.0) / 360.0;

double _latToWorldY(double lat) {
  final sinLat = math.sin(lat * math.pi / 180.0);
  return 0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi);
}

double _worldXToLng(double x) => x * 360.0 - 180.0;

double _worldYToLat(double y) {
  final n = math.pi - 2 * math.pi * y;
  return 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
}

/// 줌 레벨 [zoom]에서 위도 [latitude]의 미터/픽셀. 인증 반경(m)을 화면
/// 반지름(px)으로 바꿀 때 쓴다 — toScreenPoint로 두 점을 찍어 차분하던
/// 이전 방식(패키지 미구현이라 항상 null) 대신 닫힌 형태로 바로 구한다.
double metersPerPixel({required double latitude, required int zoom}) =>
    _earthCircumferenceM *
    math.cos(latitude * math.pi / 180.0) /
    (_tileSize * math.pow(2, zoom).toDouble());

/// 지도 카메라가 [center]·[zoom]으로 잡혀 있을 때 [point]가 [viewportSize]
/// 안 어디에 찍히는지 계산한다. toScreenPoint(iOS 미구현, 항상 null) 대체.
Offset projectToScreen({
  required LatLng point,
  required LatLng center,
  required int zoom,
  required Size viewportSize,
}) {
  final scale = _tileSize * math.pow(2, zoom).toDouble();
  final px = _lngToWorldX(point.longitude) * scale;
  final py = _latToWorldY(point.latitude) * scale;
  final cx = _lngToWorldX(center.longitude) * scale;
  final cy = _latToWorldY(center.latitude) * scale;
  return Offset(
    viewportSize.width / 2 + (px - cx),
    viewportSize.height / 2 + (py - cy),
  );
}

/// 카메라에 명령할 중심·정수 줌. moveCamera에는 항상 이 조합으로만 넘긴다
/// (네이티브 디코더가 position+zoomLevel만 지원 — fromBounds는 무조건 실패).
typedef MapFit = ({LatLng center, int zoom});

/// [points]가 [paddingPx] 여백을 두고 [viewportSize] 안에 모두 들어오는
/// 중심·줌을 계산한다. CameraUpdate.fromBounds(iOS에서 항상 E004) 대체.
/// 정수로 내림해 실제 화면이 계산값보다 넓게(더 축소되게) 나오는 쪽으로만
/// 오차가 나게 한다 — 점이 잘려나가는 실패보다 안전하다.
/// [topInsetPx]·[bottomInsetPx]는 지도를 덮는 UI(위 추적 칩·아래 거리 카드) 두께다.
/// 그만큼을 뺀 영역에 점들을 넣고, 그 영역의 한가운데에 오도록 카메라 중심을 옮긴다 —
/// 안 그러면 점이 카드 뒤로 숨어 "지도에 안 보인다"가 된다.
MapFit fitBounds({
  required List<LatLng> points,
  required Size viewportSize,
  double paddingPx = 60,
  double topInsetPx = 0,
  double bottomInsetPx = 0,
  int minZoom = 3,
  int maxZoom = 20,
}) {
  final xs = points.map((p) => _lngToWorldX(p.longitude));
  final ys = points.map((p) => _latToWorldY(p.latitude));
  final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
  final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
  final safeH = math.max(viewportSize.height - topInsetPx - bottomInsetPx, 1.0);
  final safeW = viewportSize.width;
  final availW = math.max(safeW - paddingPx * 2, 1.0);
  final availH = math.max(safeH - paddingPx * 2, 1.0);
  final spanX = maxX - minX, spanY = maxY - minY;
  var zoom = maxZoom.toDouble();
  if (spanX > 0) {
    zoom = math.min(zoom, math.log(availW / (spanX * _tileSize)) / math.ln2);
  }
  if (spanY > 0) {
    zoom = math.min(zoom, math.log(availH / (spanY * _tileSize)) / math.ln2);
  }
  final z = zoom.floor().clamp(minZoom, maxZoom).toInt();
  // 화면 중심과 "안 가려지는 영역"의 중심 차이만큼 카메라를 밀어 준다(projectToScreen의 역산).
  final scale = _tileSize * math.pow(2, z).toDouble();
  final dy = viewportSize.height / 2 - (topInsetPx + safeH / 2);
  return (
    center: LatLng(
      latitude: _worldYToLat((minY + maxY) / 2 + dy / scale),
      longitude: _worldXToLng((minX + maxX) / 2),
    ),
    zoom: z,
  );
}
