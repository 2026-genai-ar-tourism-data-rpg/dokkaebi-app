// ============================================================
// [v1] 노드 스키마 v1.1 파싱 + 상태 그래프 게이팅 테스트
// pipeline: 모바일 클라이언트 / 테스트 (contract seam 회귀 방지)
// 구현(요약): 시나리오구조화.md 6-1 노드1 JSON 원문을 그대로 넣어 파싱 검증 +
//            requires 게이팅(soft/hard·부분인지·데드락 금지) + 힌트 사다리 규칙 파싱.
// 구현일: 2026-07-30 | 작성: kys (app-v3-back/kys/v1)
// ============================================================
import 'package:dokkaebi_app/game/hint_ladder_controller.dart';
import 'package:dokkaebi_app/game/player_state.dart';
import 'package:dokkaebi_app/models/scenario.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// 시나리오구조화.md 6-1 — 노드 1(운현궁) 스키마 v1.1 원문.
final node1Json = <String, dynamic>{
  'node_id': 'tour_unhyeongung',
  'order': 0,
  'name': '운현궁',
  'npc': {
    'name': '먹 도깨비',
    'archetype': 'persona',
    'motif': '붓·먹',
    'speech': '~니라, 허허',
    'motivation': 'M1+M7',
  },
  'strategy': ['S4_PHOTO_TRAIL', 'S3_RIDDLE_UNLOCK'],
  'actions': [
    {'a': 'goto', 'place': '운현궁'},
    {
      'a': 'listen',
      'slot': 'intro+choices',
      'choices': [
        {'id': 'A', 'flags': ['호기심'], 'affinity': 1},
        {'id': 'B', 'reward_mod': {'coupon': 100}},
        {'id': 'C'},
      ],
    },
    {
      'a': 'answer',
      'quiz': {'answer_idx': 1, 'correct': {'exp': 30, 'coupon': 200}, 'hints': 'ladder'},
    },
    {'a': 'capture', 'targets': ['대문', '마당', '전통건물 외관']},
    {'a': 'follow', 'object': '먹물 발자국', 'steps': 3},
    {'a': 'tap', 'target': '글씨파편', 'count': [1, 1]},
    {'a': 'report', 'npc': '먹 도깨비'},
  ],
  'hint_ladder': {
    'H1': 'slot',
    'H2': 'slot',
    'H3': 'slot',
    'open_rule': ['fail1|idle60', 'idle90', 'button'],
  },
  'requires': <String>[],
  'requires_mode': 'none',
  'grants': ['fragment:글씨조각1', 'clue:申時'],
  'fragment_id': '글씨조각1',
  'success': ['place_verified', 'photo_done', 'tap:글씨파편>=1'],
};

QuestNode _node({
  required String id,
  String? name,
  int order = 0,
  List<String> grants = const [],
  List<String> requires = const [],
  String mode = 'none',
  bool finale = false,
  String fragmentId = '',
}) =>
    QuestNode.fromJson({
      'node_id': id,
      'name': name ?? id,
      'order': order,
      'grants': grants,
      'requires': requires,
      'requires_mode': mode,
      'is_finale': finale,
      'fragment_id': fragmentId,
    });

/// 종로 4노드 정답지 축약본 (6절 표).
Scenario _jongnoScenario() => Scenario.fromJson({
      'scenario_id': 'jongno_1',
      'title': '종로, 잊혀진 글씨의 비밀',
      'region': '종로',
      'node_sequence': [
        _node(id: 'n1', name: '운현궁', order: 0, grants: ['fragment:글씨조각1', 'clue:申時']).toJson(),
        _node(
          id: 'n2',
          name: '익선동',
          order: 1,
          grants: ['fragment:글씨조각2', 'clue:ㄱ'],
          requires: ['clue:申時'],
          mode: 'soft',
        ).toJson(),
        _node(
          id: 'n3',
          name: '인사동',
          order: 2,
          grants: ['fragment:글씨조각3', 'clue:ㅏ'],
          requires: ['clue:ㄱ'],
          mode: 'soft',
        ).toJson(),
        _node(
          id: 'n4',
          name: '광화문',
          order: 3,
          requires: ['fragment:글씨조각1', 'fragment:글씨조각2', 'fragment:글씨조각3'],
          mode: 'hard',
          finale: true,
        ).toJson(),
      ],
    });

