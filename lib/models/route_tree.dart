// ============================================================
// [v1] 경로 분기 트리 — AI route_tree(#24) 앱 소비 모델
// pipeline: 모바일 클라이언트 / 모델 (갈림길 선택지 렌더 + 실제 밟는 경로 계산)
// 구현(요약): AI route_branching.py의 route_tree(eager 다이아몬드)를 앱에서 읽는다.
//            RouteTree.traverse(choices)는 파이썬 traverse()와 동일 규칙 —
//            분기 노드에서 선택이 있으면 그 갈래, 없으면 기본(main). 사이클 방어로 항상 종료.
//            선형 시나리오(route_tree=null)면 node_sequence 순서를 그대로 경로로 쓴다.
// 구현일: 2026-07-30 | 작성: kys (app-v3-back/kys/v1) · 대응: dokkaebi-ai#24
// ============================================================

/// 갈림길 선택지 하나 — 앱은 label을 버튼으로 띄우고 choiceId를 되돌려준다.
class BranchOption {
  final String choiceId; // "main" | "b1"
  final String label;
  final String nextNodeId;

  const BranchOption({required this.choiceId, required this.label, required this.nextNodeId});

  factory BranchOption.fromJson(Map<String, dynamic> j) => BranchOption(
        choiceId: (j['choice_id'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        nextNodeId: (j['next_node_id'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() =>
      {'choice_id': choiceId, 'label': label, 'next_node_id': nextNodeId};
}

/// 분기 노드에 붙는 갈림길 프롬프트 + 갈래.
class NodeBranch {
  final String prompt;
  final List<BranchOption> options;

  const NodeBranch({required this.prompt, required this.options});

  factory NodeBranch.fromJson(Map<String, dynamic> j) => NodeBranch(
        prompt: (j['prompt'] ?? '갈림길이로다. 어느 길로 가려느냐?').toString(),
        options: (j['options'] is List)
            ? (j['options'] as List)
                .whereType<Map>()
                .map((e) => BranchOption.fromJson(e.cast<String, dynamic>()))
                .toList()
            : const [],
      );

  Map<String, dynamic> toJson() =>
      {'prompt': prompt, 'options': options.map((o) => o.toJson()).toList()};
}

/// 트리 간선 — 기본 next + (분기 노드면) choices.
class TreeEdge {
  final String? next;
  final List<BranchOption> choices;

  const TreeEdge({this.next, this.choices = const []});

  factory TreeEdge.fromJson(Map<String, dynamic> j) => TreeEdge(
        next: j['next']?.toString(),
        choices: (j['choices'] is List)
            ? (j['choices'] as List)
                .whereType<Map>()
                .map((e) => BranchOption.fromJson(e.cast<String, dynamic>()))
                .toList()
            : const [],
      );

  Map<String, dynamic> toJson() => {
        'next': next,
        if (choices.isNotEmpty) 'choices': choices.map((c) => c.toJson()).toList(),
      };
}

/// 분기 그래프. `attach_branch`가 만든 유계 다이아몬드(갈림길 1곳, 한 노드 뒤 재합류).
class RouteTree {
  final String entryNodeId;
  final List<String> branchPoints;
  final Map<String, TreeEdge> nodes;

  const RouteTree({required this.entryNodeId, required this.branchPoints, required this.nodes});

  factory RouteTree.fromJson(Map<String, dynamic> j) => RouteTree(
        entryNodeId: (j['entry_node_id'] ?? '').toString(),
        branchPoints: (j['branch_points'] is List)
            ? (j['branch_points'] as List).map((e) => e.toString()).toList()
            : const [],
        nodes: (j['nodes'] is Map)
            ? (j['nodes'] as Map).map((k, v) => MapEntry(
                k.toString(),
                TreeEdge.fromJson((v as Map).cast<String, dynamic>())))
            : const {},
      );

  Map<String, dynamic> toJson() => {
        'entry_node_id': entryNodeId,
        'branch_points': branchPoints,
        'nodes': nodes.map((k, v) => MapEntry(k, v.toJson())),
      };

  bool get isEmpty => nodes.isEmpty || entryNodeId.isEmpty;

  bool isBranchPoint(String nodeId) => branchPoints.contains(nodeId);

  /// 이 노드에서 고를 수 있는 갈래(분기 노드가 아니면 빈 리스트).
  List<BranchOption> choicesAt(String nodeId) => nodes[nodeId]?.choices ?? const [];

  /// 선택(`{분기노드id: choiceId}`)을 반영해 **실제 밟는 노드 경로**를 낸다.
  /// AI route_branching.traverse()와 동일 규칙 — 미선택이면 기본 next(main).
  List<String> traverse([Map<String, String> choices = const {}]) {
    final path = <String>[];
    final seen = <String>{};
    String? cur = entryNodeId.isEmpty ? null : entryNodeId;
    while (cur != null && !seen.contains(cur)) {
      seen.add(cur);
      path.add(cur);
      final edge = nodes[cur];
      if (edge == null) break;
      if (edge.choices.isNotEmpty) {
        final pick = choices[cur];
        final taken = edge.choices.where((o) => o.choiceId == pick).firstOrNull;
        cur = taken?.nextNodeId ?? edge.next;
      } else {
        cur = edge.next;
      }
    }
    return path;
  }

  /// 아직 선택하지 않은 갈림길 — 진행판·지도에서 "선택 대기" 표시에 사용.
  List<String> pendingBranchPoints(Map<String, String> choices) =>
      branchPoints.where((bp) => !choices.containsKey(bp)).toList();
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
