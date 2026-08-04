// ============================================================
// [v1] 나만의 코스 만들기 — 3단계 입력 draft
// pipeline: 모바일 클라이언트 / 모델 (탐험 마법사 화면 간 공유 상태)
// 구현(요약): 가고싶은장소 → 여행조건 → 입력확인 3화면이 같은 인스턴스를 들고 다니며 채운다.
//            duration·companion·difficulty·tags는 서버(dokkaebi-server/-ai) 미지원 필드라
//            로컬에만 보관하고 시나리오 생성 요청엔 포함하지 않는다.
// 구현일: 2026-08-05 | 작성: Claude
// ============================================================
import 'scenario.dart';

class ExploreDraft {
  final List<SearchCandidate> places = [];
  final Set<String> tags = {};
  String duration = '2시간';
  String transportLabel = '도보'; // '도보' | '대중교통'
  String companion = '혼자';
  String difficulty = '보통';
  bool includeMeals = true;
  int? budget = 30000; // null = 무제한

  /// 서버로 보낼 transport 값 — 대중교통은 도보와 동일 처리되는 서버 특성상 car로 매핑.
  String get transport => transportLabel == '대중교통' ? 'car' : 'walk';
}
