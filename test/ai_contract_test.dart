// ============================================================
// [v1] AI↔앱 계약 테스트 — dokkaebi-ai 생성층(#30) 실제 출력을 앱 모델로 파싱
// pipeline: 모바일 클라이언트 / 테스트 (레포 간 contract 회귀 방지)
// 구현(요약): AI `enrich_quest()`가 실제로 내놓은 노드 JSON을 픽스처로 고정하고
//            QuestNode.fromJson으로 통과시켜 **필드명·모양이 어긋나면 CI가 빨개지게** 한다.
//            파일이 안 겹치는 레포 간 변경은 git이 알려주지 않아 이 테스트가 유일한 방어선.
//            픽스처 갱신법: dokkaebi-ai에서 enrich_quest 출력을 떠서 이 파일 옆에 덮어쓴다.
// 구현일: 2026-07-30 | 작성: kys (integration/kys/v1) · 대응: dokkaebi-ai#34(#30)
// ============================================================
import 'dart:convert';
import 'dart:io';

import 'package:dokkaebi_app/game/player_state.dart';
import 'package:dokkaebi_app/models/scenario.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _aiNode() => jsonDecode(
      File('test/fixtures/ai_node_contract.json').readAsStringSync(),
    ) as Map<String, dynamic>;

/// AI `/v1/scenarios` 응답 전문(실제 출력에서 노드 3개만 남겨 축소).
/// 노드 단위 픽스처와 달리 좌표·반경·분기 트리까지 담고 있다.
Map<String, dynamic> _aiScenario() => jsonDecode(
      File('test/fixtures/ai_scenario_contract.json').readAsStringSync(),
    ) as Map<String, dynamic>;

