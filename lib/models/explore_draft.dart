// ============================================================
// [v1] 나만의 코스 만들기 — 3단계 입력 draft
// pipeline: 모바일 클라이언트 / 모델 (탐험 마법사 화면 간 공유 상태)
// 구현(요약): 가고싶은장소 → 여행조건 → 입력확인 3화면이 같은 인스턴스를 들고 다니며 채운다.
//            duration·companion·difficulty·tags는 서버(dokkaebi-server/-ai) 미지원 필드라
//            로컬에만 보관하고 시나리오 생성 요청엔 포함하지 않는다.
// 구현일: 2026-08-05 | 작성: Claude
// ------------------------------------------------------------
// [v2] 로컬에만 머물던 입력을 전부 서버로 보낸다 — 계약이 생겼다(ai#preference·server DTO).
// 구현(요약): duration·companion·difficulty·tags가 UI에만 있고 생성에는 하나도 반영되지
//            않아, 무엇을 골라도 같은 코스가 나왔다. 한글 라벨을 서버 코드로 옮기는 매핑을
//            여기 둔다 — 화면은 라벨을, 계약은 코드를 쓴다(표시 문구가 바뀌어도 계약 불변).
//            headcount는 동행에서 파생(혼자1·친구/연인2·가족4) — 식음 예산이 1인 기준이라
//            인원수가 없으면 4인 총예산을 1인 예산으로 오인한다.
//            region은 월드맵에서 고른 지역. 'auto'면 AI가 좌표 근처 주소로 시군구를 정한다.
// 구현일: 2026-08-18 | 작성: kys (explore-input-wiring/kys/v1)
// ============================================================
import 'scenario.dart';

class ExploreDraft {
  final List<SearchCandidate> places = [];
  final Set<String> tags = {};
  String duration = '2시간';
  String transportLabel = '도보'; // '도보' | '대중교통'
  String companion = '혼자';
  String difficulty = '보통';
  // [v2] 식음 삽입이 꺼져 있는 동안(scenario_food_per_route=0) 입력을 받지 않는다 —
  //      어떤 값을 넣어도 식음 노드가 0개라 UI만 있고 효과가 없었다.
  //      기능을 켜는 날 이 두 줄을 되돌리고 explore_conditions_screen의 블록을 살린다.
  bool includeMeals = false;
  int? budget; // null = 무제한(예산 게이팅 미사용)

  /// 지역 라벨. 'auto' = AI가 출발 좌표 주변 주소에서 시군구를 정한다.
  /// 월드맵에서 지역을 골라 들어온 경우 그 이름이 들어온다.
  String region = 'auto';

  /// 서버로 보낼 transport 값 — 대중교통은 도보와 동일 처리되는 서버 특성상 car로 매핑.
  String get transport => transportLabel == '대중교통' ? 'car' : 'walk';

  /// 서버 코드: 탐험 시간 → 방문 장소 수·검색 반경(AI preference.py).
  String get durationCode => switch (duration) {
        '반나절' => 'half',
        '하루' => 'full',
        _ => '2h',
      };

  /// 서버 코드: 동행 → 인원수·대사 톤 근거.
  String get companionCode => switch (companion) {
        '친구' => 'friend',
        '가족' => 'family',
        '연인' => 'couple',
        _ => 'solo',
      };

  /// 서버 코드: 난이도 → GPS 트리거 반경·힌트 노출 수.
  String get difficultyCode => switch (difficulty) {
        '쉬움' => 'easy',
        '어려움' => 'hard',
        _ => 'normal',
      };

  /// 인원수 — 동행에서 파생. 식음 예산 게이팅의 1인 예산 = budget/headcount.
  int get headcount => switch (companion) {
        '친구' => 2,
        '연인' => 2,
        '가족' => 4,
        _ => 1,
      };

  /// 취향 태그 — 화면은 '#'을 붙여 보여주지만 계약엔 라벨만 보낸다.
  List<String> get tagList => tags.toList();
}
