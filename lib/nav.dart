// ============================================================
// [v1] 전역 네비게이션 — 화면 밖(API 클라이언트 등)에서 화면 전환이 필요할 때
// pipeline: 모바일 클라이언트 / 부트스트랩·네비게이션
// 구현(요약): MaterialApp에 꽂는 navigatorKey + "로그인 화면으로 보내기" 한 가지.
//            401(세션 만료·다른 서버 토큰)을 ApiClient가 감지하면 여기로 보낸다.
//            위젯 트리가 아직 없으면(테스트·부팅 중) 조용히 무시한다.
// 구현일: 2026-09-04 | 작성: kys (dev 직접 반영 — 팀 실기기 테스트 중 401 막힘)
// ============================================================
import 'package:flutter/material.dart';

import 'screens/login_screen.dart';

class AppNav {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  /// 스택을 비우고 로그인 화면으로. [notice]가 있으면 스낵바로 이유를 알려준다.
  static void toLogin({String? notice}) {
    final nav = key.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    final ctx = key.currentContext;
    if (notice != null && ctx != null) {
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(content: Text(notice)));
    }
  }
}
