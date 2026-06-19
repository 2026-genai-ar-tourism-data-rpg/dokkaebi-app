// ============================================================
// [v1] 시나리오 모델 — 서버 응답(ScenarioGenResponse)과 1:1
// pipeline: 모바일 클라이언트 / 모델 (서버 contract)
// 구현(요약): Scenario · QuestNode + fromJson. 필드명은 서버 JSON(snake_case) 파싱.
// 구현일: 2026-06-18 | 작성: kys (app-scaffold/kys/v1)
// ============================================================

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
