// ============================================================
// [v1] 앱 설정 — 서버 베이스 URL 등
// pipeline: 모바일 클라이언트 / 공통 (REST 대상)
// 구현(요약): dokkaebi-server 주소. 실기기에선 localhost 대신 PC IP로.
// 구현일: 2026-06-18 | 작성: kys (app-scaffold/kys/v1)
// ============================================================

class AppConfig {
  /// 게임 서버(dokkaebi-server) 주소.
  /// ⚠️ 에뮬레이터/실기기에선 localhost가 안 됨:
  ///   - Android 에뮬레이터: http://10.0.2.2:8000
  ///   - 실기기: http://<PC_IP>:8000
  static const String serverBaseUrl = 'http://localhost:8000';
}
