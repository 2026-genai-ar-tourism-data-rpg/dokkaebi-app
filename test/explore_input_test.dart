// ============================================================
// [v1] 탐험 마법사 입력 배선 테스트 — 고른 것이 요청에 실리는가
// pipeline: 모바일 클라이언트 / 테스트 (입력이 화면에만 남던 회귀 방지)
// 구현(요약): ① ExploreDraft의 한글 라벨 → 서버 코드 매핑(계약이 표시 문구에 안 흔들리게)
//            ② 확인 화면이 실제 GPS 좌표를 start로 보내고, 취향·시간·동행·난이도까지
//              함께 싣는지 — HTTP를 가짜로 받아 body를 열어 본다.
//            ③ 위치 실패 시 폴백 좌표로라도 생성하고 그 사실을 알리는지.
// 구현일: 2026-08-18 | 작성: kys (explore-input-wiring/kys/v1)
// ============================================================
import 'dart:convert';

import 'package:dokkaebi_app/game/location_service.dart';
import 'package:dokkaebi_app/models/explore_draft.dart';
import 'package:dokkaebi_app/screens/explore_confirm_screen.dart';
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
}
