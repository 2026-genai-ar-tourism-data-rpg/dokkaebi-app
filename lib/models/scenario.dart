// ============================================================
// [v6] 단서 = 퀴즈의 귀띔 — 퀴즈 바로 앞 장소가 주는 단서를 가진 채 퀴즈에 오면 오답 하나를 지운다.
// 구현(요약): QuestNode.quizClue(퀴즈 화면 노드가 요구하는 단서) · Scenario.quizClues(보여 줄 단서 —
//            예전 코스의 쓰임 없는 단서는 숨긴다) · Quiz.eliminatedFor(장소마다 고정된 지울 오답).
// 구현일: 2026-09-19 | 작성: ljs (quiz-clue/ljs/v1)
// ------------------------------------------------------------
// [v5] 기억석 조각 표시 이름 — '관악구_stone_1of5'(AI 식별자) 대신 '첫째 조각 · 자매공원'.
//      식별자는 서버 조각 기록 키라 그대로 두고, 화면에만 코스 데이터(순서·장소)로 이름을 짓는다.
// 구현일: 2026-09-19 | 작성: ljs (reward-ui-polish/ljs/v1)
// ------------------------------------------------------------
// [v4] 위시리스트 — SearchCandidate.toJson(저장), NearbyPlace.contentId/toWish(주변 장소 → 위시 항목).
// 구현일: 2026-09-19 | 작성: ljs (wishlist-course/ljs/v1)
// ------------------------------------------------------------
// [v3] 생성 코스 엔딩(ai #64) — 피날레 노드의 final_restore_dialogue · endings(A/B) ·
//      final_rewards_common.region_stone을 읽는다. 엔딩 화면이 종로 고정값(訓民正音·집현전 붓)
//      대신 이 값을 쓴다(계획 A1·B3·B4). 저장된 코스에서도 남도록 toJson에 함께 넣는다.
// 구현일: 2026-09-16 | 작성: ljs (finale-ending/ljs/v1)
// ------------------------------------------------------------
// [v2] 시나리오 모델 — 서버 응답(ScenarioGenResponse)과 1:1 + 노드 스키마 v1.1
// pipeline: 모바일 클라이언트 / 모델 (서버 contract)
// 구현(요약): QuestNode에 3층 문법(motivation/strategy/actions) + 상태 그래프
//            (grants/requires/requires_mode) + hint_ladder + clue 필드 추가.
//            전부 옵셔널 — AI 미대응 구간은 기존 mission/quiz/objective로 폴백(하위호환).
// 구현일: 2026-07-30 | 작성: kys (app-v3-back/kys/v1) · 명세: 시나리오구조화.md 2·3·5절
// ------------------------------------------------------------
// [v1] Scenario · QuestNode + fromJson — 2026-06-18 kys (app-scaffold/kys/v1)
// ============================================================
import 'node_schema.dart';
import 'route_tree.dart';

export 'node_schema.dart';
export 'route_tree.dart';

/// 퀴즈 (생성 시 고정 콘텐츠)
class Quiz {
  final String q;
  final List<String> options;
  final int answer;
  final String wrongHint;
  Quiz({required this.q, required this.options, required this.answer, required this.wrongHint});
  factory Quiz.fromJson(Map<String, dynamic> j) => Quiz(
        q: j['q'] ?? '',
        options: ((j['options'] ?? []) as List).map((e) => e.toString()).toList(),
        answer: j['answer'] ?? 0,
        wrongHint: j['wrong_hint'] ?? '다시 살펴보거라.',
      );
  Map<String, dynamic> toJson() => {'q': q, 'options': options, 'answer': answer, 'wrong_hint': wrongHint};

  /// 귀띔 단서로 지울 오답 번호 — 장소([seed])마다 고정이라 다시 들어와도 같은 보기가 지워진다.
  /// 보기가 [kQuizClueMinOptions]개보다 적으면 하나를 지웠을 때 정답이 드러나므로 null.
  int? eliminatedFor(String seed) {
    if (options.length < kQuizClueMinOptions) return null;
    final wrong = [for (var i = 0; i < options.length; i++) if (i != answer) i];
    final hash = seed.codeUnits.fold<int>(0, (sum, c) => sum + c);
    return wrong[hash % wrong.length];
  }
}

/// 귀띔 단서가 쓰이는 퀴즈의 최소 보기 수 — AI node_schema.QUIZ_CLUE_MIN_OPTIONS와 같게 둔다.
const kQuizClueMinOptions = 3;

