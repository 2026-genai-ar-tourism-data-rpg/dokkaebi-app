// ============================================================
// [v1] 퀴즈 귀띔 단서 모델 테스트 — Quiz.eliminatedFor · QuestNode.quizClue · Scenario.quizClues.
// pipeline: 모바일 클라이언트 / 테스트
// 구현(요약): 지울 오답은 정답이 아니고 장소마다 고정, 보기가 적으면 안 지움. 퀴즈(S3)가 요구하는
//            단서만 귀띔 단서로 치고, 코스에서 보여 줄 단서는 그것뿐인지.
// 구현일: 2026-09-19
// ============================================================
import 'package:dokkaebi_app/models/scenario.dart';
import 'package:flutter_test/flutter_test.dart';

Quiz _quiz(int options, {int answer = 1}) =>
    Quiz(q: '?', options: [for (var i = 0; i < options; i++) '보기$i'], answer: answer, wrongHint: '');

Map<String, dynamic> _node(String id,
        {String? strategy, int options = 4, List<String> requires = const [], List<String> grants = const []}) =>
    {
      'node_id': id,
      'name': '장소$id',
      'kind': 'spot',
      'fragment_id': 'frag_$id',
      'grants': grants,
      'requires': requires,
      'requires_mode': requires.isEmpty ? 'none' : 'soft',
      'is_finale': false,
      if (strategy != null) 'strategy': [strategy],
      'quiz': {'q': '?', 'options': [for (var i = 0; i < options; i++) '보기$i'], 'answer': 0},
    };

void main() {
  group('지울 오답', () {
    test('정답이 아닌 보기를 고르고, 같은 장소면 늘 같은 보기다', () {
      final quiz = _quiz(4, answer: 2);
      for (final seed in ['q1', 'q2', 'tour_126508', '대릉원', '']) {
        final e = quiz.eliminatedFor(seed);
        expect(e, isNotNull);
        expect(e, isNot(2), reason: '정답을 지우면 안 된다');
        expect(e, inInclusiveRange(0, 3));
        expect(quiz.eliminatedFor(seed), e);
      }
    });

    test('보기가 3개보다 적으면 지우지 않는다 — 남은 하나가 곧 정답이 된다', () {
      expect(_quiz(2, answer: 0).eliminatedFor('q1'), isNull);
      expect(_quiz(0, answer: 0).eliminatedFor('q1'), isNull);
      expect(_quiz(kQuizClueMinOptions, answer: 0).eliminatedFor('q1'), isNotNull);
    });
  });

  group('퀴즈 귀띔 단서', () {
    test('퀴즈(S3)가 요구하는 단서가 그 퀴즈의 귀띔이다', () {
      final n = QuestNode.fromJson(_node('q', strategy: 'S3_RIDDLE_UNLOCK', requires: ['clue:장소q 시험의 귀띔']));
      expect(n.quizClue, '장소q 시험의 귀띔');
    });

    test('퀴즈가 아니거나 보기가 적거나 요구하는 단서가 없으면 귀띔이 아니다', () {
      expect(QuestNode.fromJson(_node('a', strategy: 'S2_HUNT_GATHER', requires: ['clue:三影'])).quizClue, isNull);
      expect(QuestNode.fromJson(_node('b', requires: ['clue:三影'])).quizClue, isNull, reason: 'strategy 없음');
      expect(QuestNode.fromJson(_node('c', strategy: 'S3_RIDDLE_UNLOCK', options: 2, requires: ['clue:ㄱ'])).quizClue,
          isNull);
      expect(QuestNode.fromJson(_node('d', strategy: 'S3_RIDDLE_UNLOCK', requires: ['fragment:frag_a'])).quizClue,
          isNull);
    });

    test('코스에서 보여 줄 단서는 퀴즈가 쓰는 것뿐이다 — 예전 코스의 쓰임 없는 단서는 빠진다', () {
      final sc = Scenario.fromJson({
        'scenario_id': 's',
        'title': 't',
        'region': 'r',
        'node_sequence': [
          _node('1', grants: ['clue:장소2 시험의 귀띔']),
          _node('2', strategy: 'S3_RIDDLE_UNLOCK', requires: ['clue:장소2 시험의 귀띔'], grants: ['clue:三影']),
          _node('3', strategy: 'S2_HUNT_GATHER', requires: ['clue:三影']),
        ],
      });
      expect(sc.quizClues, {'장소2 시험의 귀띔'});
    });
  });
}
