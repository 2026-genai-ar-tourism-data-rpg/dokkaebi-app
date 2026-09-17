// ============================================================
// [v1] 도깨비 핀(CustomPainter) 스모크 테스트.
// pipeline: 모바일 클라이언트 / 테스트
// 구현(요약): 두 톤(next·done)이 예외 없이 그려지는지 확인.
// 구현일: 2026-09-18 | 작성: Claude
// ============================================================
import 'package:dokkaebi_app/widgets/dokkaebi_pin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('next 톤 — 번호가 있어도 예외 없이 그려진다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: DokkaebiPin(tone: DokkaebiPinTone.next, number: 3)),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DokkaebiPin), findsOneWidget);
  });

  testWidgets('done 톤 — 번호 없이도(체크 표시) 예외 없이 그려진다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: DokkaebiPin(tone: DokkaebiPinTone.done)),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('두 자리 번호(12)도 예외 없이 그려진다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: DokkaebiPin(tone: DokkaebiPinTone.next, number: 12)),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
