// ============================================================
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
}

/// 노드 미션 (타입별 다양화: PHOTO_FIND·COLLECT·DIALOGUE_FIND·FIND·QUIZ_FIND·DIALOGUE_COLLECT)
/// 공통: type·order·hints. 타입별 필드는 옵셔널(없으면 null/빈값).
class Mission {
  final String type;
  final String order;
  final List<String> hints;
  // PHOTO_FIND
  final List<String> photoTargets;
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
      };
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

  Scenario({
    required this.scenarioId,
    required this.title,
    required this.region,
    required this.nodeSequence,
    required this.anchorNodeId,
    int? stoneTotal,
    this.isBranching = false,
    this.routeTree,
  }) : _stoneTotal = stoneTotal;

  /// 기억석 조각 노드만(식음 제외). 진행률·조각수 표시는 전부 이걸 기준으로.
  List<QuestNode> get stoneNodes => nodeSequence.where((n) => n.isStone).toList();

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

  factory Scenario.fromJson(Map<String, dynamic> j) => Scenario(
        scenarioId: j['scenario_id'] ?? '',
        title: j['title'] ?? '',
        region: j['region'] ?? '',
        anchorNodeId: j['anchor_node_id'],
        stoneTotal: (j['stone_total'] as num?)?.toInt(),
        isBranching: j['is_branching'] ?? false,
        routeTree: j['route_tree'] != null
            ? RouteTree.fromJson((j['route_tree'] as Map).cast<String, dynamic>())
            : null,
        nodeSequence: ((j['node_sequence'] ?? []) as List)
            .map((e) => QuestNode.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'scenario_id': scenarioId,
        'title': title,
        'region': region,
        'anchor_node_id': anchorNodeId,
        'stone_total': stoneTotal,
        if (isBranching) 'is_branching': isBranching,
        if (routeTree != null) 'route_tree': routeTree!.toJson(),
        'node_sequence': nodeSequence.map((n) => n.toJson()).toList(),
      };
}

/// dart:core에는 없는 편의 접근자 (collection 패키지 의존 없이).
extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
