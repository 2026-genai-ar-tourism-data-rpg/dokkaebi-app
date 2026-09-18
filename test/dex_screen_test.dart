// ============================================================
// [v1] 도감 카드 그림 테스트.
// pipeline: 모바일 클라이언트 / 테스트
// 구현(요약): 끝낸 장소의 도깨비는 그 도깨비 상반신, 기억석 조각은 조각 그림으로 나오는지.
// 구현일: 2026-09-18
// ============================================================
import 'package:dokkaebi_app/game/npc_art.dart';
import 'package:dokkaebi_app/models/scenario.dart';
import 'package:dokkaebi_app/screens/dex_screen.dart';
import 'package:dokkaebi_app/store.dart';
import 'package:dokkaebi_app/widgets/memory_stone_restore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sid = 'dex_art_course';

Map<String, dynamic> _node(String id, String name, {String npc = ''}) => {
      'node_id': id,
      'name': name,
      'kind': 'spot',
      'fragment_id': 'frag_$id',
      'grants': const [],
      'requires': const [],
      'requires_mode': 'none',
      'is_finale': false,
      if (npc.isNotEmpty) 'npc': {'name': npc},
    };

Finder _asset(String path) =>
    find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == path);

Future<void> _pumpDex(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: Scaffold(body: DexScreen())));
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ScenarioStore.I.load();
    await ScenarioStore.I.add(Scenario.fromJson({
      'scenario_id': _sid,
      'title': '경주시의 기억석',
      'region': '경주시',
      'node_sequence': [
        _node('d1', '첨성대', npc: '숯불 도깨비'),
        _node('d2', '불국사', npc: '처마 도깨비'), // 표에 없는 이름
        _node('d3', '석굴암', npc: '탈 도깨비'), // 아직 안 끝낸 장소
      ],
    }));
    await ScenarioStore.I.completeNode(_sid, 'd1', const []);
    await ScenarioStore.I.completeNode(_sid, 'd2', const []);
  });

  tearDown(() => ScenarioStore.I.resetAll());

  testWidgets('도깨비 탭 — 만난 도깨비마다 그 도깨비 그림, 모르는 이름은 기본 도깨비', (tester) async {
    await _pumpDex(tester);

    expect(find.text('2마리 발견'), findsOneWidget);
    expect(_asset(NpcArt.of('숯불 도깨비').bust), findsOneWidget);
    expect(_asset('assets/game/characters/${NpcArt.baseFolder}/bust_idle.webp'), findsOneWidget);
    expect(_asset(NpcArt.of('탈 도깨비').bust), findsNothing, reason: '안 끝낸 장소의 도깨비는 도감에 없다');
    expect(find.byIcon(Icons.local_fire_department), findsNothing, reason: '아이콘 대신 그림');
  });

  testWidgets('기억석 탭 — 모은 조각마다 조각 그림', (tester) async {
    await _pumpDex(tester);
    await tester.tap(find.text('기억석'));
    await tester.pump();

    expect(find.text('2개 수집'), findsOneWidget);
    expect(_asset(kMemoryFragmentAsset), findsNWidgets(2));
    expect(find.byIcon(Icons.diamond_outlined), findsNothing);
  });
}
