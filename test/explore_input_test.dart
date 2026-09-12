// ============================================================
// [v1] 탐험 마법사 입력 배선 테스트 — 고른 것이 요청에 실리는가
// pipeline: 모바일 클라이언트 / 테스트 (입력이 화면에만 남던 회귀 방지)
// 구현(요약): ① ExploreDraft의 한글 라벨 → 서버 코드 매핑(계약이 표시 문구에 안 흔들리게)
//            ② 확인 화면이 실제 GPS 좌표를 start로 보내고, 취향·시간·동행·난이도까지
//              함께 싣는지 — HTTP를 가짜로 받아 body를 열어 본다.
//            ③ 위치 실패 시 폴백 좌표로라도 생성하고 그 사실을 알리는지.
// 구현일: 2026-08-18 | 작성: kys (explore-input-wiring/kys/v1)
// ------------------------------------------------------------
// [v2] 마법사 순서(조건 → 장소)와 검색 결과 반경 필터 — QA 1 회귀 방지.
// 구현(요약): 조건 화면이 1단계인지, 장소 화면이 고른 반경으로 검색 결과를 걸러내는지,
//            반경 밖을 숨기고 개수를 알리는지, 위치를 못 읽으면 필터를 끄고 전체를
//            보여주는지, 검색 8건 한계를 알리는지 확인한다.
// 구현일: 2026-09-12 | 작성: ljs (explore-radius-first/ljs/v1)
// ============================================================
import 'dart:convert';

import 'package:dokkaebi_app/game/location_service.dart';
import 'package:dokkaebi_app/models/explore_draft.dart';
import 'package:dokkaebi_app/screens/explore_conditions_screen.dart';
import 'package:dokkaebi_app/screens/explore_confirm_screen.dart';
import 'package:dokkaebi_app/screens/explore_place_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 서버가 돌려줄 최소 시나리오 — 화면이 다음 단계로 넘어갈 수 있을 만큼만.
const _scenarioJson = {
  'scenario_id': 'scn_test',
  'title': '테스트 코스',
  'region': '강남구',
  'node_sequence': <Map<String, dynamic>>[],
  'stone_total': 0,
};

Position _pos(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 8, 18),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// 좌표를 주는 위치 서비스(실기기 GPS 없이).
LocationService _fixedLocation(double lat, double lng) => LocationService(
      serviceEnabled: () async => true,
      permission: () async => LocationPermission.whileInUse,
      position: () async => _pos(lat, lng),
    );

/// 위치 권한을 거부하는 위치 서비스.
LocationService get _deniedLocation => LocationService(
      serviceEnabled: () async => true,
      permission: () async => LocationPermission.denied,
      position: () async => throw StateError('불릴 일 없음'),
    );

