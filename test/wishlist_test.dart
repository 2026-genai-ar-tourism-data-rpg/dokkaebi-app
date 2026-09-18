// ============================================================
// [v1] 위시리스트 — 주변 탐험 +로 담기 → 퀘스트 탭 위시리스트에서 골라 바로 코스 생성,
//      코스 만들기 마법사 '위시 리스트'와 연동.
// pipeline: 모바일 클라이언트 / 테스트
// 구현(요약): 모델(content_id 꺼내기)·저장소(담기·빼기·상한·영속)·반경 계산 + 화면 흐름
//            (주변 탐험 + → 위시리스트 탭 → 코스 생성 요청 본문, 마법사에서 고르기·반경 밖·검색 분리).
// 구현일: 2026-09-19
// ============================================================
import 'dart:convert';

import 'package:dokkaebi_app/game/location_service.dart';
import 'package:dokkaebi_app/models/explore_draft.dart';
import 'package:dokkaebi_app/models/scenario.dart';
import 'package:dokkaebi_app/screens/explore_confirm_screen.dart';
import 'package:dokkaebi_app/screens/explore_place_screen.dart';
import 'package:dokkaebi_app/screens/quest_tab_screen.dart';
import 'package:dokkaebi_app/store.dart';
import 'package:dokkaebi_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubLocation extends LocationService {
  const _StubLocation(this.result);
  final LocationResult result;

  @override
  Future<LocationResult> current({Duration timeout = const Duration(seconds: 15)}) async => result;

  @override
  Future<LocationFailure?> checkAccess() async => null;
}

const _here = _StubLocation(LocationResult.ok(37.57, 126.98, 5.0));

