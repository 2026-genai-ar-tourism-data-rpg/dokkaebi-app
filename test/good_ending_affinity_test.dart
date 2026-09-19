// ============================================================
// [v1] 굿 엔딩 친밀도 기준(goodEndingAffinityFor) 테스트.
// pipeline: 모바일 클라이언트 / 테스트
// 구현(요약): 사연을 물을 수 있는 장소(피날레 제외) 수의 절반(올림), 장소가 없으면 0.
// 구현일: 2026-09-19
// ============================================================
import 'package:dokkaebi_app/game/player_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('장소 수의 절반을 올림한 친밀도가 필요하다', () {
    expect(goodEndingAffinityFor(1), 1);
    expect(goodEndingAffinityFor(2), 1);
    expect(goodEndingAffinityFor(3), 2);
    expect(goodEndingAffinityFor(4), 2);
    expect(goodEndingAffinityFor(5), 3);
  });

  test('피날레뿐인 코스(장소 0곳)나 잘못된 값이면 기준이 없다 — 굿 엔딩이 늘 열린다', () {
    expect(goodEndingAffinityFor(0), 0);
    expect(goodEndingAffinityFor(-1), 0);
  });
}
