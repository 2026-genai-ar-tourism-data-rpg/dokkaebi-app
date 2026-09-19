// ============================================================
// [v1] authErrorMessage — 인증 오류를 화면에 그대로 노출하지 않는지 검증.
// 구현(요약): App Store 심사에서 AuthApiException(...) 원문이 화면에 그대로
//            떴다고 지적받았다(2026-09-19). 알려진 원인은 안내 문구로, 모르는
//            예외는 일반 문구로 — 어떤 경우에도 원본 예외 텍스트가 새어나가지
//            않는지가 이 테스트의 핵심.
// 구현일: 2026-09-19 | 작성: Claude
// ------------------------------------------------------------
// [v2] 이메일 로그인 제거([v6], login_screen.dart)로 이 화면의 오류는 이제
//      Supabase가 아니라 서버 ApiException뿐이다 — 그 메시지는 서버가 애초에
//      사용자용으로 보내는 문구라 그대로 보여주는 게 맞는지로 테스트를 바꿨다.
// 구현일: 2026-09-19 | 작성: Claude
// ============================================================
import 'package:flutter_test/flutter_test.dart';

import 'package:dokkaebi_app/api/api_client.dart';
import 'package:dokkaebi_app/screens/login_screen.dart';

void main() {
  group('authErrorMessage', () {
    test('ApiException.message는 사용자용 문구라 그대로 보여준다', () {
      final e = ApiException(
        action: '로그인',
        statusCode: 429,
        code: 'rate_limited',
        message: '잠시 후 다시 시도해 주세요.',
      );
      expect(authErrorMessage(e), '잠시 후 다시 시도해 주세요.');
    });

    test('알 수 없는 예외는 원문 노출 없이 일반 안내로 떨어진다', () {
      final e = Exception('some internal detail nobody should see');
      final msg = authErrorMessage(e);
      expect(msg, isNot(contains('some internal detail')));
      expect(msg.isNotEmpty, isTrue);
    });
  });
}
