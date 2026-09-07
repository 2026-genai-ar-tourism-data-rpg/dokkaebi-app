// ============================================================
// [v1] 세션 — 로그인 토큰·유저 보관(영속)
// pipeline: 모바일 클라이언트 / 인증 상태
// 구현(요약): token·userId·nickname을 메모리+SharedPreferences에 저장/복원.
//            요청 시 ApiClient가 token을 Authorization 헤더로 사용.
// 구현일: 2026-06-18 | 작성: kys (auth-guest/kys/v1)
// ------------------------------------------------------------
// [v2] 토큰에 발급 서버 주소를 같이 저장 — 다른 서버 토큰은 복원하지 않는다.
// 구현(요약): SERVER_BASE_URL을 LAN 개발 서버↔프로덕션으로 바꿔 실행하면 이전 서버가
//            서명한 토큰이 그대로 살아남아 보호 API마다 401("유효한 토큰이 필요하느니라")이
//            났다. 저장 시 server_url을 함께 기록하고, 복원 시 지금 주소와 다르면(또는
//            기록이 없는 구버전 토큰이면) 버려서 로그인 화면부터 다시 타게 한다.
// 구현일: 2026-09-04 | 작성: kys (dev 직접 반영 — 팀 실기기 테스트 중 401 막힘)
// ============================================================
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

class Session {
  static String? token;
  static String? userId;
  static String? nickname;

  static bool get isLoggedIn => token != null && token!.isNotEmpty;

  /// 앱 시작 시 저장된 세션 복원. 지금 붙는 서버가 발급한 토큰만 인정한다.
  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final savedUrl = p.getString('server_url');
    if (p.getString('token') != null && savedUrl != AppConfig.serverBaseUrl) {
      // 다른 서버(또는 주소 기록이 없는 구버전) 토큰 — 서명이 안 맞아 401만 난다.
      await clear();
      return;
    }
    token = p.getString('token');
    userId = p.getString('user_id');
    nickname = p.getString('nickname');
  }

  /// 로그인 성공 시 저장.
  static Future<void> save(String t, String uid, String nick) async {
    token = t;
    userId = uid;
    nickname = nick;
    final p = await SharedPreferences.getInstance();
    await p.setString('token', t);
    await p.setString('user_id', uid);
    await p.setString('nickname', nick);
    await p.setString('server_url', AppConfig.serverBaseUrl);
  }

  /// 로그아웃.
  static Future<void> clear() async {
    token = null;
    userId = null;
    nickname = null;
    await (await SharedPreferences.getInstance()).clear();
  }
}
