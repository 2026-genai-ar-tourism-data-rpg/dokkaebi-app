// ============================================================
// [v1] 코스별 프롤로그 테스트 — 모델 파싱 + 화면 폴백
// pipeline: 모바일 클라이언트 / 테스트 (prologue-story-gen)
// 커버: ① Scenario.fromJson이 prologue 배열을 파싱한다
//       ② prologue 키가 없으면(구버전 캐시) 빈 배열로 떨어진다(하위호환)
//       ③ PrologueScreen이 서버 프롤로그를 그대로 보여준다
//       ④ prologue가 비어있으면 기존 정적(종로) 대본으로 폴백한다
// 구현일: 2026-09-04 | 작성: ljs (prologue-story-gen/ljs/v1)
// ============================================================
import 'package:dokkaebi_app/models/scenario.dart';
import 'package:dokkaebi_app/screens/prologue_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _scenarioJson({List<Map<String, dynamic>>? prologue}) => {
      'scenario_id': 'scn_test_1',
      'title': '강남구의 기억석 — 1조각 코스',
      'region': '강남구',
      'anchor_node_id': null,
      'node_sequence': [],
      if (prologue != null) 'prologue': prologue,
    };

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Scenario.fromJson — prologue 파싱', () {
    test('prologue 배열을 PrologueLine 리스트로 파싱한다', () {
      final scenario = Scenario.fromJson(_scenarioJson(prologue: [
        {'speaker': 'narration', 'text': '강남구 부근 이야기'},
        {'speaker': 'beat', 'text': '', 'beat': 'reach'},
        {'speaker': 'npc', 'text': '허허, 반갑구나.'},
      ]));

      expect(scenario.prologue, hasLength(3));
      expect(scenario.prologue[0].speaker, 'narration');
      expect(scenario.prologue[0].text, '강남구 부근 이야기');
      expect(scenario.prologue[1].speaker, 'beat');
      expect(scenario.prologue[1].beat, 'reach');
      expect(scenario.prologue[2].speaker, 'npc');
    });

    test('prologue 키가 없으면(구버전 캐시) 빈 배열로 떨어진다', () {
      final scenario = Scenario.fromJson(_scenarioJson());
      expect(scenario.prologue, isEmpty);
    });
  });

  group('PrologueScreen', () {
    testWidgets('서버가 준 프롤로그 대사를 그대로 보여준다', (tester) async {
      final scenario = Scenario.fromJson(_scenarioJson(prologue: [
        {'speaker': 'narration', 'text': '{name}는 강남구 부근을 지나던 평범한 사람이다.'},
      ]));

      await tester.pumpWidget(MaterialApp(
        home: PrologueScreen(scenario: scenario),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('강남구'), findsOneWidget);
      expect(find.textContaining('종로'), findsNothing);
    });

    testWidgets('prologue가 비어있으면 기존 정적(종로) 대본으로 폴백한다', (tester) async {
      final scenario = Scenario.fromJson(_scenarioJson());   // prologue 없음

      await tester.pumpWidget(MaterialApp(
        home: PrologueScreen(scenario: scenario),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('종로'), findsOneWidget);
    });
  });
}
