// ============================================================
// [v2] 앱 설정 — 서버 베이스 URL 등
// pipeline: 모바일 클라이언트 / 공통 (REST 대상)
// 구현(요약): dokkaebi-server 주소를 빌드 시 --dart-define으로 주입.
//            하드코딩 localhost였던 것을 빼냈다 — 실기기에선 localhost가 폰 자신을
//            가리켜 서버에 절대 닿지 않는다(실기기 연결 실패의 1순위 원인).
// 구현일: 2026-06-18 (dart-define 주입: 2026-08-04) | 작성: kys (app-scaffold/kys/v1)
// ============================================================

class AppConfig {
  /// 게임 서버(dokkaebi-server) 주소.
  ///
  /// 빌드/실행 시 주입한다:
  /// ```
  /// flutter run --dart-define=SERVER_BASE_URL=http://192.168.0.102:8000
  /// ```
  ///
  /// 환경별 값:
  ///   - 실기기(같은 Wi-Fi)    : http://<PC의 LAN IP>:8000
  ///   - Android 에뮬레이터     : http://10.0.2.2:8000
  ///   - iOS 시뮬레이터·데스크톱 : http://localhost:8000
  ///
  /// 기본값은 시뮬레이터/데스크톱 기준이라 실기기에선 반드시 넘겨야 한다.
  static const String serverBaseUrl = String.fromEnvironment(
    'SERVER_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// 루프백 주소를 쓰고 있는지 — 실기기에서 이러면 서버에 닿지 못한다.
  /// 진단 배너를 띄워 "왜 안 되지"로 시간 날리는 것을 막는다.
  static bool get isLoopback =>
      serverBaseUrl.contains('localhost') || serverBaseUrl.contains('127.0.0.1');
}
