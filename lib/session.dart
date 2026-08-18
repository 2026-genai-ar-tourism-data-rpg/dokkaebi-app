// ============================================================
// [v1] 세션 — 로그인 토큰·유저 보관(영속)
// pipeline: 모바일 클라이언트 / 인증 상태
// 구현(요약): token·userId·nickname을 메모리+SharedPreferences에 저장/복원.
//            요청 시 ApiClient가 token을 Authorization 헤더로 사용.
// 구현일: 2026-06-18 | 작성: kys (auth-guest/kys/v1)
// ============================================================
import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static String? token;
  static String? userId;
  static String? nickname;

  static bool get isLoggedIn => token != null && token!.isNotEmpty;

  /// 앱 시작 시 저장된 세션 복원.
  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
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
  }

  /// 로그아웃.
  static Future<void> clear() async {
    token = null;
    userId = null;
    nickname = null;
    await (await SharedPreferences.getInstance()).clear();
  }
}
