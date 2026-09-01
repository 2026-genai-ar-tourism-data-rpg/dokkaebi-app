// ============================================================
// [v1] API 클라이언트 — dokkaebi-server 호출
// pipeline: 모바일 클라이언트 / 네트워크 (앱→서버, 서버가 AI 프록시)
// 구현(요약): 인증·시나리오 생성/검색·분기 대화 + 게임 루프(run·GPS인증·조각·완료).
//            앱은 AI를 직접 호출하지 않는다 ❌ — 전부 게임 서버 경유.
//            서버 오류는 ApiException으로 감싸 code/message로 분기 가능하게 한다.
// 구현일: 2026-06-18 (게임 루프 배선: 2026-08-04) | 작성: kys (app-scaffold/kys/v1)
// ------------------------------------------------------------
// [v2] 마법사 입력 전달 — duration·companion·difficulty·tags·headcount·region.
// 구현(요약): 앱이 보내던 건 transport·wishlist·budget·no_meals 4개뿐이었고 region은
//            '종로' 하드코딩 기본값이었다 → 사용자가 무엇을 골라도, 어디에 있어도 같은
//            종로 코스가 나왔다. region 기본값을 'auto'(서버가 좌표로 판정)로 바꾸고
//            나머지 입력을 계약대로 실어 보낸다. 서버 DTO·AI 스키마와 이름이 1:1이어야
//            한다 — 서버 ValidationPipe가 whitelist라 이름이 다르면 조용히 잘린다.
//            + http.Client 주입 지점 — 지금까지 top-level http.post를 직접 불러서
//              화면 단위 네트워크 목킹이 불가능했다(create_scenario_screen_test 주석 참조).
// 구현일: 2026-08-18 | 작성: kys (explore-input-wiring/kys/v1)
// ============================================================
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/run.dart';
import '../models/scenario.dart';
import '../session.dart';

class ApiClient {
  final String baseUrl;

  /// HTTP 실행기 — 테스트가 MockClient로 갈아끼운다. 기본은 실제 네트워크.
  final http.Client _http;

  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConfig.serverBaseUrl,
        _http = client ?? http.Client();

