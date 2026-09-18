// ============================================================
// [v1] 소환 도깨비 발견 판정(SummonSighting) 테스트.
// pipeline: 모바일 클라이언트 / 테스트
// 구현(요약): 가운데 근처에 잠시 잡아야 발견, 스치거나 놓치면 처음부터, 발견은 한 번만.
// 구현일: 2026-09-18
// ============================================================
import 'package:dokkaebi_app/game/summon_sighting.dart';
import 'package:dokkaebi_app/widgets/native_ar_view.dart';
import 'package:flutter_test/flutter_test.dart';

ArMarkerReading _aim(double rad) => ArMarkerReading(distance: 2.3, aimError: rad);

void main() {
  test('가운데 근처에 kSummonFoundReadings번 이어서 잡으면 발견한다', () {
    final s = SummonSighting();
    for (var i = 0; i < kSummonFoundReadings - 1; i++) {
      expect(s.onReading(_aim(0.1)), isFalse);
    }
    expect(s.onReading(_aim(0.1)), isTrue);
    expect(s.found, isTrue);
    expect(s.onReading(_aim(0.1)), isFalse, reason: '발견은 한 번만 알린다');
  });

  test('화면 밖으로 벗어나거나 값이 없으면 처음부터 다시 센다', () {
    final s = SummonSighting();
    for (var i = 0; i < kSummonFoundReadings - 1; i++) {
      s.onReading(_aim(0.1));
    }
    s.onReading(_aim(kSummonFoundAimRad + 0.2)); // 스치듯 지나감
    for (var i = 0; i < kSummonFoundReadings - 1; i++) {
      expect(s.onReading(_aim(0.1)), isFalse);
    }
    s.onReading(null); // 이번 틱엔 도깨비 값이 없다
    expect(s.found, isFalse);
  });

  test('계속 딴 곳을 비추면 발견하지 않는다', () {
    final s = SummonSighting();
    for (var i = 0; i < 30; i++) {
      s.onReading(_aim(1.2));
    }
    expect(s.found, isFalse);
  });
}