SearchCandidate _wish(String id, {double lat = 37.571, double lng = 126.981}) =>
    SearchCandidate(contentId: id, name: '장소$id', addr: '주소$id', lat: lat, lng: lng);

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ScenarioStore.I.load();
  });

  group('주변 장소 → 위시 항목', () {
    test('tour_ 노드는 content_id를 꺼내 위시 항목이 된다', () {
      const p = NearbyPlace(nodeId: 'tour_126508', name: '경복궁', addr: '종로구', lat: 37.5, lng: 126.9);
      expect(p.contentId, '126508');
      final w = p.toWish()!;
      expect([w.contentId, w.name, w.addr, w.lat, w.lng], ['126508', '경복궁', '종로구', 37.5, 126.9]);
    });

    test('관광공사 ID가 없는 장소는 담을 수 없다', () {
      expect(const NearbyPlace(nodeId: 'osm_node_1').toWish(), isNull);
      expect(const NearbyPlace(nodeId: 'tour_').contentId, isNull);
    });
  });

  group('위시리스트 저장소', () {
    test('담기·빼기, 같은 장소는 한 번만, 앱을 다시 켜도 남는다', () async {
      expect(await ScenarioStore.I.addWish(_wish('1')), isTrue);
      expect(await ScenarioStore.I.addWish(_wish('1')), isTrue);
      await ScenarioStore.I.addWish(_wish('2'));
      expect(ScenarioStore.I.wishlist.map((c) => c.contentId), ['1', '2']);

      await ScenarioStore.I.load(); // 다시 읽기
      expect(ScenarioStore.I.isWished('2'), isTrue);
      expect(ScenarioStore.I.wishlist.first.name, '장소1');

      await ScenarioStore.I.removeWish('1');
      expect(ScenarioStore.I.wishlist.map((c) => c.contentId), ['2']);
    });

    test('최대 개수를 넘으면 담지 않는다', () async {
      for (var i = 0; i < ScenarioStore.wishlistMax; i++) {
        expect(await ScenarioStore.I.addWish(_wish('$i')), isTrue);
      }
      expect(await ScenarioStore.I.addWish(_wish('over')), isFalse);
      expect(ScenarioStore.I.wishlist, hasLength(ScenarioStore.wishlistMax));
    });
  });

  group('바로 만드는 코스의 반경', () {
    test('가장 먼 장소까지 올리고, 가까우면 기본 반경', () {
      // 경도 0.07° ≈ 6.2km(위도 37.57)
      expect(wishCourseRadiusKm(37.57, 126.98, [_wish('a'), _wish('b', lng: 127.05)]), 7);
      expect(wishCourseRadiusKm(37.57, 126.98, [_wish('a')]), ExploreDraft().radiusKm);
    });

    test('위치를 모르거나 좌표 없는 장소가 있거나 너무 멀면 최대 10km', () {
      expect(wishCourseRadiusKm(null, null, [_wish('a')]), 10);
      expect(wishCourseRadiusKm(37.57, 126.98, [SearchCandidate(contentId: 'x')]), 10);
      expect(wishCourseRadiusKm(37.57, 126.98, [_wish('far', lng: 127.3)]), 10);
    });
  });

  group('퀘스트 탭', () {
    testWidgets('주변 탐험 + → 위시리스트 탭에서 골라 코스 생성하면 그 장소로 바로 생성을 요청한다', (tester) async {
      Map<String, dynamic>? created;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/v1/scenarios/nearby')) {
          return _json([
            {'node_id': 'tour_101', 'name': '명락사', 'addr': '관악구', 'lat': 37.57, 'lng': 127.05, 'dist_m': 6200,
             'category': 'attraction'},
            {'node_id': 'osm_9', 'name': '이름없는 비석', 'lat': 37.571, 'lng': 126.981, 'dist_m': 120,
             'category': 'historic'},
          ]);
        }
        if (req.url.path.endsWith('/v1/scenarios/custom')) {
          created = jsonDecode(req.body) as Map<String, dynamic>;
          return _json({'detail': 'test'}, 500);
        }
        return _json({}, 404);
      });

      // 실제 앱 테마로 — 테마의 버튼 최소 크기가 '가로 꽉 참'이라 한 줄 배치가 깨지던 걸 잡는다.
      await tester.pumpWidget(MaterialApp(
          theme: buildDokkaebiTheme(),
          home: Scaffold(body: QuestTabScreen(locationService: _here, httpClient: client))));
      await tester.tap(find.text('내 주변 탐험'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('wish-osm_9')), findsNothing, reason: '관광공사 ID 없는 곳은 + 없음');
      await tester.tap(find.byKey(const ValueKey('wish-tour_101')));
      await tester.pumpAndSettle();
      expect(ScenarioStore.I.isWished('101'), isTrue);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.tap(find.text('위시리스트'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '코스 생성 버튼 배치가 깨지면 안 된다');
      expect(find.text('명락사'), findsOneWidget);
      final button = find.widgetWithText(FilledButton, '코스 생성');
      expect(tester.widget<FilledButton>(button).onPressed, isNull, reason: '고르기 전엔 못 누른다');

      await tester.tap(find.byKey(const ValueKey('wish-pick-101')));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '코스 생성 1'));
      await tester.pumpAndSettle();

      expect(created, isNotNull, reason: '누르자마자 생성을 요청한다');
      expect((created!['wishlist'] as List).map((w) => w['content_id']), ['101']);
      expect(created!['radius_m'], 7000, reason: '고른 장소(6.2km)가 들어오게');
      expect(created!['duration'], '2h');
      expect(created!['wishlist_only'], isTrue, reason: '고른 장소로만 — 다른 장소로 채우지 않는다');
      expect(ScenarioStore.I.isWished('101'), isTrue, reason: '만들어도 위시리스트는 남는다');
    });

    testWidgets('코스 하나엔 5곳까지만 고를 수 있다', (tester) async {
      for (var i = 0; i < 6; i++) {
        await ScenarioStore.I.addWish(_wish('$i'));
      }
      await tester.pumpWidget(MaterialApp(
          theme: buildDokkaebiTheme(),
          home: Scaffold(body: QuestTabScreen(locationService: _here, httpClient: MockClient((_) async => _json([]))))));
      await tester.tap(find.text('위시리스트'));
      await tester.pumpAndSettle();

      for (var i = 0; i < 6; i++) {
        await tester.ensureVisible(find.byKey(ValueKey('wish-pick-$i')));
        await tester.tap(find.byKey(ValueKey('wish-pick-$i')));
        await tester.pump();
      }
      expect(find.text('코스 하나엔 최대 5곳까지 고를 수 있어요.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '코스 생성 5'), findsOneWidget);
    });
  });

  testWidgets('마법사로 만들 땐 wishlist_only를 보내지 않는다 — 위시 장소에 다른 장소를 더해도 된다', (tester) async {
    Map<String, dynamic>? created;
    final client = MockClient((req) async {
      created = jsonDecode(req.body) as Map<String, dynamic>;
      return _json({'detail': 'test'}, 500);
    });
    final draft = ExploreDraft()..places.add(_wish('101'));
    await tester.pumpWidget(MaterialApp(
        home: ExploreConfirmScreen(draft: draft, locationService: _here, httpClient: client, autoGenerate: true)));
    await tester.pumpAndSettle();

    expect((created!['wishlist'] as List).map((w) => w['content_id']), ['101']);
    expect(created!.containsKey('wishlist_only'), isFalse);
  });

  group('코스 만들기 마법사 — 위시 리스트', () {
    testWidgets('위시리스트 장소를 골라 넣고, 반경 밖은 못 고르고, 검색으로 담은 건 위시리스트에 안 남는다', (tester) async {
      await ScenarioStore.I.addWish(_wish('201')); // 150m
      await ScenarioStore.I.addWish(_wish('202', lng: 127.10)); // 약 10.6km — 3km 반경 밖
      final draft = ExploreDraft()..radiusKm = 3;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/v1/scenarios/search')) {
          return _json([
            {'content_id': '301', 'name': '검색한 곳', 'addr': '근처', 'lat': 37.572, 'lng': 126.982},
          ]);
        }
        return _json({}, 404);
      });
      await tester.pumpWidget(MaterialApp(
          home: ExplorePlaceScreen(draft: draft, locationService: _here, httpClient: client)));
      await tester.pumpAndSettle();

      expect(find.text('위시 리스트'), findsOneWidget);
      expect(find.text('선택한 장소'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('wizard-wish-201')));
      await tester.pump();
      expect(draft.places.map((c) => c.contentId), ['201']);

      expect(find.text('장소202 · 반경 밖'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('wizard-wish-202')));
      await tester.pump();
      expect(draft.places.map((c) => c.contentId), ['201'], reason: '반경 밖은 못 고른다');

      await tester.enterText(find.byType(TextField).first, '검색');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('검색한 곳'));
      await tester.pumpAndSettle();
      expect(draft.places.map((c) => c.contentId), ['201', '301']);
      expect(ScenarioStore.I.isWished('301'), isFalse, reason: '검색으로 담은 건 이번 코스에만');
    });
  });
}
