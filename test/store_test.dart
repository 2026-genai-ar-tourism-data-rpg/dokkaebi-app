// ============================================================
// [v1] 스토어 영속 테스트 — 상태 그래프·갈림길·엔딩이 재시작 후에도 남는가
// pipeline: 모바일 클라이언트 / 테스트 (진행상황 영속 회귀 방지)
// 구현(요약): completeNode/grant/chooseBranch/setEnding 후 load()로 되살려
//            PlayerState(플래그·친밀도·쿠폰)와 갈림길 선택이 그대로인지 검증.
//            소유형 중복 지급 차단(재방문 이중 누적 ❌)·누적형 합산도 확인.
// 구현일: 2026-07-30 | 작성: kys (app-v3-back/kys/v1)
// ============================================================
import 'package:dokkaebi_app/models/scenario.dart';
import 'package:dokkaebi_app/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const sid = 'jongno_1';

QuestNode _node(String id, {List<String> grants = const [], String fragmentId = ''}) =>
    QuestNode.fromJson({
      'node_id': id,
      'name': id,
      'fragment_id': fragmentId,
      'grants': grants,
    });

Scenario _scenario() => Scenario.fromJson({
      'scenario_id': sid,
      'title': '종로, 잊혀진 글씨의 비밀',
      'region': '종로',
      'node_sequence': [
        _node('n1', grants: ['fragment:글씨조각1', 'clue:申時']).toJson(),
        _node('n2', grants: ['fragment:글씨조각2', 'clue:ㄱ']).toJson(),
      ],
    });

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ScenarioStore.I.load();
    await ScenarioStore.I.resetProgress(sid);
  });

  group('상태 그래프 영속', () {
    test('노드 grants → 재시작 후에도 조각·단서 유지', () async {
      final sc = _scenario();
      await ScenarioStore.I.add(sc);
      await ScenarioStore.I.completeNodeWithGrants(sid, sc.nodeSequence[0]);

      await ScenarioStore.I.load(); // 앱 재시작 시뮬
      final st = ScenarioStore.I.stateOf(sid);
      expect(st.fragments, {'글씨조각1'});
      expect(st.clues, {'申時'});
      expect(ScenarioStore.I.doneOf(sid), ['n1']);
    });

    test('플래그·친밀도·쿠폰도 살아남는다 (v1에서 유실됐던 부분)', () async {
      await ScenarioStore.I.add(_scenario());
      await ScenarioStore.I.grant(sid, [
        const StateRef(kind: StateKind.flag, value: '호기심'),
        const StateRef(kind: StateKind.affinity, value: '', amount: 1),
        const StateRef(kind: StateKind.coupon, value: '', to: '익선동카페', amount: 500),
        const StateRef(kind: StateKind.relic, value: '나침반'),
      ]);

      await ScenarioStore.I.load();
      final st = ScenarioStore.I.stateOf(sid);
      expect(st.flags, {'호기심'});
      expect(st.affinity, 1);
      expect(st.coupons['익선동카페'], 500);
      expect(st.relics, {'나침반'});
    });

    test('소유형은 중복 지급 안 됨 — 재방문해도 조각 1개', () async {
      final sc = _scenario();
      await ScenarioStore.I.add(sc);
      await ScenarioStore.I.completeNodeWithGrants(sid, sc.nodeSequence[0]);
      await ScenarioStore.I.completeNodeWithGrants(sid, sc.nodeSequence[0]); // 재방문

      expect(ScenarioStore.I.doneOf(sid), ['n1']);
      expect(ScenarioStore.I.stateOf(sid).fragments, {'글씨조각1'});
      expect(ScenarioStore.I.inventoryOf(sid).where((e) => e == 'fragment:글씨조각1').length, 1);
    });

    test('누적형(쿠폰·친밀도)은 여러 번 쌓인다', () async {
      await ScenarioStore.I.add(_scenario());
      final coupon = const StateRef(kind: StateKind.coupon, value: '', to: '익선동카페', amount: 500);
      await ScenarioStore.I.grant(sid, [coupon]);
      await ScenarioStore.I.grant(sid, [coupon]);

      expect(ScenarioStore.I.stateOf(sid).coupons['익선동카페'], 1000);
    });

    test('v1 형식(접두사 없는 조각 문자열)도 읽는다 — 하위호환', () async {
      await ScenarioStore.I.add(_scenario());
      await ScenarioStore.I.completeNode(sid, 'n1', ['글씨조각1', '申時']);

      await ScenarioStore.I.load();
      // 접두사 없으면 조각으로 파싱(구 inventory 호환)
      expect(ScenarioStore.I.stateOf(sid).fragments, containsAll(['글씨조각1', '申時']));
    });
  });

  group('갈림길 선택 영속', () {
    Scenario branching() => Scenario.fromJson({
          'scenario_id': sid,
          'title': 't',
          'region': 'r',
          'is_branching': true,
          'route_tree': {
            'entry_node_id': 'n1',
            'branch_points': ['n1'],
            'nodes': {
              'n1': {
                'next': 'n2',
                'choices': [
                  {'choice_id': 'main', 'label': '본래 길', 'next_node_id': 'n2'},
                  {'choice_id': 'b1', 'label': '샛길', 'next_node_id': 'alt'},
                ],
              },
              'n2': {'next': 'n3'},
              'alt': {'next': 'n3'},
              'n3': {'next': null},
            },
          },
          'node_sequence': [
            _node('n1', fragmentId: '조각1').toJson(),
            _node('n2', fragmentId: '조각2').toJson(),
            _node('n3', fragmentId: '조각3').toJson(),
            _node('alt', fragmentId: '조각alt').toJson(),
          ],
        });

    test('선택이 저장되고 pathOf가 그 갈래로 순회', () async {
      final sc = branching();
      await ScenarioStore.I.add(sc);
      expect(ScenarioStore.I.pathOf(sc).map((n) => n.nodeId).toList(), ['n1', 'n2', 'n3']);

      await ScenarioStore.I.chooseBranch(sid, 'n1', 'b1');
      await ScenarioStore.I.load();

      final restored = ScenarioStore.I.scenarios.first;
      expect(ScenarioStore.I.choicesOf(sid), {'n1': 'b1'});
      expect(ScenarioStore.I.pathOf(restored).map((n) => n.nodeId).toList(), ['n1', 'alt', 'n3']);
    });
  });

  group('엔딩 · 초기화', () {
    test('엔딩 기록·복원', () async {
      await ScenarioStore.I.add(_scenario());
      expect(ScenarioStore.I.endingOf(sid), isNull);
      await ScenarioStore.I.setEnding(sid, 'good');

      await ScenarioStore.I.load();
      expect(ScenarioStore.I.endingOf(sid), 'good');
    });

    test('resetProgress — 진행만 지우고 시나리오는 남긴다', () async {
      final sc = _scenario();
      await ScenarioStore.I.add(sc);
      await ScenarioStore.I.completeNodeWithGrants(sid, sc.nodeSequence[0]);
      await ScenarioStore.I.chooseBranch(sid, 'n1', 'b1');
      await ScenarioStore.I.setEnding(sid, 'good');

      await ScenarioStore.I.resetProgress(sid);
      await ScenarioStore.I.load();

      expect(ScenarioStore.I.scenarios.map((s) => s.scenarioId), contains(sid));
      expect(ScenarioStore.I.doneOf(sid), isEmpty);
      expect(ScenarioStore.I.stateOf(sid).fragments, isEmpty);
      expect(ScenarioStore.I.choicesOf(sid), isEmpty);
      expect(ScenarioStore.I.endingOf(sid), isNull);
    });

    test('조각 진행률은 식음 노드를 세지 않는다', () async {
      final sc = Scenario.fromJson({
        'scenario_id': sid,
        'title': 't',
        'region': 'r',
        'node_sequence': [
          _node('s1', fragmentId: '조각1').toJson(),
          {'node_id': 'c1', 'kind': 'cafe', 'fragment_id': ''},
          _node('s2', fragmentId: '조각2').toJson(),
        ],
      });
      await ScenarioStore.I.add(sc);
      await ScenarioStore.I.completeNode(sid, 's1', ['fragment:조각1']);
      await ScenarioStore.I.completeNode(sid, 'c1', []);

      expect(ScenarioStore.I.progressOf(sc), 2); // 방문 노드 수
      expect(ScenarioStore.I.stoneProgressOf(sc), 1); // 조각은 1개
      expect(sc.stoneTotal, 2);
    });
  });
}
