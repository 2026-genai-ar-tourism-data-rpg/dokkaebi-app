// ============================================================
// [v1] 시나리오 모델 — 서버 응답(ScenarioGenResponse)과 1:1
// pipeline: 모바일 클라이언트 / 모델 (서버 contract)
// 구현(요약): Scenario · QuestNode + fromJson. 필드명은 서버 JSON(snake_case) 파싱.
// 구현일: 2026-06-18 | 작성: kys (app-scaffold/kys/v1)
// ============================================================

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

/// 퀘스트 노드 한 개 (= 방문 장소 1곳 = 기억석 조각 1개)
class QuestNode {
  final int order;
  final String nodeId;
  final String? name;
  final double? mapX; // 경도
  final double? mapY; // 위도
  final double? distM;
  final int triggerRadiusM;
  final String fragmentId;
  final String npcDialogue;
  final bool isFinale;
  final Mission? mission; // 타입별 미션(핵심: 노드마다 다른 종류)
  final Quiz? quiz; // 앱 호환: 질문형 미션이면 채워짐
  final Objective? objective; // AR 지령+힌트

  QuestNode({
    required this.order,
    required this.nodeId,
    required this.name,
    required this.mapX,
    required this.mapY,
    required this.distM,
    required this.triggerRadiusM,
    required this.fragmentId,
    required this.npcDialogue,
    required this.isFinale,
    this.mission,
    this.quiz,
    this.objective,
  });

  factory QuestNode.fromJson(Map<String, dynamic> j) => QuestNode(
        order: j['order'] ?? 0,
        nodeId: j['node_id'] ?? '',
        name: j['name'],
        mapX: (j['map_x'] as num?)?.toDouble(),
        mapY: (j['map_y'] as num?)?.toDouble(),
        distM: (j['dist_m'] as num?)?.toDouble(),
        triggerRadiusM: j['trigger_radius_m'] ?? 100,
        fragmentId: j['fragment_id'] ?? '',
        npcDialogue: j['npc_dialogue'] ?? '',
        isFinale: j['is_finale'] ?? false,
        mission: j['mission'] != null ? Mission.fromJson(j['mission'] as Map<String, dynamic>) : null,
        quiz: j['quiz'] != null ? Quiz.fromJson(j['quiz'] as Map<String, dynamic>) : null,
        objective: j['objective'] != null ? Objective.fromJson(j['objective'] as Map<String, dynamic>) : null,
      );

  Map<String, dynamic> toJson() => {
        'order': order,
        'node_id': nodeId,
        'name': name,
        'map_x': mapX,
        'map_y': mapY,
        'dist_m': distM,
        'trigger_radius_m': triggerRadiusM,
        'fragment_id': fragmentId,
        'npc_dialogue': npcDialogue,
        'is_finale': isFinale,
        if (mission != null) 'mission': mission!.toJson(),
        if (quiz != null) 'quiz': quiz!.toJson(),
        if (objective != null) 'objective': objective!.toJson(),
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

  Scenario({
    required this.scenarioId,
    required this.title,
    required this.region,
    required this.nodeSequence,
    required this.anchorNodeId,
  });

  factory Scenario.fromJson(Map<String, dynamic> j) => Scenario(
        scenarioId: j['scenario_id'] ?? '',
        title: j['title'] ?? '',
        region: j['region'] ?? '',
        anchorNodeId: j['anchor_node_id'],
        nodeSequence: ((j['node_sequence'] ?? []) as List)
            .map((e) => QuestNode.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'scenario_id': scenarioId,
        'title': title,
        'region': region,
        'anchor_node_id': anchorNodeId,
        'node_sequence': nodeSequence.map((n) => n.toJson()).toList(),
      };
}
