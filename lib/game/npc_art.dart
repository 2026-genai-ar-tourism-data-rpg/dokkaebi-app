// ============================================================
// [v1] 도깨비 이름 → 캐릭터 그림 경로.
// pipeline: 모바일 클라이언트 / 게임
// 구현(요약): AI가 장소마다 붙이는 도깨비 이름('먹 도깨비')의 접두로 그림 폴더
//            (assets/game/characters/<폴더>/)를 고른다. 피날레는 수호 도깨비,
//            초롱 도깨비는 프롤로그와 같은 기존 그림, 표에 없는 이름은 기본 소년 도깨비.
// 구현일: 2026-09-18
// ============================================================

/// 도깨비 한 명의 그림 세 장 — 전신(등장·AR), 상반신 기본(지령), 상반신 말하기(대화).
class NpcArt {
  final String full;
  final String bust;
  final String bustTalk;

  const NpcArt._(this.full, this.bust, this.bustTalk);

  /// 이름 접두 → 그림 폴더. dokkaebi-ai node_schema.py의 _NPC_MOTIFS 접두와 1:1이다 —
  /// 그쪽에 모티프가 늘면 여기에도 폴더와 함께 늘린다(없으면 기본 도깨비로 보인다).
  static const Map<String, String> folderByPrefix = {
    '먹': 'heritage_meok',
    '기와': 'heritage_giwa',
    '현판': 'heritage_hyeonpan',
    '솔': 'nature_sol',
    '이끼': 'nature_ikki',
    '물안개': 'nature_mulangae',
    '엽전': 'market_yeopjeon',
    '됫박': 'market_doetbak',
    '보따리': 'market_bottari',
    '가마솥': 'food_gamasot',
    '찻잔': 'food_chatjan',
    '숯불': 'food_sutbul',
    '바람': 'leports_baram',
    '징검': 'leports_jinggeom',
    '탈': 'festival_tal',
    '등불': 'festival_deungbul',
    '수문': 'person_sumun',
    '서책': 'person_seochaek',
    '수호': guardianFolder,
  };

  static const String baseFolder = 'base_youth';
  static const String guardianFolder = 'guardian_suho';
  static const String _dir = 'assets/game/characters';

  /// 프롤로그의 초롱 도깨비 — 새 세트에 없어 기존 그림을 그대로 쓴다(말하기 표정 없음).
  static const NpcArt lantern = NpcArt._(
    'assets/images/dokkaebi_character.png',
    'assets/images/dokkaebi_character_bust.png',
    'assets/images/dokkaebi_character_bust.png',
  );

  /// [npcName] 도깨비의 그림. [isFinale]이면 이름과 무관하게 수호 도깨비다 —
  /// 종로 시연 코스처럼 피날레 이름이 표와 다를 때('글빛 수호 도깨비')도 같은 수호신이 나온다.
  factory NpcArt.of(String npcName, {bool isFinale = false}) {
    if (isFinale) return _inFolder(guardianFolder);
    final prefix = npcName.trim().replaceFirst(RegExp(r'\s*도깨비$'), '');
    if (prefix == '초롱') return lantern;
    return _inFolder(folderByPrefix[prefix] ?? baseFolder);
  }

  static NpcArt _inFolder(String folder) => NpcArt._(
        '$_dir/$folder/full_idle.webp',
        '$_dir/$folder/bust_idle.webp',
        '$_dir/$folder/bust_talk.webp',
      );
}
