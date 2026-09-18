// ============================================================
// [v1] 빛 순서 기억하기(MemorySequenceGame) 테스트.
// pipeline: 모바일 클라이언트 / 테스트
// 구현(요약): 같은 순서로 누르면 성공, 틀리면 다시 보여 주고 성공 아님, 보여 주는 동안 탭 무시,
//            조각 수는 3~6으로 맞춤.
// 구현일: 2026-09-18
// ============================================================
import 'package:dokkaebi_app/widgets/memory_sequence_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// 시작 지연(700) + 조각당 빛남(600)·쉼(250) — 순서를 다 보여 주고 입력 단계가 되는 시간.
Duration _showTime(int n) => Duration(milliseconds: 700 + n * 850);

Future<void> _pumpGame(WidgetTester tester, {required int count, List<int>? sequence, VoidCallback? onCleared}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: MemorySequenceGame(count: count, sequence: sequence, onCleared: onCleared ?? () {}),
        ),
      ),
    ));

Future<void> _tapTile(WidgetTester tester, int i) async {
  await tester.tap(find.byKey(ValueKey('seq-tile-$i')));
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('보여 준 순서대로 누르면 성공한다', (tester) async {
    var cleared = 0;
    await _pumpGame(tester, count: 3, sequence: const [2, 0, 1], onCleared: () => cleared++);
    expect(find.text('빛나는 순서를 기억하거라…'), findsOneWidget);

    await tester.pump(_showTime(3));
    expect(find.text('같은 순서로 눌러 보거라 (0/3)'), findsOneWidget);

    await _tapTile(tester, 2);
    await _tapTile(tester, 0);
    expect(find.text('같은 순서로 눌러 보거라 (2/3)'), findsOneWidget);
    await _tapTile(tester, 1);

    expect(cleared, 1);
    expect(find.text('기억이 되살아났느니라!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('틀리면 성공이 아니고, 같은 순서를 다시 보여 준 뒤 다시 할 수 있다', (tester) async {
    var cleared = 0;
    await _pumpGame(tester, count: 3, sequence: const [2, 0, 1], onCleared: () => cleared++);
    await tester.pump(_showTime(3));

    await _tapTile(tester, 0); // 첫 조각은 2였다
    expect(find.text('순서가 어긋났느니라 — 다시 보거라'), findsOneWidget);
    expect(cleared, 0);

    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('빛나는 순서를 기억하거라…'), findsOneWidget, reason: '처음부터 다시 보여 준다');

    await tester.pump(_showTime(3));
    for (final i in const [2, 0, 1]) {
      await _tapTile(tester, i);
    }
    expect(cleared, 1);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('순서를 보여 주는 동안의 탭은 무시한다', (tester) async {
    var cleared = 0;
    await _pumpGame(tester, count: 3, sequence: const [0, 1, 2], onCleared: () => cleared++);
    await tester.pump(const Duration(milliseconds: 800));

    await _tapTile(tester, 0); // 아직 보여 주는 중
    await tester.pump(_showTime(3));
    expect(find.text('같은 순서로 눌러 보거라 (0/3)'), findsOneWidget, reason: '보는 중 탭은 입력으로 안 센다');
    expect(cleared, 0);
  });

  testWidgets('조각 수는 3~6으로 맞춘다', (tester) async {
    await _pumpGame(tester, count: 1);
    expect(find.byKey(const ValueKey('seq-tile-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('seq-tile-3')), findsNothing);

    await _pumpGame(tester, count: 9);
    await tester.pump();
    expect(find.byKey(const ValueKey('seq-tile-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('seq-tile-6')), findsNothing);
    await tester.pump(_showTime(6));
  });
}
