// ============================================================
// [v1] Web Mercator 계산 — 카카오맵 패키지의 toScreenPoint(iOS 미구현)·fromBounds(항상 E004)
//      대체 구현. 이동 화면 오버레이가 이 계산 위에 그려지므로 어긋나면 바로 눈에 보인다.
// pipeline: 모바일 클라이언트 / 테스트
// 구현(요약): fitBounds의 insets(위 칩·아래 카드에 가려지는 두께)를 검증한다 —
//            가려지는 영역을 빼고 맞춰야 내 위치 마커가 카드 뒤로 숨지 않는다.
// 구현일: 2026-09-16 | 작성: ljs (gps-map-gestures/ljs/v1)
// ============================================================
import 'dart:ui';

import 'package:dokkaebi_app/utils/web_mercator.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewport = Size(400, 800);
  final me = LatLng(latitude: 37.5270, longitude: 126.9240);
  final target = LatLng(latitude: 37.5300, longitude: 126.9280);

  group('fitBounds — 가려지는 영역(insets)', () {
    test('아래가 가려지면 두 점이 그 위쪽 영역 한가운데에 들어온다', () {
      final fit = fitBounds(
        points: [me, target],
        viewportSize: viewport,
        paddingPx: 40,
        topInsetPx: 96,
        bottomInsetPx: 210,
      );

      for (final p in [me, target]) {
        final at = projectToScreen(
            point: p, center: fit.center, zoom: fit.zoom, viewportSize: viewport);
        expect(at.dy, greaterThan(96), reason: '위 칩에 가리면 안 된다');
        expect(at.dy, lessThan(viewport.height - 210), reason: '아래 카드에 가리면 안 된다');
        expect(at.dx, inInclusiveRange(0, viewport.width));
      }
    });

    test('insets가 없으면 화면 한가운데에 맞춘다 — 기존 동작 그대로', () {
      final fit = fitBounds(points: [me, target], viewportSize: viewport, paddingPx: 40);

      final a = projectToScreen(
          point: me, center: fit.center, zoom: fit.zoom, viewportSize: viewport);
      final b = projectToScreen(
          point: target, center: fit.center, zoom: fit.zoom, viewportSize: viewport);
      // 두 점의 한가운데가 화면 중앙(±1px)
      expect((a.dy + b.dy) / 2, closeTo(viewport.height / 2, 1));
      expect((a.dx + b.dx) / 2, closeTo(viewport.width / 2, 1));
    });
  });
}
