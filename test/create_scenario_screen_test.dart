// ============================================================
// [v1] 위시 반경 사전 경고 — 순수 로직 테스트
// pipeline: 모바일 클라이언트 / 테스트 (create_scenario_screen 위시 입력 회귀 방지)
// 구현(요약): haversineMeters(서버 density.py _haversine_m과 동일 공식)·wishWarningLabel
//            문구 매핑을 검증. _wishWarning(사전 판정)은 State 내부 private라 위젯 단위
//            검증이 필요 — ApiClient가 주입 불가능해 네트워크 목킹 없이는 테스트 불가.
// 구현일: 2026-07-30 | 작성: 정찬희 (app-v3-front/jch/v1)
// ============================================================
import 'package:dokkaebi_app/screens/create_scenario_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('haversineMeters', () {
    test('같은 좌표면 거리 0에 가깝다', () {
      final double d = haversineMeters(37.5703, 126.9856, 37.5703, 126.9856);
      expect(d, closeTo(0, 0.001));
    });

    test('위도 1도 차이는 지구 반지름 기준 약 111.19km', () {
      // dLng=0이면 a=sin²(dLat/2), c=dLat(rad) — 순수 위도 이동 거리 공식과 동일해야 함.
      final double d = haversineMeters(0, 0, 1, 0);
      expect(d, closeTo(111194.93, 1));
    });
  });

  group('wishWarningLabel', () {
    test('outOfRadius는 반경 밖 문구를 반환한다', () {
      expect(wishWarningLabel(WishWarning.outOfRadius), '반경 밖 — 위치가 부정확할 수 있음');
    });

    test('missingCoords는 좌표 없음 문구, none은 빈 문자열을 반환한다', () {
      expect(wishWarningLabel(WishWarning.missingCoords), '좌표 없음 — 경로에 반영되지 않을 수 있음');
      expect(wishWarningLabel(WishWarning.none), '');
    });
  });
}
