// ============================================================
// [v1] 소환 도깨비 발견 판정 — AR로 비춰 잡아야 말을 걸 수 있다.
// pipeline: 모바일 클라이언트 / 게임
// 구현(요약): 네이티브 텔레메트리(10Hz)의 조준 오차가 kSummonFoundAimRad 이내로
//            kSummonFoundReadings번 이어지면 발견. 전엔 소환 화면이 1.5초 뒤 무조건
//            '말 걸기'를 띄워 도깨비를 안 비춰도 대화가 됐다.
// 구현일: 2026-09-18
// ============================================================
import '../widgets/native_ar_view.dart' show ArMarkerReading;

/// 이 각도(라디안, 약 20°) 안이면 도깨비가 화면 가운데 근처에 있다. 마커 위치는 도깨비
/// 발끝이라 몸통을 가운데 두면 발끝까지 10°쯤 벌어진다 — 그만큼 넉넉히 잡는다.
const double kSummonFoundAimRad = 0.35;

/// 이어서 잡혀야 하는 텔레메트리 수(10Hz → 약 0.5초). 스치듯 지나가면 발견이 아니다.
const int kSummonFoundReadings = 5;

class SummonSighting {
  int _streak = 0;
  bool _found = false;

  bool get found => _found;

  /// 텔레메트리 한 번을 넣는다(도깨비 마커 값, 없으면 null). 발견한 순간에만 true.
  bool onReading(ArMarkerReading? reading) {
    if (_found) return false;
    if (reading == null || reading.aimError > kSummonFoundAimRad) {
      _streak = 0;
      return false;
    }
    _streak++;
    if (_streak < kSummonFoundReadings) return false;
    _found = true;
    return true;
  }
}
