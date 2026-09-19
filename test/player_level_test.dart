// ============================================================
// [v1] 레벨(굿 엔딩 코스 수 기준) — 응답 모델·세션 조회·프로필 표시 테스트.
// pipeline: 모바일 클라이언트 / 테스트
// 구현(요약): NodeReward·PlayerLevel 파싱(옛 서버 호환), RunSession.myLevel은 로그인 전·실패면 null,
//            프로필은 'Lv.N · 등급'과 '다음 레벨까지 굿 엔딩 M번'을 보여 주고 못 읽으면 숨긴다.
// 구현일: 2026-09-19
// ============================================================
import 'dart:convert';

import 'package:dokkaebi_app/api/api_client.dart';
import 'package:dokkaebi_app/game/run_session.dart';
import 'package:dokkaebi_app/models/run.dart';
import 'package:dokkaebi_app/screens/profile_screen.dart';
import 'package:dokkaebi_app/session.dart';
import 'package:dokkaebi_app/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _me = {'level': 2, 'tier': '초급 탐사자', 'good_endings': 1, 'next_level_at': 3};

RunSession _session(Future<http.Response> Function(http.Request) handler) =>
    RunSession(api: ApiClient(baseUrl: 'http://test', client: MockClient(handler)));

Future<http.Response> _meOk(http.Request req) async => http.Response(jsonEncode(_me), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ScenarioStore.I.load();
  });

  tearDown(() => Session.token = null);

  group('응답 모델', () {
    test('완료 응답의 레벨·레벨업과 내 레벨을 읽는다', () {
      final r = NodeReward.fromJson({'state': 'REWARDED', 'level': 3, 'tier': '중급 탐사자', 'level_up': true});
      expect([r.level, r.tier, r.levelUp], [3, '중급 탐사자', true]);

      final lv = PlayerLevel.fromJson(_me);
      expect([lv.level, lv.tier, lv.goodEndings, lv.nextLevelAt, lv.toNextLevel], [2, '초급 탐사자', 1, 3, 2]);
    });

    test('레벨이 없는 옛 서버 응답이면 레벨은 비고 레벨업도 아니다', () {
      final r = NodeReward.fromJson({'state': 'REWARDED'});
      expect(r.level, isNull);
      expect(r.levelUp, isFalse);
      expect(PlayerLevel.fromJson({}).level, 1);
    });
  });

  group('RunSession.myLevel', () {
    test('로그인했으면 서버 레벨을 읽는다', () async {
      Session.token = 't';
      final lv = await _session(_meOk).myLevel();
      expect(lv?.level, 2);
    });

    test('로그인 전이면 묻지 않고, 서버가 실패하면 null', () async {
      var asked = 0;
      final s = _session((req) async {
        asked++;
        return http.Response('error', 500);
      });
      expect(await s.myLevel(), isNull);
      expect(asked, 0, reason: '로그인 전엔 서버에 묻지 않는다');

      Session.token = 't';
      expect(await s.myLevel(), isNull);
      expect(asked, 1);
      expect(s.error, isNull, reason: '레벨 조회 실패는 플레이 오류로 남기지 않는다');
    });
  });

  group('프로필', () {
    testWidgets('레벨·등급과 다음 레벨까지 남은 굿 엔딩을 보여 준다', (tester) async {
      Session.token = 't';
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProfileScreen(runSession: _session(_meOk)))));
      await tester.pump();

      expect(find.text('Lv.2 · 초급 탐사자'), findsOneWidget);
      expect(find.text('다음 레벨까지 굿 엔딩 2번'), findsOneWidget);
    });

    testWidgets('레벨을 못 읽으면 레벨 줄을 숨긴다', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProfileScreen(runSession: _session(_meOk)))));
      await tester.pump();

      expect(find.textContaining('Lv.'), findsNothing);
      expect(find.textContaining('다음 레벨까지'), findsNothing);
    });
  });
}