/// 피날레에서 고를 수 있는 엔딩 한 갈래 (AI `endings.A`/`endings.B`).
///
/// 굿·노멀은 AI가 붙여 주는 이름(`ending`)이고, 어느 쪽을 고를지는 플레이어가 정한다.
/// 굿 엔딩은 친밀도가 기준(goodEndingAffinityFor)에 모자라면 잠긴다 — 코스 진행 화면에서 판정.
class CourseEnding {
  final String id; // "A" | "B"
  final String choiceText; // 피날레에서 보여줄 선택지 문구
  final String label; // "굿 엔딩" | "노멀 엔딩"
  final List<String> npcDialogue; // 엔딩 화면 대사(여러 줄)
  final String? title; // 칭호 — 서버가 준 칭호가 없을 때만 쓴다
  final String? relic; // rewards.garden_item_final (지역 기억석)
  final String? unlock; // rewards.unlock — "{지역}의 기억이 복원되었습니다."

  const CourseEnding({
    required this.id,
    required this.choiceText,
    required this.label,
    this.npcDialogue = const [],
    this.title,
    this.relic,
    this.unlock,
  });

  factory CourseEnding.fromJson(Map<String, dynamic> j) {
    final rewards = (j['rewards'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CourseEnding(
      id: (j['id'] ?? '').toString(),
      choiceText: (j['choice_text'] ?? '').toString(),
      label: (j['ending'] ?? '').toString(),
      npcDialogue: ((j['npc_dialogue'] ?? []) as List).map((e) => e.toString()).toList(),
      title: rewards['title']?.toString(),
      relic: rewards['garden_item_final']?.toString(),
      unlock: rewards['unlock']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'choice_text': choiceText,
        'ending': label,
        if (npcDialogue.isNotEmpty) 'npc_dialogue': npcDialogue,
        'rewards': {
          if (title != null) 'title': title,
          if (relic != null) 'garden_item_final': relic,
          if (unlock != null) 'unlock': unlock,
        },
      };

  /// 굿 엔딩 갈래인가 — 화면 강조(금색)와 저장값('good'/'normal')을 이걸로 정한다.
  bool get isGood => label.contains('굿');
}

/// 노드 미션 (타입별 다양화: PHOTO_FIND·COLLECT·DIALOGUE_FIND·FIND·QUIZ_FIND·DIALOGUE_COLLECT)
/// 공통: type·order·hints. 타입별 필드는 옵셔널(없으면 null/빈값).
/// 촬영 타깃의 참조 정보 — AI가 TourAPI에서 꺼내 준다(photo_refs.py).
/// refImage는 비전 검증의 비교 대상, credit은 화면 출처 표기(공공누리).
class PhotoRef {
  final String name;
  final String? why;
  final String? refImage;
  final String? credit;
  const PhotoRef({required this.name, this.why, this.refImage, this.credit});

  factory PhotoRef.fromJson(Map<String, dynamic> j) => PhotoRef(
        name: (j['name'] ?? '').toString(),
        why: j['why']?.toString(),
        refImage: j['ref_image']?.toString(),
        credit: j['credit']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (why != null) 'why': why,
        if (refImage != null) 'ref_image': refImage,
        if (credit != null) 'credit': credit,
      };
}

class Mission {
  final String type;
  final String order;
  final List<String> hints;
  // PHOTO_FIND
  final List<String> photoTargets;
  /// 타깃별 참조 사진·이유·출처 (photo_targets와 같은 순서, 없을 수 있음).
  final List<PhotoRef> photoRefs;
  /// ARKit Augmented Images 후보 — 노드 진입 시 내려받아 참조 이미지로 등록한다.
  final List<String> arReferenceImages;
  // COLLECT
  final List<String> items;
  final List<String> reactions;
  // FIND
  final String? object;
  final int count;
  final String? special;
  // DIALOGUE_FIND / *_FIND / PATH_TRACE 공통
  final String? find;
  // HUNT
  final String? monster;
  final String? boss;
  final String? weakness;
  // RESTORE_AR
  final String? structure;
  final List<String> parts;
  final String? era;
  // PATH_TRACE
  final String? trailClue;
  final List<String> steps;
  // DIALOGUE_COLLECT (피날레)
  final String? villainLine;
  final String? guardianLine;

  Mission({
    required this.type,
    required this.order,
    required this.hints,
    this.photoTargets = const [],
    this.photoRefs = const [],
    this.arReferenceImages = const [],
    this.items = const [],
    this.reactions = const [],
    this.object,
    this.count = 0,
    this.special,
    this.find,
    this.monster,
    this.boss,
    this.weakness,
    this.structure,
    this.parts = const [],
    this.era,
    this.trailClue,
    this.steps = const [],
    this.villainLine,
    this.guardianLine,
  });

  static List<String> _strs(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : const [];

  factory Mission.fromJson(Map<String, dynamic> j) => Mission(
        type: (j['type'] ?? 'FIND').toString(),
        order: (j['order'] ?? '').toString(),
        hints: _strs(j['hints']),
        photoTargets: _strs(j['photo_targets']),
        photoRefs: j['photo_refs'] is List
            ? (j['photo_refs'] as List)
                .whereType<Map>()
                .map((e) => PhotoRef.fromJson(e.cast<String, dynamic>()))
                .toList()
            : const [],
        arReferenceImages: _strs(j['ar_reference_images']),
        items: _strs(j['items']),
        reactions: _strs(j['reactions']),
        object: j['object']?.toString(),
        count: (j['count'] as num?)?.toInt() ?? 0,
        special: j['special']?.toString(),
        find: j['find']?.toString(),
        monster: j['monster']?.toString(),
        boss: j['boss']?.toString(),
        weakness: j['weakness']?.toString(),
        structure: j['structure']?.toString(),
        parts: _strs(j['parts']),
        era: j['era']?.toString(),
        trailClue: j['trail_clue']?.toString(),
        steps: _strs(j['steps']),
        villainLine: j['villain_line']?.toString(),
        guardianLine: j['guardian_line']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'order': order,
        'hints': hints,
        if (photoTargets.isNotEmpty) 'photo_targets': photoTargets,
        if (photoRefs.isNotEmpty) 'photo_refs': photoRefs.map((e) => e.toJson()).toList(),
        if (arReferenceImages.isNotEmpty) 'ar_reference_images': arReferenceImages,
        if (items.isNotEmpty) 'items': items,
        if (reactions.isNotEmpty) 'reactions': reactions,
        if (object != null) 'object': object,
        if (count > 0) 'count': count,
        if (special != null) 'special': special,
        if (find != null) 'find': find,
        if (monster != null) 'monster': monster,
        if (boss != null) 'boss': boss,
        if (weakness != null) 'weakness': weakness,
        if (structure != null) 'structure': structure,
        if (parts.isNotEmpty) 'parts': parts,
        if (era != null) 'era': era,
        if (trailClue != null) 'trail_clue': trailClue,
        if (steps.isNotEmpty) 'steps': steps,
        if (villainLine != null) 'villain_line': villainLine,
        if (guardianLine != null) 'guardian_line': guardianLine,
      };

  /// 수집/사냥/복원/추적형 목표 개수(없으면 1). AR 카운터 표시에 사용.
  int get targetCount {
    if (count > 0) return count; // FIND·HUNT
    if (items.isNotEmpty) return items.length; // COLLECT
    if (parts.isNotEmpty) return parts.length; // RESTORE_AR
    if (steps.isNotEmpty) return steps.length; // PATH_TRACE
    return 1;
  }
}

/// AR 지령 + 단계 힌트 (생성 시 고정 콘텐츠)
class Objective {
  final String order;
  final List<String> hints;
  Objective({required this.order, required this.hints});
  factory Objective.fromJson(Map<String, dynamic> j) => Objective(
        order: j['order'] ?? '',
        hints: ((j['hints'] ?? []) as List).map((e) => e.toString()).toList(),
      );
  Map<String, dynamic> toJson() => {'order': order, 'hints': hints};
}

/// 퀘스트 노드 한 개 (= 방문 장소 1곳).
/// kind="spot"이면 기억석 조각 노드, kind="food"/"cafe"면 경유 식음 노드(조각 아님).
class QuestNode {
  final int order;
  final String nodeId;
  final String? name;
  final String kind; // "spot"(기억석) | "food" | "cafe"
  final double? mapX; // 경도
  final double? mapY; // 위도
  final double? distM;
  final int triggerRadiusM;
  final String fragmentId; // 기억석 조각 id. 식음 노드는 빈 문자열(조각 아님)
  final int? stoneNo; // 기억석 조각 번호(1-base). 식음 노드는 null
  final String npcDialogue;

  /// 이 장소를 지키는 도깨비 이름(AI가 노드마다 합성). 서버 도감(DexEntry)도 이 값을 쓴다.
  /// 없으면 빈 문자열 — 화면이 기본 이름으로 폴백한다.
  final String npcName;
  final bool isFinale;
  final int? priceBand; // 식음: 가격대 밴드 1~4(미상 null)
  final String? priceBandLabel; // 식음: ₩~₩₩₩₩ 표시용
  final Map<String, dynamic>? coupon; // 식음: 상권 쿠폰
  final Mission? mission; // 타입별 미션(핵심: 노드마다 다른 종류)
  final Quiz? quiz; // 앱 호환: 질문형 미션이면 채워짐
  final Objective? objective; // AR 지령+힌트

  // ── 노드 스키마 v1.1 (시나리오구조화 2·3·5절) — AI 생성층 대응 전엔 빈 값 ──
  final List<String> motivation; // 동기 M1~M9 ("M1+M7" → ['M1','M7'])
  final List<String> strategy; // 전략 S1~S7 ("S4_PHOTO_TRAIL")
  final List<ActionAtom> actions; // 액션 원자 시퀀스
  final List<StateRef> grants; // 이 노드가 주는 상태
  final List<StateRef> requires; // 이 노드가 요구하는 상태
  final RequiresMode requiresMode; // none | soft | hard(피날레)
  final HintLadder? hintLadder; // H1~H3 문구 슬롯 + 공개 규칙
  final String? clue; // 단서 이름(단서설계규칙) — grants의 clue 편의 접근
  final List<String> success; // 성공 판정식(코드 고정)

  // ── 경로 분기 (dokkaebi-ai#24) ──
  final String pathId; // "main"(본선) | "b1"(샛길)
  final NodeBranch? branch; // 분기 노드면 갈림길 프롬프트+갈래

  // ── 위시 앵커 (wishlist.py) ──
  final bool outOfRadius; // true면 검색 반경 밖 좌표로 합성된 앵커(위치 부정확 가능)
  final String? source; // 앵커 출처("wishlist" 등)

  // ── 생성 코스 엔딩 (ai #64, 피날레 노드에만 붙는다) ──
  final String? finalRestoreDialogue; // 조각을 모두 이었을 때의 복원 대사
  final Map<String, CourseEnding> endings; // "A"/"B" → 갈래
  final String? regionStoneName; // final_rewards_common.region_stone.name
  final String? regionStoneDesc; // 〃 .desc

  QuestNode({
    required this.order,
    required this.nodeId,
    required this.name,
    this.kind = 'spot',
    required this.mapX,
    required this.mapY,
    required this.distM,
    required this.triggerRadiusM,
    required this.fragmentId,
    this.stoneNo,
    required this.npcDialogue,
    this.npcName = '',
    required this.isFinale,
    this.priceBand,
    this.priceBandLabel,
    this.coupon,
    this.mission,
    this.quiz,
    this.objective,
    this.motivation = const [],
    this.strategy = const [],
    this.actions = const [],
    this.grants = const [],
    this.requires = const [],
    this.requiresMode = RequiresMode.none,
    this.hintLadder,
    this.clue,
    this.success = const [],
    this.pathId = 'main',
    this.branch,
    this.outOfRadius = false,
    this.source,
    this.finalRestoreDialogue,
    this.endings = const {},
    this.regionStoneName,
    this.regionStoneDesc,
  });

  /// 식음(카페·식당) 경유 노드인가 — 기억석 조각 아님.
  bool get isFood => kind == 'food' || kind == 'cafe';

  /// 기억석 조각 노드인가.
  bool get isStone => !isFood;

  /// 전략 코드만 (`S4_PHOTO_TRAIL` → `S4`).
  List<String> get strategyCodes => strategy.map(strategyCode).toList();

  /// 이 노드가 주는 상태 — grants 미제공 시 조각/단서 필드로 합성(하위호환).
  ///
  /// 구 플로우(fragment_id만 있는 노드)도 상태 그래프에 동일하게 태울 수 있게 한다.
  List<StateRef> get effectiveGrants {
    if (grants.isNotEmpty) return grants;
    return [
      if (isStone && fragmentId.isNotEmpty) StateRef(kind: StateKind.fragment, value: fragmentId),
      if (clue != null && clue!.isNotEmpty) StateRef(kind: StateKind.clue, value: clue!),
    ];
  }

  /// 이 노드가 주는 단서 이름 — clue 필드 우선, 없으면 grants에서 찾음.
  String? get clueName {
    if (clue != null && clue!.isNotEmpty) return clue;
    for (final g in grants) {
      if (g.kind == StateKind.clue) return g.value;
    }
    return null;
  }

  /// 이 퀴즈에서 오답 하나를 지워 주는 귀띔 단서 — 퀴즈 화면으로 가는 노드(S3)가 요구하는 단서.
  /// 퀴즈가 아니거나 보기가 적거나 요구하는 단서가 없으면 null.
  String? get quizClue {
    final codes = strategyCodes;
    if (codes.isEmpty || codes.first != 'S3') return null;
    if ((quiz?.options.length ?? 0) < kQuizClueMinOptions) return null;
    for (final r in requires) {
      if (r.kind == StateKind.clue) return r.value;
    }
    return null;
  }

  /// 힌트 사다리 — hint_ladder 우선, 없으면 구 mission.hints/objective.hints로 폴백.
  HintLadder get hints {
    if (hintLadder != null && !hintLadder!.isEmpty) return hintLadder!;
    final legacy = mission?.hints ?? objective?.hints ?? const <String>[];
    return HintLadder.fromLegacyHints(legacy);
  }

  /// 피날레 하드 게이팅 대상인가 (규칙 4조 — 강제 게이트는 피날레 하나뿐).
  bool get isHardGated => requiresMode == RequiresMode.hard && requires.isNotEmpty;

  factory QuestNode.fromJson(Map<String, dynamic> j) => QuestNode(
        order: j['order'] ?? 0,
        nodeId: j['node_id'] ?? '',
        name: j['name'],
        kind: (j['kind'] ?? 'spot').toString(),
        mapX: (j['map_x'] as num?)?.toDouble(),
        mapY: (j['map_y'] as num?)?.toDouble(),
        distM: (j['dist_m'] as num?)?.toDouble(),
        triggerRadiusM: j['trigger_radius_m'] ?? 100,
        fragmentId: j['fragment_id'] ?? '', // 식음 노드는 null → ''
        stoneNo: (j['stone_no'] as num?)?.toInt(),
        npcDialogue: j['npc_dialogue'] ?? '',
        npcName: ((j['npc'] as Map?)?['name'] ?? '').toString(),
        isFinale: j['is_finale'] ?? false,
        priceBand: (j['price_band'] as num?)?.toInt(),
        priceBandLabel: j['price_band_label'],
        coupon: j['coupon'] as Map<String, dynamic>?,
        mission: j['mission'] != null ? Mission.fromJson(j['mission'] as Map<String, dynamic>) : null,
        quiz: j['quiz'] != null ? Quiz.fromJson(j['quiz'] as Map<String, dynamic>) : null,
        objective: j['objective'] != null ? Objective.fromJson(j['objective'] as Map<String, dynamic>) : null,
        // ── 스키마 v1.1 — motivation은 npc.motivation에 들어올 수도 있음 ──
        motivation: parseCodes(j['motivation'] ?? (j['npc'] as Map?)?['motivation']),
        strategy: parseCodes(j['strategy']),
        actions: ActionAtom.listFrom(j['actions']),
        grants: StateRef.listFrom(j['grants']),
        requires: StateRef.listFrom(j['requires']),
        requiresMode: requiresModeOf(j['requires_mode']?.toString()),
        hintLadder: j['hint_ladder'] != null
            ? HintLadder.fromJson((j['hint_ladder'] as Map).cast<String, dynamic>())
            : null,
        clue: j['clue']?.toString(),
        pathId: (j['path_id'] ?? 'main').toString(),
        branch: j['branch'] != null
            ? NodeBranch.fromJson((j['branch'] as Map).cast<String, dynamic>())
            : null,
        outOfRadius: j['out_of_radius'] ?? false,
        source: j['source']?.toString(),
        finalRestoreDialogue: j['final_restore_dialogue']?.toString(),
        endings: _endingsFrom(j['endings']),
        regionStoneName: _regionStone(j)?['name']?.toString(),
        regionStoneDesc: _regionStone(j)?['desc']?.toString(),
        // success는 판정식 문자열("tap:글씨파편>=1") — 분해하지 않고 그대로 보관
        success: (j['success'] is List)
            ? (j['success'] as List).map((e) => e.toString()).toList()
            : const [],
      );

  Map<String, dynamic> toJson() => {
        'order': order,
        'node_id': nodeId,
        'name': name,
        'kind': kind,
        'map_x': mapX,
        'map_y': mapY,
        'dist_m': distM,
        'trigger_radius_m': triggerRadiusM,
        'fragment_id': fragmentId,
        if (stoneNo != null) 'stone_no': stoneNo,
        'npc_dialogue': npcDialogue,
        if (npcName.isNotEmpty) 'npc': {'name': npcName},
        'is_finale': isFinale,
        if (priceBand != null) 'price_band': priceBand,
        if (priceBandLabel != null) 'price_band_label': priceBandLabel,
        if (coupon != null) 'coupon': coupon,
        if (mission != null) 'mission': mission!.toJson(),
        if (quiz != null) 'quiz': quiz!.toJson(),
        if (objective != null) 'objective': objective!.toJson(),
        if (motivation.isNotEmpty) 'motivation': motivation,
        if (strategy.isNotEmpty) 'strategy': strategy,
        if (actions.isNotEmpty) 'actions': actions.map((a) => a.toJson()).toList(),
        if (grants.isNotEmpty) 'grants': grants.map((g) => g.toStorageString()).toList(),
        if (requires.isNotEmpty) 'requires': requires.map((r) => r.toStorageString()).toList(),
        if (requiresMode != RequiresMode.none) 'requires_mode': requiresModeName(requiresMode),
        if (hintLadder != null) 'hint_ladder': hintLadder!.toJson(),
        if (clue != null) 'clue': clue,
        if (success.isNotEmpty) 'success': success,
        if (pathId != 'main') 'path_id': pathId,
        if (branch != null) 'branch': branch!.toJson(),
        if (outOfRadius) 'out_of_radius': outOfRadius,
        if (source != null) 'source': source,
        if (finalRestoreDialogue != null) 'final_restore_dialogue': finalRestoreDialogue,
        if (endings.isNotEmpty)
          'endings': endings.map((id, e) => MapEntry(id, e.toJson())),
        if (regionStoneName != null || regionStoneDesc != null)
          'final_rewards_common': {
            'region_stone': {
              if (regionStoneName != null) 'name': regionStoneName,
              if (regionStoneDesc != null) 'desc': regionStoneDesc,
            }
          },
      };

  /// 고른 갈래 — 없으면 null(데이터 없는 코스·데모).
  CourseEnding? endingOf(String? id) => id == null ? null : endings[id];

  static Map<String, CourseEnding> _endingsFrom(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, CourseEnding>{};
    raw.forEach((k, v) {
      if (v is Map) out[k.toString()] = CourseEnding.fromJson(v.cast<String, dynamic>());
    });
    return out;
  }

  static Map<String, dynamic>? _regionStone(Map<String, dynamic> j) {
    final common = j['final_rewards_common'];
    if (common is! Map) return null;
    final stone = common['region_stone'];
    return stone is Map ? stone.cast<String, dynamic>() : null;
  }
}

/// 분기 대화 선택지
class DialogueChoice {
  final String id;
  final String text;
  DialogueChoice(this.id, this.text);
  factory DialogueChoice.fromJson(Map<String, dynamic> j) =>
      DialogueChoice((j['id'] ?? '').toString(), (j['text'] ?? '').toString());
}

/// 분기 대화 한 턴 결과
class DialogueTurn {
  final String response;
  final List<DialogueChoice> choices;
  final List<String> grants; // 획득 조각/단서
  final bool done;
  DialogueTurn({required this.response, required this.choices, required this.grants, required this.done});
  factory DialogueTurn.fromJson(Map<String, dynamic> j) => DialogueTurn(
        response: j['response'] ?? '',
        choices: ((j['choices'] ?? []) as List)
            .map((e) => DialogueChoice.fromJson(e as Map<String, dynamic>))
            .toList(),
        grants: ((j['grants'] ?? []) as List).map((e) => e.toString()).toList(),
        done: j['done'] ?? false,
      );
}

/// 관광지 검색 후보 (앵커 자동완성 항목)
class SearchCandidate {
  final String contentId;
  final String? name;
  final String? addr;
  final double? lat;
  final double? lng;

  SearchCandidate({
    required this.contentId,
    this.name,
    this.addr,
    this.lat,
    this.lng,
  });

  factory SearchCandidate.fromJson(Map<String, dynamic> j) => SearchCandidate(
        contentId: (j['content_id'] ?? '').toString(),
        name: j['name'],
        addr: j['addr'],
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
      );

  /// 위시리스트 저장용(fromJson과 같은 키).
  Map<String, dynamic> toJson() => {
        'content_id': contentId,
        if (name != null) 'name': name,
        if (addr != null) 'addr': addr,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };
}

/// 주변 장소 갈래 — 목록 아이콘·필터칩의 기준.
/// 문자열 값은 서버 category(dokkaebi-ai osm._category_of)와 일치해야 한다.
enum NearbyCategory {
  historic('historic', '유적'),
  museum('museum', '박물관'),
  artwork('artwork', '예술품'),
  viewpoint('viewpoint', '전망'),
  park('park', '공원'),
  attraction('attraction', '명소'),
  other('other', '기타');

  final String wire;
  final String label;
  const NearbyCategory(this.wire, this.label);

  /// 모르는 값은 조용히 버리지 않고 '기타'로 모은다 — 서버가 갈래를 늘려도 목록이 비지 않게.
  static NearbyCategory parse(String? raw) => NearbyCategory.values
      .firstWhere((c) => c.wire == raw, orElse: () => NearbyCategory.other);
}

/// 내 주변 POI 1개 — 코스 생성 없이 그 자리에서 바로 탐색하는 지점.
/// 서버 NearbyPlace(dokkaebi-ai schemas.py)와 1:1.
class NearbyPlace {
  final String nodeId;
  final String? name;
  final String? addr;
  final double? lat;
  final double? lng;
  final double? distM;
  final NearbyCategory category;
  final String? summary;

  const NearbyPlace({
    required this.nodeId,
    this.name,
    this.addr,
    this.lat,
    this.lng,
    this.distM,
    this.category = NearbyCategory.other,
    this.summary,
  });

  /// TourAPI 콘텐츠 ID — 위시리스트(코스 생성 앵커)에 필요하다. AI가 node_id를
  /// 'tour_<contentid>'로 만든다(dokkaebi-ai tourapi/client.py). 그 밖(OSM 등)은 null.
  String? get contentId {
    const prefix = 'tour_';
    if (!nodeId.startsWith(prefix) || nodeId.length == prefix.length) return null;
    return nodeId.substring(prefix.length);
  }

  /// 위시리스트 항목으로 — content_id가 없으면 null(담을 수 없다).
  SearchCandidate? toWish() {
    final id = contentId;
    if (id == null) return null;
    return SearchCandidate(contentId: id, name: name, addr: addr, lat: lat, lng: lng);
  }

  /// 목록에 보여줄 거리 표기(1km 이상은 km).
  String get distLabel {
    final d = distM;
    if (d == null) return '';
    return d >= 1000 ? '${(d / 1000).toStringAsFixed(1)}km' : '${d.round()}m';
  }

  factory NearbyPlace.fromJson(Map<String, dynamic> j) => NearbyPlace(
        nodeId: (j['node_id'] ?? '').toString(),
        name: j['name'],
        addr: j['addr'],
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        distM: (j['dist_m'] as num?)?.toDouble(),
        category: NearbyCategory.parse(j['category'] as String?),
        summary: j['summary'] as String?,
      );
}

const _koreanOrdinals = ['첫째', '둘째', '셋째', '넷째', '다섯째', '여섯째', '일곱째', '여덟째', '아홉째', '열째', '열한째', '열두째'];

/// 기억석 조각의 화면 이름 — '첫째 조각 · 자매공원'. 순서를 모르면 '기억석 조각 · 장소',
/// 장소도 모르면 [fallback](보통 fragment_id).
String fragmentDisplayName(int? stoneNo, String? place, {required String fallback}) {
  final hasPlace = place != null && place.isNotEmpty;
  if (stoneNo == null || stoneNo < 1) return hasPlace ? '기억석 조각 · $place' : fallback;
  final ordinal = stoneNo <= _koreanOrdinals.length ? '${_koreanOrdinals[stoneNo - 1]} 조각' : '$stoneNo번째 조각';
  return hasPlace ? '$ordinal · $place' : ordinal;
}

/// 코스 오프닝 프롤로그 대본 한 줄. speaker="beat"면 text 없이 연출 트리거(beat)만 있다.
/// 서버(dokkaebi-ai PrologueLineSchema)와 1:1 — speaker: narration|npc|player|beat.
class PrologueLine {
  final String speaker;
  final String text;
  final String? beat;

  const PrologueLine({required this.speaker, required this.text, this.beat});

  factory PrologueLine.fromJson(Map<String, dynamic> j) => PrologueLine(
        speaker: (j['speaker'] ?? 'narration').toString(),
        text: (j['text'] ?? '').toString(),
        beat: j['beat']?.toString(),
      );
}

/// 시나리오(루트) — 노드 시퀀스 + 메타
class Scenario {
  final String scenarioId;
  final String title;
  final String region;
  final List<QuestNode> nodeSequence;
  final String? anchorNodeId;
  final int? _stoneTotal; // 서버 제공 조각 총수(식음 제외). null이면 노드에서 계산

  // ── 경로 분기 (dokkaebi-ai#24) — 선형이면 isBranching=false, routeTree=null ──
  final bool isBranching;
  final RouteTree? routeTree;

  /// 코스 생성 시 지정한 1인 예산(원). 앱이 보내는 값인데 응답에서 안 읽어
  /// 저장된 코스의 예산을 표시할 수 없었다 → 파싱·왕복 대상에 포함.
  final int? budget;

  /// 코스 오프닝 프롤로그 대본(화자 순서·연출 비트 고정, 대사만 region·첫 장소로 생성).
  /// 비어있으면(구버전 캐시·생성 실패) 프롤로그 화면이 자체 정적 텍스트로 폴백한다.
  final List<PrologueLine> prologue;

  Scenario({
    required this.scenarioId,
    required this.title,
    required this.region,
    required this.nodeSequence,
    required this.anchorNodeId,
    int? stoneTotal,
    this.isBranching = false,
    this.routeTree,
    this.budget,
    this.prologue = const [],
  }) : _stoneTotal = stoneTotal;

  /// 기억석 조각 노드만(식음 제외). 진행률·조각수 표시는 전부 이걸 기준으로.
  List<QuestNode> get stoneNodes => nodeSequence.where((n) => n.isStone).toList();

  /// 조각 식별자(fragment_id) → 화면 이름('첫째 조각 · 자매공원'). 코스에 없는 조각이면 식별자 그대로.
  /// 갈림길 대체 장소는 본선과 같은 조각을 주므로, [played](끝낸 노드 id) 중 그 조각을 준 곳을 먼저 쓴다.
  String fragmentLabel(String fragmentId, {Set<String> played = const {}}) {
    final givers = nodeSequence.where((n) => n.fragmentId == fragmentId).toList();
    if (givers.isEmpty) return fragmentId;
    final n = givers.firstWhere((g) => played.contains(g.nodeId), orElse: () => givers.first);
    return fragmentDisplayName(n.stoneNo, n.name, fallback: fragmentId);
  }

  /// 퀴즈가 쓰는 귀띔 단서들 — 보상·단서함엔 이것만 보여 준다(예전 코스의 쓰임 없는 단서는 숨김).
  Set<String> get quizClues => {
        for (final n in nodeSequence)
          if (n.quizClue != null) n.quizClue!,
      };

  /// 조각 총수 — 서버값 우선, 없으면 관광 노드 수로 폴백.
  int get stoneTotal => _stoneTotal ?? stoneNodes.length;

  QuestNode? nodeById(String nodeId) =>
      nodeSequence.where((n) => n.nodeId == nodeId).firstOrNull;

  /// **실제 밟는 노드 순서.** 분기 시나리오는 route_tree를 선택대로 순회하고,
  /// 선형이면 node_sequence 그대로. 화면·진행률은 전부 이걸 기준으로 삼는다.
  List<QuestNode> playedPath([Map<String, String> choices = const {}]) {
    final tree = routeTree;
    if (tree == null || tree.isEmpty) return nodeSequence;
    return tree.traverse(choices).map(nodeById).whereType<QuestNode>().toList();
  }

  /// 아직 안 고른 갈림길의 노드들 — "선택 대기" 렌더용.
  List<QuestNode> pendingBranchNodes(Map<String, String> choices) =>
      (routeTree?.pendingBranchPoints(choices) ?? const [])
          .map(nodeById)
          .whereType<QuestNode>()
          .toList();

  /// 코스 이름을 사용자가 직접 지었을 때(입력 확인 화면) 덮어쓰기용.
  Scenario copyWith({String? title}) => Scenario(
        scenarioId: scenarioId,
        title: title ?? this.title,
        region: region,
        nodeSequence: nodeSequence,
        anchorNodeId: anchorNodeId,
        stoneTotal: _stoneTotal,
        isBranching: isBranching,
        routeTree: routeTree,
        budget: budget,
        prologue: prologue,
      );

  factory Scenario.fromJson(Map<String, dynamic> j) => Scenario(
        scenarioId: j['scenario_id'] ?? '',
        title: j['title'] ?? '',
        region: j['region'] ?? '',
        anchorNodeId: j['anchor_node_id'],
        stoneTotal: (j['stone_total'] as num?)?.toInt(),
        budget: (j['budget'] as num?)?.toInt(),
        isBranching: j['is_branching'] ?? false,
        routeTree: j['route_tree'] != null
            ? RouteTree.fromJson((j['route_tree'] as Map).cast<String, dynamic>())
            : null,
        nodeSequence: ((j['node_sequence'] ?? []) as List)
            .map((e) => QuestNode.fromJson(e as Map<String, dynamic>))
            .toList(),
        prologue: ((j['prologue'] ?? []) as List)
            .map((e) => PrologueLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'scenario_id': scenarioId,
        'title': title,
        'region': region,
        'anchor_node_id': anchorNodeId,
        'stone_total': stoneTotal,
        if (budget != null) 'budget': budget,
        if (isBranching) 'is_branching': isBranching,
        if (routeTree != null) 'route_tree': routeTree!.toJson(),
        'node_sequence': nodeSequence.map((n) => n.toJson()).toList(),
      };
}

/// dart:core에는 없는 편의 접근자 (collection 패키지 의존 없이).
extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
