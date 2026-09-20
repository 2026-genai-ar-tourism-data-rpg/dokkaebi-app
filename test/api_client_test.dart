// ============================================================
// [v1] apiErrorMessage — 예외를 화면에 그대로 노출하지 않는지 검증.
// 구현(요약): 화면 7곳이 '$e'를 그대로 문구에 박고 있다가 App Store 심사에서
//            두 차례(로그인·나만의 코스 만들기) "오류가 떴다"로 지적받았다(2026-09-19/20).
// 구현일: 2026-09-21 | 작성: Claude
// ============================================================
import 'package:flutter_test/flutter_test.dart';

import 'package:dokkaebi_app/api/api_client.dart';

void main() {
  group('apiErrorMessage', () {
    test('ApiException.message는 서버가 보낸 사용자용 문구라 그대로 쓴다', () {
      final e = ApiException(
        action: '시나리오 생성',
        statusCode: 422,
        code: 'domain_error',
        message: '반경 3000m 내 관광지 없음 (좌표 -122.009,37.3349)',
      );
      expect(apiErrorMessage(e), '반경 3000m 내 관광지 없음 (좌표 -122.009,37.3349)');
    });

    test('네트워크 예외처럼 알 수 없는 예외는 원문 노출 없이 일반 안내로 떨어진다', () {
      final e = Exception('SocketException: Failed host lookup');
      final msg = apiErrorMessage(e);
      expect(msg, isNot(contains('SocketException')));
      expect(msg.isNotEmpty, isTrue);
    });
  });
}