/// 장소 검색만 응답하는 가짜 서버 — 반경 판정은 앱이 하므로 좌표만 실어 준다.
/// 서버 `/v1/scenarios/search`는 후보 배열을 그대로 돌려준다.
http.Client _searchClient(List<Map<String, dynamic>> candidates) => MockClient((req) async {
      if (req.url.path.endsWith('/v1/scenarios/search')) {
        return http.Response(jsonEncode(candidates), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response('{}', 200);
    });

Map<String, dynamic> _cand(String id, String name, double lat, double lng) =>
    {'content_id': id, 'name': name, 'addr': '$name 주소', 'lat': lat, 'lng': lng};

/// 강남역 — 반경 판정의 기준점으로 쓴다.
const _gangnamLat = 37.4979, _gangnamLng = 127.0276;

/// 강남역에서 약 400m(반경 1km 안).
Map<String, dynamic> _near(String id) => _cand(id, '가까운 곳', 37.5015, _gangnamLng);

/// 종로 — 강남역에서 약 8km(반경 1km 밖).
Map<String, dynamic> _far(String id, [String name = '먼 곳']) =>
    _cand(id, name, 37.5703, 126.9856);

/// 장소 화면을 띄우고 검색어를 넣어 결과가 그려질 때까지 진행한다.
/// 검색 스피너가 계속 돌아 pumpAndSettle은 못 쓴다 — 디바운스(400ms)와 응답을 따로 펌프한다.
Future<void> _searchOn(
  WidgetTester tester, {
  required List<Map<String, dynamic>> candidates,
  required LocationService location,
  int radiusKm = 1,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: ExplorePlaceScreen(
      draft: ExploreDraft()..radiusKm = radiusKm,
      locationService: location,
      httpClient: _searchClient(candidates),
    ),
  ));
  await tester.pump(); // 기준점(현재 위치) 읽기 완료
  await tester.enterText(find.byType(TextField), '곳');
  await tester.pump(const Duration(milliseconds: 450)); // 디바운스 경과 → 검색 시작
  await tester.pump(); // 검색 응답 반영
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ExploreDraft 매핑', () {
    test('한글 라벨이 서버 코드로 바뀐다', () {
      final d = ExploreDraft()
        ..duration = '반나절'
        ..companion = '가족'
        ..difficulty = '어려움';
      expect(d.durationCode, 'half');
      expect(d.companionCode, 'family');
      expect(d.difficultyCode, 'hard');
      expect(d.headcount, 4, reason: '식음 예산이 1인 기준이라 인원수가 틀리면 밴드가 4배로 어긋난다');
    });

    test('기본값은 혼자·2시간·보통', () {
      final d = ExploreDraft();
      expect(d.durationCode, '2h');
      expect(d.companionCode, 'solo');
      expect(d.difficultyCode, 'normal');
      expect(d.headcount, 1);
      expect(d.region, 'auto', reason: '지역을 고정하면 어디서 만들어도 같은 코스가 나온다');
    });

    test('취향 태그는 라벨 그대로 실린다', () {
      final d = ExploreDraft()..tags.addAll({'고궁', '카페'});
      expect(d.tagList..sort(), ['고궁', '카페']);
    });
  });

  group('확인 화면 → 생성 요청', () {
    testWidgets('현재 위치와 마법사 입력이 요청에 실린다', (tester) async {
      Map<String, dynamic>? sent;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/v1/scenarios/custom')) {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(_scenarioJson), 201,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('{}', 200);
      });

      final draft = ExploreDraft()
        ..duration = '하루'
        ..companion = '연인'
        ..difficulty = '쉬움'
        ..transportLabel = '대중교통'
        ..includeMeals = false
        ..budget = 50000
        ..tags.addAll({'한옥'});

      await tester.pumpWidget(MaterialApp(
        home: ExploreConfirmScreen(
          draft: draft,
          locationService: _fixedLocation(37.4979, 127.0276),   // 강남역
          httpClient: client,
        ),
      ));
      await tester.tap(find.text('나만의 코스 만들기'));
      await tester.pumpAndSettle();

      expect(sent, isNotNull, reason: '생성 요청이 아예 안 나갔다');
      expect(sent!['start'], {'lat': 37.4979, 'lng': 127.0276},
          reason: '종로 하드코딩 좌표가 아니라 실제 위치를 보내야 한다');
      expect(sent!['region'], 'auto');
      expect(sent!['duration'], 'full');
      expect(sent!['companion'], 'couple');
      expect(sent!['difficulty'], 'easy');
      expect(sent!['tags'], ['한옥']);
      expect(sent!['headcount'], 2);
      expect(sent!['transport'], 'car');
      expect(sent!['no_meals'], true);
      expect(sent!['budget'], 50000);
      expect(sent!['use_fixed_script'], false,
          reason: '마법사로 만든 코스는 정답지 재생이 아니라 입력을 반영한 생성이어야 한다');
      expect(sent!.containsKey('end'), isFalse,
          reason: '종로 고정 도착점을 보내면 다른 지역에서 피날레가 엉뚱한 곳에 잡힌다');
    });

    testWidgets('위치를 못 얻으면 폴백 좌표로 만들고 알린다', (tester) async {
      Map<String, dynamic>? sent;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/v1/scenarios/custom')) {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(_scenarioJson), 201,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('{}', 200);
      });

      await tester.pumpWidget(MaterialApp(
        home: ExploreConfirmScreen(
          draft: ExploreDraft(),
          locationService: _deniedLocation,
          httpClient: client,
        ),
      ));
      await tester.tap(find.text('나만의 코스 만들기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(sent, isNotNull, reason: '위치를 못 얻었다고 생성 자체가 막히면 안 된다');
      expect(sent!['start'], {'lat': 37.5703, 'lng': 126.9856});
      expect(find.textContaining('위치 권한'), findsOneWidget,
          reason: '왜 종로 코스가 나왔는지 사용자가 알 수 있어야 한다');
    });
  });

  // QA 1 — 반경을 먼저 고르고 그 반경 안에서 장소를 고른다.
  group('마법사 순서와 반경 필터', () {
    testWidgets('조건 화면이 1단계 — 다음을 누르면 장소 화면으로 간다', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExploreConditionsScreen()));

      expect(find.text('여행 조건'), findsOneWidget);
      expect(find.text('STEP 1 / 3'), findsOneWidget);

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      expect(find.text('가고 싶은 장소'), findsOneWidget,
          reason: '반경을 고른 다음에 장소를 골라야 반경이 검색에 걸린다');
      expect(find.text('STEP 2 / 3'), findsOneWidget);
    });

    testWidgets('반경 밖 후보는 목록에서 빠지고 숨긴 개수를 알린다', (tester) async {
      await _searchOn(tester,
          candidates: [_near('1'), _far('2')],
          location: _fixedLocation(_gangnamLat, _gangnamLng));

      expect(find.text('가까운 곳'), findsOneWidget);
      expect(find.text('먼 곳'), findsNothing,
          reason: '반경 밖을 고를 수 있으면 반경을 먼저 고른 의미가 없다');
      expect(find.textContaining('반경 밖 1건은 숨겼어요'), findsOneWidget);
    });

    testWidgets('반경 안만 있으면 숨김 안내 없이 그대로 보여준다', (tester) async {
      await _searchOn(tester,
          candidates: [_near('1')], location: _fixedLocation(_gangnamLat, _gangnamLng));

      expect(find.text('가까운 곳'), findsOneWidget);
      expect(find.textContaining('숨겼어요'), findsNothing);
      expect(find.textContaining('반경 1km 안의 장소만'), findsOneWidget);
    });

    testWidgets('위치를 못 읽으면 필터를 끄고 전체를 보여주며 사유를 알린다', (tester) async {
      await _searchOn(tester,
          candidates: [_near('1'), _far('2')], location: _deniedLocation);

      expect(find.textContaining('전체 결과를 보여줘요'), findsOneWidget);
      expect(find.text('가까운 곳'), findsOneWidget);
      expect(find.text('먼 곳'), findsOneWidget,
          reason: '기준점이 없으면 반경을 판정할 수 없어 걸러내면 안 된다');
      expect(find.textContaining('숨겼어요'), findsNothing);
    });

    testWidgets('좌표 없는 후보는 반경을 판정할 수 없어 남긴다', (tester) async {
      await _searchOn(tester,
          candidates: [
            _near('1'),
            {'content_id': '2', 'name': '좌표 없는 곳', 'addr': '주소'},
          ],
          location: _fixedLocation(_gangnamLat, _gangnamLng));

      expect(find.text('좌표 없는 곳'), findsOneWidget,
          reason: '판정 불가를 숨기면 고를 길이 아예 사라진다');
      expect(find.textContaining('숨겼어요'), findsNothing);
    });

    testWidgets('검색이 8건을 다 채운 채 반경 밖을 걸렀으면 검색 한계를 알린다', (tester) async {
      await _searchOn(tester,
          candidates: [
            _near('in'),
            for (var i = 0; i < 7; i++) _far('out$i', '먼 곳 $i'),
          ],
          location: _fixedLocation(_gangnamLat, _gangnamLng));

      expect(find.textContaining('반경 안 장소가 더 있을 수 있어요'), findsOneWidget,
          reason: '서버가 top_n을 노출하지 않아 앱 필터로는 8건 안에서만 걸러진다');
    });
  });
}