  /// 공통 헤더(로그인 토큰 포함).
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (Session.token != null) 'Authorization': 'Bearer ${Session.token}',
      };

  /// 게스트 로그인 — 닉네임만으로 토큰 발급받아 세션 저장.
  Future<void> guestLogin(String nickname) async {
    final res = await _http.post(
      Uri.parse('$baseUrl/v1/auth/guest'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nickname': nickname}),
    );
    if (res.statusCode >= 400) {
      throw ApiException.from('로그인', res);
    }
    final d = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    await Session.save(d['token'] as String, d['user_id'] as String, d['nickname'] as String);
  }

  /// 분기 대화 한 턴 — 선택마다 호출. inventory로 연계(이전 단서 인지).
  ///
  /// [branch]는 갈림길 노드의 `node.branch` 그대로. AI는 시나리오를 들고 있지 않아
  /// 이 값을 받아야 갈림길을 인지하고, 종료 선택지를 갈래 id(main|b1)로 낸다.
  /// [regionId]는 grounding 원문 재조회 시 지역 워킹셋 편입에 쓰인다.
  Future<DialogueTurn> dialogueTurn({
    required String nodeId,
    String? nodeName,
    String? fragmentId,
    String? regionId,
    List<Map<String, String>> history = const [],
    List<String> inventory = const [],
    String? lastChoice,
    int turn = 0,
    Map<String, dynamic>? branch,
    Map<String, dynamic>? playerState,
    String? kind,
  }) async {
    final body = {
      'node_id': nodeId,
      if (nodeName != null) 'node_name': nodeName,
      if (fragmentId != null) 'fragment_id': fragmentId,
      if (regionId != null) 'region_id': regionId,
      'history': history,
      'inventory': {'items': inventory},
      if (lastChoice != null) 'last_choice': lastChoice,
      'turn': turn,
      if (branch != null) 'branch': branch,
      if (playerState != null) 'player_state': playerState,
      if (kind != null) 'kind': kind,
    };
    final res = await _http.post(
      Uri.parse('$baseUrl/v1/dialogue/turn'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) {
      throw ApiException.from('대화', res);
    }
    return DialogueTurn.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  /// 관광지 이름 검색 — 앵커 자동완성(부분일치, 정확 title 우선).
  Future<List<SearchCandidate>> searchAttractions(String keyword) async {
    final uri = Uri.parse('$baseUrl/v1/scenarios/search')
        .replace(queryParameters: {'keyword': keyword});
    final res = await _http.get(uri, headers: _headers);
    if (res.statusCode >= 400) {
      throw ApiException.from('검색', res);
    }
    final List data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return data
        .map((e) => SearchCandidate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 내 주변 POI(거리순) — "내 주변 탐험" 탭.
  /// 코스 생성과 달리 LLM을 타지 않아 즉시 응답한다.
  Future<List<NearbyPlace>> nearbyPlaces({
    required double lat,
    required double lng,
    int? radiusM,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/scenarios/nearby').replace(queryParameters: {
      'lat': '$lat',
      'lng': '$lng',
      if (radiusM != null) 'radius_m': '$radiusM',
    });
    final res = await _http.get(uri, headers: _headers);
    if (res.statusCode >= 400) {
      throw ApiException.from('주변 탐색', res);
    }
    final List data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return data
        .map((e) => NearbyPlace.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 시나리오 생성 — 입력 contract(아키텍처 5-6)를 서버에 전달.
  /// start/end는 좌표(앱 GPS/카카오 해석). wishlist는 자동완성 확정분(content_id + 좌표·이름).
  /// ⚠️ 좌표를 반드시 함께 보낸다 — 반경 밖 위시를 서버가 합성 앵커로 배치하려면 필수.
  ///    (좌표 없으면 서버가 배치 불가로 드롭 → 위시가 조용히 무시됨)
  Future<Scenario> generateScenario({
    required double startLat,
    required double startLng,
    double? endLat,
    double? endLng,
    String transport = 'walk',
    List<SearchCandidate> wishlist = const [],
    int? budget,
    bool noMeals = false,
    String region = 'auto',
    String duration = '2h',
    String companion = 'solo',
    String difficulty = 'normal',
    List<String> tags = const [],
    int headcount = 1,
    bool useFixedScript = false,
    bool withDialogue = true,
  }) async {
    final body = <String, dynamic>{
      'user_id': Session.userId ?? 'guest',
      'start': {'lat': startLat, 'lng': startLng},
      if (endLat != null && endLng != null) 'end': {'lat': endLat, 'lng': endLng},
      'transport': transport,
      'wishlist': wishlist
          .map((c) => <String, dynamic>{
                'content_id': c.contentId,
                if (c.name != null) 'name': c.name,
                if (c.lat != null) 'lat': c.lat,
                if (c.lng != null) 'lng': c.lng,
              })
          .toList(),
      if (budget != null) 'budget': budget,
      'headcount': headcount,
      'no_meals': noMeals,
      'region': region,
      'duration': duration,
      'companion': companion,
      'difficulty': difficulty,
      'tags': tags,
      'use_fixed_script': useFixedScript,
      'with_dialogue': withDialogue,
    };
    final res = await _http.post(
      Uri.parse('$baseUrl/v1/scenarios/custom'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) {
      throw ApiException.from('시나리오 생성', res);
    }
    return Scenario.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  // ── 게임 루프 (dokkaebi-server#9) ───────────────────────────────
  // 서버는 run(시나리오 1회 플레이) 단위로 진행도를 관리한다.
  // 흐름: startRun → (노드마다) verifyLocation → collectFragment → completeNode

  /// 플레이 시작 — 시나리오 1회 플레이(run) 생성.
  ///
  /// [nodes]: 노드 정의(좌표·반경·조각). 서버는 시나리오를 저장하지 않는 얇은
  /// 프록시라 GPS 판정에 쓸 좌표를 앱이 함께 보낸다 — 안 보내면 서버가
  /// 판정 근거 없이 관대 모드(무조건 통과)로 돈다.
  Future<QuestRun> startRun(
    String scenarioId, {
    List<Map<String, dynamic>>? nodes,
  }) async {
    final res = await _http.post(
      Uri.parse('$baseUrl/v1/runs'),
      headers: _headers,
      body: jsonEncode({
        'scenario_id': scenarioId,
        if (nodes != null) 'nodes': nodes,
      }),
    );
    if (res.statusCode >= 400) throw ApiException.from('플레이 시작', res);
    return QuestRun.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  /// 진행 상태 조회 — 앱 재시작·복귀 시 진행도 복원.
  Future<QuestRun> getRun(String runId) async {
    final res = await _http.get(Uri.parse('$baseUrl/v1/runs/$runId'), headers: _headers);
    if (res.statusCode >= 400) throw ApiException.from('플레이 조회', res);
    return QuestRun.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  /// GPS 위치 인증 — 노드 반경 안에 있는지 서버가 판정한다.
  ///
  /// [accuracyM]을 반드시 함께 보낸다: 서버가 GPS 오차만큼 반경을 관대하게 잡아 주고,
  /// 오차가 너무 크면 LOW_ACCURACY로 보류한다. 안 보내면 오차 0으로 간주돼
  /// 실제로 도착했는데 튕기는 일이 생긴다.
  ///
  /// 거절(verified=false)은 예외가 아니다 — 정상 응답이고 reason으로 분기한다.
  Future<LocationVerdict> verifyLocation({
    required String runId,
    required String nodeId,
    required double lat,
    required double lng,
    double? accuracyM,
  }) async {
    final res = await _http.post(
      Uri.parse('$baseUrl/v1/runs/$runId/nodes/$nodeId/verify-location'),
      headers: _headers,
      body: jsonEncode({
        'lat': lat,
        'lng': lng,
        if (accuracyM != null) 'accuracy_m': accuracyM,
      }),
    );
    if (res.statusCode >= 400) throw ApiException.from('위치 인증', res);
    return LocationVerdict.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  /// 기억석 조각 획득 — GPS 인증·requires 통과 후에만 성공한다(403이면 아직 이르다).
  Future<CollectResult> collectFragment({
    required String runId,
    required String nodeId,
  }) async {
    final res = await _http.post(
      Uri.parse('$baseUrl/v1/runs/$runId/nodes/$nodeId/collect'),
      headers: _headers,
      body: jsonEncode({}),
    );
    if (res.statusCode >= 400) throw ApiException.from('조각 획득', res);
    return CollectResult.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  /// 노드 완료·보상. [choiceId]는 갈림길에서 고른 갈래(main|b1) — 다음 노드 산출에 쓰인다.
  Future<NodeReward> completeNode({
    required String runId,
    required String nodeId,
    String? choiceId,
  }) async {
    final res = await _http.post(
      Uri.parse('$baseUrl/v1/runs/$runId/nodes/$nodeId/complete'),
      headers: _headers,
      body: jsonEncode({if (choiceId != null) 'choice_id': choiceId}),
    );
    if (res.statusCode >= 400) throw ApiException.from('노드 완료', res);
    return NodeReward.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }
}

/// 서버 오류를 앱이 분기할 수 있는 형태로 감싼다.
///
/// 서버는 {"error":{"code","message"}} 규격으로 내려준다(server#10).
/// 예전처럼 본문 전체를 예외 문구에 박으면 사용자에게 JSON이 그대로 노출된다.
class ApiException implements Exception {
  final String action;   // '시나리오 생성' 등 — 어떤 요청이 실패했는지
  final int statusCode;
  final String code;     // domain_error · upstream_unavailable · rate_limited …
  final String message;  // 사용자에게 보여줄 문구

  ApiException({
    required this.action,
    required this.statusCode,
    required this.code,
    required this.message,
  });

  /// 재시도가 의미 있는 실패인지(외부 장애·혼잡). 입력을 고쳐야 하는 422와 구분.
  bool get isRetryable => statusCode >= 500 || code == 'rate_limited';

  /// 로그인이 풀렸는지 — 재로그인 유도.
  bool get isUnauthorized => statusCode == 401;

  factory ApiException.from(String action, http.Response res) {
    String code = 'unknown';
    String message = '';
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['error'] is Map) {
        code = '${body['error']['code'] ?? 'unknown'}';
        message = '${body['error']['message'] ?? ''}';
      } else if (body is Map && body['message'] != null) {
        // NestJS 기본 예외 형식(401/403/404 등)
        final m = body['message'];
        message = m is List ? m.join(', ') : '$m';
      }
    } catch (_) {
      // 본문이 JSON이 아니면 상태코드만으로 안내한다
    }
    if (message.isEmpty) message = '$action에 실패했습니다 (${res.statusCode}).';
    return ApiException(
        action: action, statusCode: res.statusCode, code: code, message: message);
  }

  @override
  String toString() => message;
}
