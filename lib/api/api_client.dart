// ============================================================
// [v1] API 클라이언트 — dokkaebi-server 호출
// pipeline: 모바일 클라이언트 / 네트워크 (앱→서버, 서버가 AI 프록시)
// 구현(요약): POST /v1/scenarios/custom (입력 contract → 시나리오). 앱은 AI 직접 호출 ❌.
// 구현일: 2026-06-18 | 작성: kys (app-scaffold/kys/v1)
// ============================================================
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/scenario.dart';
import '../session.dart';

class ApiClient {
  final String baseUrl;
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.serverBaseUrl;

  /// 공통 헤더(로그인 토큰 포함).
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (Session.token != null) 'Authorization': 'Bearer ${Session.token}',
      };

  /// 게스트 로그인 — 닉네임만으로 토큰 발급받아 세션 저장.
  Future<void> guestLogin(String nickname) async {
    final res = await http.post(
      Uri.parse('$baseUrl/v1/auth/guest'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nickname': nickname}),
    );
    if (res.statusCode >= 400) {
      throw Exception('로그인 실패 (${res.statusCode}): ${res.body}');
    }
    final d = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    await Session.save(d['token'] as String, d['user_id'] as String, d['nickname'] as String);
  }

  /// 분기 대화 한 턴 — 선택마다 호출. inventory로 연계(이전 단서 인지).
  Future<DialogueTurn> dialogueTurn({
    required String nodeId,
    String? nodeName,
    String? fragmentId,
    List<Map<String, String>> history = const [],
    List<String> inventory = const [],
    String? lastChoice,
    int turn = 0,
  }) async {
    final body = {
      'node_id': nodeId,
      if (nodeName != null) 'node_name': nodeName,
      if (fragmentId != null) 'fragment_id': fragmentId,
      'history': history,
      'inventory': {'items': inventory},
      if (lastChoice != null) 'last_choice': lastChoice,
      'turn': turn,
    };
    final res = await http.post(
      Uri.parse('$baseUrl/v1/dialogue/turn'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) {
      throw Exception('대화 실패 (${res.statusCode}): ${res.body}');
    }
    return DialogueTurn.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  /// 관광지 이름 검색 — 앵커 자동완성(부분일치, 정확 title 우선).
  Future<List<SearchCandidate>> searchAttractions(String keyword) async {
    final uri = Uri.parse('$baseUrl/v1/scenarios/search')
        .replace(queryParameters: {'keyword': keyword});
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode >= 400) {
      throw Exception('검색 실패 (${res.statusCode}): ${res.body}');
    }
    final List data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return data
        .map((e) => SearchCandidate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 시나리오 생성 — 입력 contract(아키텍처 5-6)를 서버에 전달.
  /// start/end는 좌표(앱 GPS/카카오 해석). wishlist는 content_id(자동완성 확정분).
  Future<Scenario> generateScenario({
    required double startLat,
    required double startLng,
    double? endLat,
    double? endLng,
    String transport = 'walk',
    List<String> wishlistContentIds = const [],
    int? budget,
    String region = '종로',
    bool withDialogue = true,
  }) async {
    final body = <String, dynamic>{
      'user_id': Session.userId ?? 'guest',
      'start': {'lat': startLat, 'lng': startLng},
      if (endLat != null && endLng != null) 'end': {'lat': endLat, 'lng': endLng},
      'transport': transport,
      'wishlist': wishlistContentIds.map((c) => {'content_id': c}).toList(),
      if (budget != null) 'budget': budget,
      'region': region,
      'with_dialogue': withDialogue,
    };
    final res = await http.post(
      Uri.parse('$baseUrl/v1/scenarios/custom'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) {
      throw Exception('시나리오 생성 실패 (${res.statusCode}): ${res.body}');
    }
    return Scenario.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }
}
