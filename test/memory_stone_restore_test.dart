// ============================================================
// [v1] 기억석 복원 연출(MemoryStoneRestore) 테스트.
// pipeline: 모바일 클라이언트 / 테스트
// 구현(요약): 조각 수만큼 떠오르고, 끝나면 완성체·이름·'계속'이 나오며, 재생 중 탭은 건너뛰기,
//            끝나기 전 '계속'은 눌리지 않는지. 그림 파일·pubspec 등록도 확인.
// 구현일: 2026-09-18
// ============================================================
import 'dart:io';

import 'package:dokkaebi_app/widgets/memory_stone_restore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Finder _asset(String path) =>
    find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == path);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('모은 조각 수만큼 조각이 떠오르고, 끝나면 완성된 기억석과 이름이 나온다', (tester) async {
    var continued = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MemoryStoneRestore(fragmentCount: 4, stoneName: '경주시 기억석', onContinue: () => continued++),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_asset(kMemoryFragmentAsset), findsNWidgets(4));
    expect(_asset(kMemoryStoneAsset), findsNothing, reason: '아직 모이기 전');

    await tester.pump(kRestoreDuration);
    expect(_asset(kMemoryStoneAsset), findsOneWidget);
    expect(find.text('「경주시 기억석」'), findsOneWidget);

    await tester.tap(find.text('계속'));
    expect(continued, 1);
  });

  testWidgets('재생 중 탭하면 끝 장면으로 건너뛰고, 끝나기 전 계속은 눌리지 않는다', (tester) async {
    var continued = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MemoryStoneRestore(fragmentCount: 3, stoneName: '종로구 기억석', onContinue: () => continued++),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('계속'), warnIfMissed: false); // 아직 안 보이는 버튼 자리 — 건너뛰기로 먹힌다
    await tester.pump();
    expect(continued, 0, reason: '끝나기 전엔 계속이 눌리지 않는다');
    expect(_asset(kMemoryStoneAsset), findsOneWidget, reason: '탭으로 끝 장면까지 건너뛰었다');

    await tester.tap(find.text('계속'));
    expect(continued, 1);
  });

  test('조각·완성체·복원 빛 그림이 있고 pubspec에 등록돼 있다', () {
    for (final path in [kMemoryFragmentAsset, kMemoryStoneAsset, kMemoryRestoreFxAsset]) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/game/memory_stone/'));
    expect(pubspec, contains('- assets/game/vfx/'));
  });
}