void main() {
  group('AI 생성층 출력 → 앱 모델 (C4 계약)', () {
    late QuestNode node;

    setUpAll(() => node = QuestNode.fromJson(_aiNode()));

    test('3층 문법이 파싱된다 — 동기·전략·액션', () {
      expect(node.motivation, isNotEmpty, reason: 'AI가 motivation을 안 내리면 화면이 동기를 못 보여준다');
      expect(node.motivation.every((m) => motivationLabels.containsKey(m)), isTrue,
          reason: '동기 코드가 M1~M9 어휘 밖이면 라벨이 안 붙는다: ${node.motivation}');

      expect(node.strategy, isNotEmpty);
      expect(node.strategyCodes.every((s) => strategyLabels.containsKey(s)), isTrue,
          reason: '전략 코드가 S1~S7 밖: ${node.strategyCodes}');

      expect(node.actions, isNotEmpty);
      // 액션 어휘 10종 — 모르는 a는 앱이 무시하므로 '조용히 사라지는' 액션을 잡아낸다
      const known = {
        'goto', 'listen', 'answer', 'capture', 'tap', 'defeat',
        'follow', 'purchase', 'combine', 'report',
      };
      final unknown = node.actions.map((a) => a.a).where((a) => !known.contains(a)).toSet();
      expect(unknown, isEmpty, reason: '앱이 모르는 액션 = 조용히 무시됨: $unknown');
    });

    test('액션 시퀀스가 goto로 시작하고 report로 끝난다', () {
      expect(node.actions.first.a, 'goto');
      expect(node.actions.last.a, 'report');
    });

    test('플레이 단계 액션이 최소 1개는 있다 — 빈 노드 방지', () {
      expect(node.actions.where((a) => a.isPlayStep), isNotEmpty,
          reason: 'goto/report만 있으면 플레이할 게 없는 노드가 된다');
    });

    test('액션 파라미터가 앱 접근자로 읽힌다', () {
      for (final a in node.actions) {
        switch (a.a) {
          case 'goto':
            expect(a.place, isNotNull, reason: 'goto에 place 없음');
          case 'capture':
            expect(a.targets, isNotEmpty, reason: 'capture에 targets 없음');
          case 'follow':
            expect(a.countTarget, greaterThan(0), reason: 'follow 목표 수가 0');
          case 'tap':
            expect(a.target, isNotNull, reason: 'tap에 target 없음');
            expect(a.countTarget, greaterThan(0), reason: 'tap 목표 수가 0 → 영원히 못 끝낸다');
          case 'report':
            expect(a.npc, isNotNull, reason: 'report에 npc 없음');
        }
      }
    });

    test('listen 선택지 — 효과는 코드 고정, 문구는 채워져 있다', () {
      final listen = node.actions.where((a) => a.a == 'listen').toList();
      expect(listen, isNotEmpty);
      final choices = listen.first.choices;
      expect(choices.length, greaterThanOrEqualTo(2), reason: '분기 선택지가 2개 미만');
      for (final c in choices) {
        expect(c.id, isNotEmpty);
        expect(c.text, isNotNull, reason: 'LLM이 선택지 문구를 안 채웠다: ${c.id}');
      }
    });

    test('grants가 StateRef로 파싱되고 상태 그래프에 들어간다', () {
      expect(node.effectiveGrants, isNotEmpty);
      // 앱 StateRef는 모르는 접두사를 '조각'으로 간주한다 →
      // 어휘 밖 접두사(visit:/bonus: 등)를 쓰면 가짜 조각이 생겨 진행률이 틀어진다
      for (final g in node.grants) {
        expect(g.kind, isNot(StateKind.unknown),
            reason: '어휘 밖 상태 접두사 → 가짜 조각으로 오인됨: $g');
      }
      final state = PlayerState()..applyAll(node.effectiveGrants);
      expect(state.fragments.length + state.clues.length, greaterThan(0));
    });

    test('requires_mode가 어휘 안에 있다', () {
      expect(RequiresMode.values, contains(node.requiresMode));
      // requires가 있는데 mode가 none이면 게이팅이 조용히 죽는다
      if (node.requires.isNotEmpty) {
        expect(node.requiresMode, isNot(RequiresMode.none),
            reason: 'requires는 있는데 mode=none → 게이팅이 동작하지 않는다');
      }
    });

    test('힌트 사다리 — 문구가 채워지고 공개 규칙이 앱 파서와 맞는다', () {
      final h = node.hints;
      expect(h.filledTiers, greaterThan(0), reason: '힌트 문구가 하나도 없다(ai#31 대기 항목)');
      expect(h.openRule.length, 3, reason: 'open_rule 3단이 아니면 앱이 기본값으로 폴백한다');
      // 앱 파서가 이해하는 토큰인지 — 모르면 그 단이 안 열린다
      final tokenOk = RegExp(r'^(fail\d+|idle\d+|button|request)(\|(fail\d+|idle\d+|button|request))*$');
      for (final r in h.openRule) {
        expect(tokenOk.hasMatch(r), isTrue, reason: '앱이 못 읽는 공개 규칙 → 그 단이 안 열린다: "$r"');
      }
    });

    test('구 필드(mission)가 남아 하위호환된다', () {
      expect(node.mission, isNotNull, reason: '구 화면 폴백 경로가 끊긴다');
    });

    test('quiz는 질문형 미션에서만 채워진다 (항상 있는 게 아니다)', () {
      // AI to_quiz()는 QUIZ_FIND·DIALOGUE_FIND만 quiz dict로 매핑하고 나머지는 None.
      // v1 테스트는 quiz를 항상 non-null로 단정했는데, 그건 당시 픽스처가 우연히
      // 질문형이었을 뿐이다 — 실측 5노드 중 quiz를 가진 노드는 0개였다.
      // 앱은 quiz가 없으면 mission/objective로 그리므로 null이 정상이다.
      const questionTypes = {'QUIZ_FIND', 'DIALOGUE_FIND'};
      final type = node.mission?.type;
      if (questionTypes.contains(type)) {
        expect(node.quiz, isNotNull, reason: '$type인데 quiz가 없으면 질문 화면을 못 그린다');
      } else {
        expect(node.quiz, isNull, reason: '$type에 quiz가 붙으면 앱이 엉뚱한 질문 화면을 띄운다');
      }
    });

    test('식음 노드가 아니면 조각을 준다', () {
      expect(node.isStone, isTrue);
      expect(node.fragmentId, isNotEmpty);
    });

    test('toJson 왕복 — 앱이 저장·복원해도 필드가 살아남는다', () {
      final r = QuestNode.fromJson(node.toJson());
      expect(r.motivation, node.motivation);
      expect(r.strategyCodes, node.strategyCodes);
      expect(r.actions.map((a) => a.a), node.actions.map((a) => a.a));
      expect(r.grants.map((g) => g.key), node.grants.map((g) => g.key));
      expect(r.hints.filledTiers, node.hints.filledTiers);
    });
  });

  group('AI 노드로 시나리오 구성 — 게이팅까지 도는가', () {
    test('단일 노드 시나리오가 게이팅·경로 계산에 태워진다', () {
      final sc = Scenario.fromJson({
        'scenario_id': 'contract',
        'title': '계약 확인',
        'region': '종로',
        'node_sequence': [_aiNode()],
      });
      expect(sc.stoneNodes, isNotEmpty);
      expect(sc.playedPath().length, 1);

      final state = PlayerState();
      final check = sc.checkEntry(sc.nodeSequence.first, state);
      expect(check.needsGuidance, isFalse, reason: '첫 노드가 안내 모드로 막히면 시작을 못 한다');
    });
  });

  // ── [v2] 시나리오 전문 계약 — GPS 게임 루프가 쓰는 필드까지 ──────────────
  //
  // 노드 픽스처만 보던 v1은 map_x·map_y·trigger_radius_m·stone_no·source를
  // 아예 안 담고 있었다. 서버 verify-location이 이 값들로 반경 판정을 하므로,
  // AI가 좌표 필드명을 바꾸면 GPS 인증이 통째로 죽는데 테스트는 초록이었다.
  group('AI 시나리오 전문 → 앱 모델 (GPS 루프 계약)', () {
    late Scenario scenario;

    setUpAll(() => scenario = Scenario.fromJson(_aiScenario()));

    test('시나리오 메타가 파싱된다', () {
      expect(scenario.scenarioId, isNotEmpty);
      expect(scenario.region, isNotEmpty);
      expect(scenario.stoneTotal, isNotNull, reason: '조각 총수가 없으면 진행도 N/M을 못 그린다');
      expect(scenario.nodeSequence, isNotEmpty);
    });

    test('[회귀] 모든 노드가 GPS 판정에 필요한 좌표·반경을 갖는다', () {
      for (final n in scenario.stoneNodes) {
        expect(n.mapY, isNotNull, reason: '${n.name}: 위도 없음 → 서버가 반경 판정 불가');
        expect(n.mapX, isNotNull, reason: '${n.name}: 경도 없음 → 서버가 반경 판정 불가');
        expect(n.triggerRadiusM, greaterThan(0),
            reason: '${n.name}: trigger_radius_m이 0/누락이면 어디서도 도착 판정이 안 난다');
      }
    });

    test('[회귀] 기억석 노드는 조각 id와 번호를 갖는다', () {
      for (final n in scenario.stoneNodes) {
        expect(n.fragmentId, isNotEmpty, reason: '${n.name}: fragment_id 없으면 조각 획득 불가');
        expect(n.stoneNo, isNotNull, reason: '${n.name}: stone_no 없으면 "N번째 조각" 표시 불가');
      }
    });

    test('피날레가 정확히 하나이고 anchor_node_id와 일치한다', () {
      final finales = scenario.nodeSequence.where((n) => n.isFinale).toList();
      expect(finales.length, 1);
      expect(scenario.anchorNodeId, finales.first.nodeId);
    });

    test('toJson 왕복 — 저장했다 복원해도 좌표·반경이 살아남는다', () {
      final r = Scenario.fromJson(scenario.toJson());
      expect(r.nodeSequence.length, scenario.nodeSequence.length);
      for (var i = 0; i < r.nodeSequence.length; i++) {
        final a = scenario.nodeSequence[i];
        final b = r.nodeSequence[i];
        expect(b.mapX, a.mapX, reason: '${a.name}: 저장 왕복에서 경도 유실');
        expect(b.mapY, a.mapY, reason: '${a.name}: 저장 왕복에서 위도 유실');
        expect(b.triggerRadiusM, a.triggerRadiusM, reason: '${a.name}: 저장 왕복에서 반경 유실');
        expect(b.fragmentId, a.fragmentId);
      }
      expect(r.stoneTotal, scenario.stoneTotal);
      expect(r.anchorNodeId, scenario.anchorNodeId);
    });

    test('예산이 파싱된다 — 앱이 보낸 값을 되읽을 수 있어야 한다', () {
      final withBudget = Scenario.fromJson({
        ..._aiScenario(),
        'budget': 30000,
      });
      expect(withBudget.budget, 30000,
          reason: '앱이 budget을 보내고도 응답에서 못 읽으면 저장된 코스의 예산을 표시할 수 없다');
      // 왕복도 보존되어야 저장된 코스에서 예산이 사라지지 않는다
      expect(Scenario.fromJson(withBudget.toJson()).budget, 30000);
    });
  });
}
