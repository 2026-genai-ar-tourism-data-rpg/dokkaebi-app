// ============================================================
// [v1] 위치 인증 화면 테스트 — GPS 실패·서버 거절 분기
// pipeline: 모바일 클라이언트 / 테스트 (실기기·서버 없이 화면 분기 검증)
// 구현(요약): LocationService를 주입해 권한 거부·신호 없음을 흉내내고,
//            화면이 사유별 안내와 다음 행동(설정 열기/다시 확인)을 내는지 본다.
//            v1 화면은 1.8초 뒤 무조건 성공 pop이라 검증할 게 없었다.
// 구현일: 2026-08-04 | 작성: kys (game-loop-ui/kys/v1)
// ============================================================
import 'package:dokkaebi_app/game/location_service.dart';
import 'package:dokkaebi_app/screens/location_verify_screen.dart';
import 'package:dokkaebi_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

/// 항상 같은 결과를 내는 위치 서비스 — 화면 분기만 보기 위한 스텁.
class _StubLocation extends LocationService {
  final LocationResult result;
  final bool throwOnSettings;
  const _StubLocation(this.result, {this.throwOnSettings = false});

  @override
  Future<LocationResult> current({Duration timeout = const Duration(seconds: 15)}) async =>
      result;

  @override
  Future<void> openSettings() async {
    if (throwOnSettings) throw Exception('설정 열기 실패');
  }
}

Future<void> _pump(WidgetTester tester, LocationService service) async {
  await tester.pumpWidget(MaterialApp(
    theme: buildDokkaebiTheme(),
    // nodeId 없음 = 서버를 타지 않는 경로 — GPS 단계 분기만 검증한다.
    home: LocationVerifyScreen(placeName: '경복궁', locationService: service),
  ));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('위치 서비스가 꺼져 있으면 설정 열기를 제안한다', (tester) async {
    await _pump(tester, const _StubLocation(
        LocationResult.fail(LocationFailure.serviceDisabled)));

    expect(find.textContaining('위치 서비스가 꺼져'), findsOneWidget);
    expect(find.text('설정 열기'), findsOneWidget);
    expect(find.text('다시 확인'), findsOneWidget);
  });

  testWidgets('영구 거부도 설정 열기로 안내한다 — 다시 요청해봐야 안 뜬다', (tester) async {
    await _pump(tester, const _StubLocation(
        LocationResult.fail(LocationFailure.deniedForever)));

    expect(find.textContaining('앱 설정에서 허용'), findsOneWidget);
    expect(find.text('설정 열기'), findsOneWidget);
  });

  testWidgets('이번만 거부면 설정 대신 재시도만 제안한다', (tester) async {
    await _pump(tester, const _StubLocation(
        LocationResult.fail(LocationFailure.denied)));

    expect(find.text('설정 열기'), findsNothing, reason: '아직 설정까지 보낼 단계가 아니다');
    expect(find.text('다시 확인'), findsOneWidget);
  });

  testWidgets('신호를 못 잡으면 트인 곳으로 나가라고 안내한다', (tester) async {
    await _pump(tester, const _StubLocation(
        LocationResult.fail(LocationFailure.timeout)));

    expect(find.textContaining('하늘이 트인 곳'), findsOneWidget);
  });

  testWidgets('[회귀] 실패해도 화면에 갇히지 않는다 — 뒤로가기가 있다', (tester) async {
    await _pump(tester, const _StubLocation(
        LocationResult.fail(LocationFailure.deniedForever)));

    expect(find.byIcon(Icons.arrow_back), findsOneWidget,
        reason: '실패 화면에서 빠져나갈 방법이 없으면 앱을 껐다 켜야 한다');
  });

  testWidgets('좌표를 얻으면(서버 판정 없음) 성공으로 닫힌다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildDokkaebiTheme(),
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const LocationVerifyScreen(
                placeName: '경복궁',
                locationService: _StubLocation(
                    LocationResult.ok(37.5796, 126.977, 8.0)),
              ),
            ),
          ),
          child: const Text('열기'),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('위치 확인 완료!'), findsOneWidget);

    // 연출 후 자동으로 닫힌다
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.text('열기'), findsOneWidget, reason: '성공 후 이전 화면으로 돌아와야 한다');
  });

  group('LocationResult', () {
    test('설정으로 보내야 하는 실패만 needsSettings', () {
      expect(
          const LocationResult.fail(LocationFailure.deniedForever).needsSettings, isTrue);
      expect(
          const LocationResult.fail(LocationFailure.serviceDisabled).needsSettings, isTrue);
      expect(const LocationResult.fail(LocationFailure.denied).needsSettings, isFalse);
      expect(const LocationResult.fail(LocationFailure.timeout).needsSettings, isFalse);
    });

    test('성공이면 좌표와 정확도가 담긴다', () {
      const r = LocationResult.ok(37.5796, 126.977, 12.5);
      expect(r.isOk, isTrue);
      expect(r.accuracyM, 12.5, reason: '정확도를 서버에 보내야 반경이 보정된다');
      expect(r.message, isEmpty);
    });
  });

  group('LocationService 권한 분기', () {
    test('서비스가 꺼져 있으면 권한을 묻지도 않는다', () async {
      var permissionAsked = false;
      final svc = LocationService(
        serviceEnabled: () async => false,
        permission: () async {
          permissionAsked = true;
          return LocationPermission.always;
        },
      );
      final r = await svc.current();
      expect(r.failure, LocationFailure.serviceDisabled);
      expect(permissionAsked, isFalse, reason: '켜지도 않았는데 권한 팝업을 띄우면 안 된다');
    });

    test('영구 거부는 denied와 구분된다', () async {
      final svc = LocationService(
        serviceEnabled: () async => true,
        permission: () async => LocationPermission.deniedForever,
      );
      expect((await svc.current()).failure, LocationFailure.deniedForever);
    });

    test('좌표 획득이 예외를 던지면 timeout으로 본다', () async {
      final svc = LocationService(
        serviceEnabled: () async => true,
        permission: () async => LocationPermission.whileInUse,
        position: () async => throw Exception('신호 없음'),
      );
      expect((await svc.current()).failure, LocationFailure.timeout);
    });
  });
}
