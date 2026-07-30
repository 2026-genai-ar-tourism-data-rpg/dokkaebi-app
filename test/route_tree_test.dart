// ============================================================
// [v1] 경로 분기 트리 소비 테스트 — AI route_tree(#24) 파싱 + 순회
// pipeline: 모바일 클라이언트 / 테스트 (앱↔AI 분기 contract 회귀 방지)
// 구현(요약): AI attach_branch가 내는 다이아몬드 트리(BP→[main M | b1 A]→R 재합류)를
//            그대로 넣어 playedPath()가 선택대로 갈리고 재합류하는지 검증.
//            선형(route_tree=null) 폴백 · 사이클 방어 · 선택 대기 목록 포함.
// 구현일: 2026-07-30 | 작성: kys (app-v3-back/kys/v1) · 대응: dokkaebi-ai#24
// ============================================================
import 'package:dokkaebi_app/models/scenario.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _n(String id, {bool finale = false, String path = 'main'}) => {
      'node_id': id,
      'name': id,
      'kind': 'spot',
      'fragment_id': '조각_$id',
      'is_finale': finale,
      'path_id': path,
    };

/// AI attach_branch 출력 형태: n0 → BP(n1) ─┬ main:n2 ┐
///                                          └ b1:alt  ┴→ n3(재합류)
Map<String, dynamic> _branchingScenario() {
  const options = [
    {'choice_id': 'main', 'label': '본래 길 — 「n2」 쪽으로 간다', 'next_node_id': 'n2'},
    {'choice_id': 'b1', 'label': '새어 나온 혼불을 따라 「alt」로 샌다', 'next_node_id': 'alt'},
  ];
  return {
    'scenario_id': 's1',
    'title': '종로, 잊혀진 글씨의 비밀',
    'region': '종로',
    'is_branching': true,
    'route_tree': {
      'entry_node_id': 'n0',
      'branch_points': ['n1'],
      'nodes': {
        'n0': {'next': 'n1'},
        'n1': {'next': 'n2', 'choices': options},
        'n2': {'next': 'n3'},
        'n3': {'next': null},
        'alt': {'next': 'n3'},
      },
    },
    'node_sequence': [
      _n('n0'),
      {..._n('n1'), 'branch': {'prompt': '갈림길이로다. 어느 길로 가려느냐?', 'options': options}},
      _n('n2'),
      _n('n3', finale: true),
      _n('alt', path: 'b1'),
    ],
  };
}

void main() {
  group('route_tree 파싱', () {
    final sc = Scenario.fromJson(_branchingScenario());

    test('is_branching / route_tree 배선', () {
      expect(sc.isBranching, isTrue);
      expect(sc.routeTree, isNotNull);
      expect(sc.routeTree!.entryNodeId, 'n0');
      expect(sc.routeTree!.isBranchPoint('n1'), isTrue);
      expect(sc.routeTree!.isBranchPoint('n2'), isFalse);
    });

    test('분기 노드에 갈림길 프롬프트·갈래 부착', () {
      final bp = sc.nodeById('n1')!;
      expect(bp.branch, isNotNull);
      expect(bp.branch!.prompt, contains('갈림길'));
      expect(bp.branch!.options.map((o) => o.choiceId).toList(), ['main', 'b1']);
      expect(bp.branch!.options[1].nextNodeId, 'alt');
    });

    test('path_id — 샛길 노드만 b1', () {
      expect(sc.nodeById('n2')!.pathId, 'main');
      expect(sc.nodeById('alt')!.pathId, 'b1');
    });

    test('toJson → fromJson 왕복', () {
      final r = Scenario.fromJson(sc.toJson());
      expect(r.isBranching, isTrue);
      expect(r.routeTree!.branchPoints, ['n1']);
      expect(r.nodeById('n1')!.branch!.options.length, 2);
      expect(r.nodeById('alt')!.pathId, 'b1');
    });
  });

  group('playedPath — 선택대로 갈리고 재합류', () {
    final sc = Scenario.fromJson(_branchingScenario());

    test('미선택이면 기본(main) 갈래', () {
      expect(sc.playedPath().map((n) => n.nodeId).toList(), ['n0', 'n1', 'n2', 'n3']);
    });

    test('main 선택 — 본래 길', () {
      expect(sc.playedPath({'n1': 'main'}).map((n) => n.nodeId).toList(),
          ['n0', 'n1', 'n2', 'n3']);
    });

    test('b1 선택 — 샛길로 갔다가 n3에서 재합류', () {
      final path = sc.playedPath({'n1': 'b1'}).map((n) => n.nodeId).toList();
      expect(path, ['n0', 'n1', 'alt', 'n3']);
      expect(path.last, 'n3', reason: '두 갈래 모두 피날레로 수렴');
    });

    test('두 갈래 길이가 같다 — 조각 총량 도달 가능', () {
      expect(sc.playedPath({'n1': 'main'}).length, sc.playedPath({'n1': 'b1'}).length);
    });

    test('없는 choice_id는 기본 갈래로 폴백', () {
      expect(sc.playedPath({'n1': '없는갈래'}).map((n) => n.nodeId).toList(),
          ['n0', 'n1', 'n2', 'n3']);
    });

    test('선택 대기 갈림길 목록', () {
      expect(sc.pendingBranchNodes({}).map((n) => n.nodeId).toList(), ['n1']);
      expect(sc.pendingBranchNodes({'n1': 'b1'}), isEmpty);
    });
  });

  group('선형·방어', () {
    test('route_tree 없으면 node_sequence 그대로', () {
      final sc = Scenario.fromJson({
        'scenario_id': 'l',
        'title': 't',
        'region': 'r',
        'node_sequence': [_n('a'), _n('b'), _n('c', finale: true)],
      });
      expect(sc.isBranching, isFalse);
      expect(sc.routeTree, isNull);
      expect(sc.playedPath().map((n) => n.nodeId).toList(), ['a', 'b', 'c']);
      expect(sc.pendingBranchNodes({}), isEmpty);
    });

    test('사이클이 있어도 순회는 종료한다', () {
      final tree = RouteTree.fromJson({
        'entry_node_id': 'a',
        'branch_points': <String>[],
        'nodes': {
          'a': {'next': 'b'},
          'b': {'next': 'a'}, // 순환
        },
      });
      expect(tree.traverse(), ['a', 'b']);
    });

    test('빈 트리는 빈 경로', () {
      final tree = RouteTree.fromJson({'entry_node_id': '', 'nodes': <String, dynamic>{}});
      expect(tree.isEmpty, isTrue);
      expect(tree.traverse(), isEmpty);
    });
  });
}