void main() {
  group('노드 스키마 v1.1 파싱 (6-1 원문)', () {
    final n = QuestNode.fromJson(node1Json);

    test('동기는 npc.motivation의 "M1+M7"에서도 읽는다', () {
      expect(n.motivation, ['M1', 'M7']);
      expect(motivationLabels[n.motivation.first], '기억의 수호');
    });

    test('전략 코드 추출', () {
      expect(n.strategy, ['S4_PHOTO_TRAIL', 'S3_RIDDLE_UNLOCK']);
      expect(n.strategyCodes, ['S4', 'S3']);
      expect(strategyLabels['S4'], '사진→추적→파편');
    });

    test('액션 원자 시퀀스 7개 + 타입별 접근자', () {
      expect(n.actions.map((a) => a.a).toList(),
          ['goto', 'listen', 'answer', 'capture', 'follow', 'tap', 'report']);
      expect(n.actions[0].place, '운현궁');
      expect(n.actions[3].targets, ['대문', '마당', '전통건물 외관']);
      expect(n.actions[4].steps, 3);
      expect(n.actions[5].countTarget, 1); // count:[1,1] → 목표 1
      expect(n.actions[6].npc, '먹 도깨비');
      expect(n.actions[2].answerIdx, 1);
    });

    test('선택지 효과는 코드 고정 — 문구(text)는 아직 비어 있어도 파싱된다', () {
      final choices = n.actions[1].choices;
      expect(choices.length, 3);
      expect(choices[0].flags, ['호기심']);
      expect(choices[0].affinity, 1);
      expect(choices[0].text, isNull); // LLM 미생성 슬롯
      expect(choices[1].rewardMod['coupon'], 100);
    });

    test('플레이 단계 액션만 골라낸다 (goto/report 제외)', () {
      expect(n.actions.where((a) => a.isPlayStep).map((a) => a.a).toList(),
          ['listen', 'answer', 'capture', 'follow', 'tap']);
    });

    test('grants 파싱 + 단서 이름 편의 접근', () {
      expect(n.grants.map((g) => g.key).toList(), ['fragment:글씨조각1', 'clue:申時']);
      expect(n.clueName, '申時');
    });

    test('hint_ladder의 "slot" 자리표시자는 문구 없음으로 취급', () {
      expect(n.hintLadder!.isEmpty, isTrue);
      expect(n.hintLadder!.openRule, ['fail1|idle60', 'idle90', 'button']);
    });

    test('success 판정식은 분해하지 않고 원문 보존', () {
      expect(n.success, ['place_verified', 'photo_done', 'tap:글씨파편>=1']);
    });

    test('toJson → fromJson 왕복', () {
      final r = QuestNode.fromJson(n.toJson());
      expect(r.motivation, n.motivation);
      expect(r.strategyCodes, n.strategyCodes);
      expect(r.actions.length, n.actions.length);
      expect(r.grants.map((g) => g.key), n.grants.map((g) => g.key));
      expect(r.success, n.success);
    });
  });

  group('하위호환 — AI 미대응 노드', () {
    test('grants 없으면 fragment_id로 합성', () {
      final n = QuestNode.fromJson({'node_id': 'x', 'fragment_id': '글씨조각1'});
      expect(n.grants, isEmpty);
      expect(n.effectiveGrants.single.key, 'fragment:글씨조각1');
    });

    test('식음 노드는 조각을 주지 않는다', () {
      final n = QuestNode.fromJson({'node_id': 'c', 'kind': 'cafe', 'fragment_id': ''});
      expect(n.isFood, isTrue);
      expect(n.effectiveGrants, isEmpty);
    });

    test('hint_ladder 없으면 mission.hints 3개로 사다리 폴백', () {
      final n = QuestNode.fromJson({
        'node_id': 'x',
        'mission': {'type': 'FIND', 'order': '찾아라', 'hints': ['해 지는 쪽', '이로당 처마', '세 번째 서까래']},
      });
      expect(n.hintLadder, isNull);
      expect(n.hints.filledTiers, 3);
      expect(n.hints.h2, '이로당 처마');
      expect(n.hints.openRule, HintLadder.defaultOpenRule);
    });

    test('requires_mode 미제공 → none', () {
      expect(QuestNode.fromJson({'node_id': 'x'}).requiresMode, RequiresMode.none);
    });
  });

  group('StateRef 표기 파싱', () {
    test('어휘 6종', () {
      expect(StateRef.parse('fragment:글씨조각1').kind, StateKind.fragment);
      expect(StateRef.parse('clue:申時').value, '申時');
      expect(StateRef.parse('flag:호기심').kind, StateKind.flag);
      expect(StateRef.parse('relic:나침반').value, '나침반');
      expect(StateRef.parse('affinity:+1').amount, 1);
      expect(StateRef.parse('coupon:500').amount, 500);
    });

    test('쿠폰 사용처 포함 표기', () {
      final c = StateRef.parse('coupon:익선동카페:500');
      expect(c.to, '익선동카페');
      expect(c.amount, 500);
      expect(c.label, '쿠폰 500원 (익선동카페)');
    });

    test('접두사 없는 구 문자열은 조각으로', () {
      expect(StateRef.parse('글씨조각1').kind, StateKind.fragment);
    });

    test('맵 표기도 받는다', () {
      final r = StateRef.fromJson({'kind': 'clue', 'value': 'ㅏ'});
      expect(r.key, 'clue:ㅏ');
    });
  });

  group('PlayerState 누적', () {
    test('grants 적용 + 저장 문자열 왕복', () {
      final s = PlayerState()
        ..applyAll(StateRef.listFrom(['fragment:글씨조각1', 'clue:申時', 'flag:호기심', 'affinity:+1']))
        ..apply(StateRef.parse('coupon:익선동카페:500'));

      expect(s.fragments, {'글씨조각1'});
      expect(s.clues, {'申時'});
      expect(s.affinity, 1);
      expect(s.couponTotal, 500);

      final round = PlayerState.fromStrings(s.toStrings());
      expect(round.clues, s.clues);
      expect(round.coupons['익선동카페'], 500);
    });

    test('플래그는 누적만 — 중간 소비 없음(규칙 3조)', () {
      final s = PlayerState()..applyAll(StateRef.listFrom(['flag:호기심', 'flag:실리']));
      expect(s.flags, {'호기심', '실리'});
    });

    test('carriedNames = 조각+단서 (대사 연계 주입용)', () {
      final s = PlayerState()..applyAll(StateRef.listFrom(['fragment:글씨조각1', 'clue:申時']));
      expect(s.carriedNames, containsAll(['글씨조각1', '申時']));
    });
  });

  group('requires 게이팅 — 데드락 금지(규칙 1조)', () {
    final sc = _jongnoScenario();

    test('조건 없는 노드는 항상 통과', () {
      final c = sc.checkEntry(sc.nodeSequence[0], PlayerState());
      expect(c.ok, isTrue);
      expect(c.mode, RequiresMode.none);
    });

    test('소프트 미충족 — 진행은 되고 연계 대사만 못 쓴다(D4)', () {
      final c = sc.checkEntry(sc.nodeSequence[1], PlayerState());
      expect(c.ok, isFalse);
      expect(c.softMissing, isTrue);
      expect(c.needsGuidance, isFalse); // 차단 아님
    });

    test('소프트 충족 — 연계 인지 가능', () {
      final s = PlayerState()..apply(StateRef.parse('clue:申時'));
      final c = sc.checkEntry(sc.nodeSequence[1], s);
      expect(c.ok, isTrue);
      expect(c.canRecognize, isTrue);
    });

    test('D1 피날레 직행(0/3) — 안내 모드 + 획득처 역추적', () {
      final c = sc.checkEntry(sc.nodeSequence[3], PlayerState());
      expect(c.needsGuidance, isTrue);
      expect(c.missing.length, 3);
      expect(c.isPartial, isFalse);
      expect(c.highlightPlaces, containsAll(['운현궁', '익선동', '인사동']));
      expect(c.guidance(), contains('운현궁에서 글씨조각1'));
    });

    test('D2 부분 스킵(2/3) — 가진 것 인정, 없는 것만 짚기', () {
      final s = PlayerState()
        ..applyAll(StateRef.listFrom(['fragment:글씨조각1', 'fragment:글씨조각2']));
      final c = sc.checkEntry(sc.nodeSequence[3], s);
      expect(c.isPartial, isTrue);
      expect(c.missing.single.value, '글씨조각3');
      expect(c.guidance(), contains('잘 챘구나'));
      expect(c.guidance(), contains('인사동에서 글씨조각3'));
    });

    test('피날레 requires 충족 → 구조적 종료 보장(규칙 4조)', () {
      final s = PlayerState()
        ..applyAll(StateRef.listFrom(
            ['fragment:글씨조각1', 'fragment:글씨조각2', 'fragment:글씨조각3']));
      expect(sc.checkEntry(sc.nodeSequence[3], s).ok, isTrue);
      expect(sc.finaleUnlocked(s), isTrue);
    });

    test('requires 없는 피날레는 조각 전량으로 폴백 판정', () {
      final legacy = Scenario.fromJson({
        'scenario_id': 'l',
        'title': 't',
        'region': 'r',
        'node_sequence': [
          _node(id: 'a', fragmentId: '조각A').toJson(),
          _node(id: 'b', fragmentId: '조각B').toJson(),
          _node(id: 'f', fragmentId: '조각F', finale: true).toJson(),
        ],
      });
      final partial = PlayerState()..apply(StateRef.parse('fragment:조각A'));
      expect(legacy.finaleUnlocked(partial), isFalse);
      partial.apply(StateRef.parse('fragment:조각B'));
      expect(legacy.finaleUnlocked(partial), isTrue);
    });
  });

  group('힌트 사다리 공개 타이밍 (5절)', () {
    HintLadderController ctl({List<String>? rule}) => HintLadderController(
          ladder: HintLadder(
            h1: '발자국은 해 지는 쪽으로 번졌느니',
            h2: '이로당 처마 아래니라',
            h3: '처마 그늘 왼편, 세 번째 서까래',
            openRule: rule ?? HintLadder.defaultOpenRule,
          ),
          tick: const Duration(milliseconds: 10),
        );

    test('H1은 실패 1회로 즉시 열린다 (fail1)', () {
      final c = ctl();
      expect(c.openTier, 0);
      c.noteFailure();
      expect(c.openTier, 1);
      expect(c.latestText, contains('해 지는 쪽'));
      c.dispose();
    });

    test('H1은 무진행 60초로도 열린다 (idle60)', () {
      fakeAsync((fa) {
        final c = ctl()..start();
        fa.elapse(const Duration(seconds: 59));
        expect(c.openTier, 0);
        fa.elapse(const Duration(seconds: 2));
        expect(c.openTier, 1);
        c.dispose();
      });
    });

    test('진행이 생기면 무진행 타이머 리셋 — 힌트 안 열림', () {
      fakeAsync((fa) {
        final c = ctl()..start();
        fa.elapse(const Duration(seconds: 50));
        c.noteProgress();
        fa.elapse(const Duration(seconds: 50));
        expect(c.openTier, 0);
        c.dispose();
      });
    });

    test('H2는 H1 후 90초 무진행 (idle90)', () {
      fakeAsync((fa) {
        final c = ctl()..start();
        c.noteFailure();
        expect(c.openTier, 1);
        fa.elapse(const Duration(seconds: 89));
        expect(c.openTier, 1);
        fa.elapse(const Duration(seconds: 2));
        expect(c.openTier, 2);
        c.dispose();
      });
    });

    test('H3은 시간으로 열리지 않고 버튼 요청으로만 (button)', () {
      fakeAsync((fa) {
        final c = ctl()..start();
        c.noteFailure();
        fa.elapse(const Duration(minutes: 30));
        expect(c.openTier, 2, reason: 'H3은 대기로 열려선 안 됨');
        expect(c.canRequestMore, isTrue);
        expect(c.requestNext(), isTrue);
        expect(c.openTier, 3);
        expect(c.visibleTexts.length, 3);
        expect(c.hasMore, isFalse);
        expect(c.canRequestMore, isFalse);
        c.dispose();
      });
    });

    test('H2는 버튼으로 못 연다 — 규칙이 idle90뿐(요청형은 H3만)', () {
      final c = ctl();
      c.noteFailure(); // H1 개방
      expect(c.openTier, 1);
      expect(c.canRequestMore, isFalse, reason: 'H2 규칙은 idle90 — 버튼 대상 아님');
      expect(c.requestNext(), isFalse);
      expect(c.openTier, 1);
      c.dispose();
    });

    test('단계가 열릴수록 보상 배율만 감소 — 종류는 불변', () {
      fakeAsync((fa) {
        final c = ctl()..start();
        expect(c.penaltyFactor, 1.0);
        c.noteFailure(); // H1
        expect(c.penaltyFactor, 0.8);
        fa.elapse(const Duration(seconds: 91)); // H2
        expect(c.openTier, 2);
        expect(c.penaltyFactor, 0.6);
        c.requestNext(); // H3 (버튼)
        expect(c.openTier, 3);
        expect(c.penaltyFactor, 0.5);
        c.dispose();
      });
    });

    test('문구가 1단만 있으면 그 이상 열리지 않는다', () {
      final c = HintLadderController(ladder: const HintLadder(h1: '한 줄만'));
      c.noteFailure();
      expect(c.openTier, 1);
      expect(c.hasMore, isFalse);
      expect(c.requestNext(), isFalse);
      c.dispose();
    });

    test('reset — 다음 노드로 넘어갈 때 초기화', () {
      final c = ctl();
      c.noteFailure();
      c.reset();
      expect(c.openTier, 0);
      expect(c.failures, 0);
      c.dispose();
    });
  });
}
