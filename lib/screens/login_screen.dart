// ============================================================
// [v1] 화면: 로그인 (게스트)
// pipeline: 모바일 클라이언트 / 인증
// 구현(요약): 닉네임 입력 → 서버 게스트 로그인(토큰) → 세션 저장 → 메인.
//            디버그 빌드에선 접속 중인 서버 주소를 화면에 노출(실기기 진단).
//            카카오/구글은 같은 화면에 버튼 추가 예정(키 발급 후).
// 구현일: 2026-06-18 (서버주소 진단 배너: 2026-08-04) | 작성: kys (auth-guest/kys/v1)
// ------------------------------------------------------------
// [v2] 이메일 로그인/회원가입 추가 — 게스트는 매번 새 계정이라 다시 로그인해도
//      이전 진행도로 이어지지 않았다. Supabase Auth로 신원을 증명하면 서버가
//      같은 user_id를 재발급한다(api_client.supabaseLogin). 회원가입은 이메일
//      확인이 끝나야 세션이 생기므로(Supabase 기본 설정) 그 경우 안내만 하고
//      로그인은 확인 후 별도로 하게 한다.
// 구현일: 2026-09-17 | 작성: jch
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../main.dart' show MainShell;
import '../store.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// 디버그 전용 — 지금 어느 서버로 붙는지 화면에 보여준다.
/// 실기기에서 localhost로 남아 있으면(= 폰 자신을 가리킴) 연결이 절대 안 되므로
/// "왜 안 되지"로 시간 날리지 않게 경고까지 띄운다.
class _ServerBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bad = AppConfig.isLoopback &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            bad ? Colors.red.withOpacity(0.12) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: bad ? Colors.red.withOpacity(0.5) : Colors.white24),
      ),
      child: Column(children: [
        Text('서버: ${AppConfig.serverBaseUrl}',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: bad ? Colors.red.shade200 : AppColors.textSecondary,
                fontSize: 11)),
        if (bad) ...[
          const SizedBox(height: 4),
          const Text(
            '실기기에서 localhost는 폰 자신을 가리킵니다.\n'
            '--dart-define=SERVER_BASE_URL=http://<PC_IP>:8000 으로 실행하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.redAccent, fontSize: 10),
          ),
        ],
      ]),
    );
  }
}

class _LoginScreenState extends State<LoginScreen> {
  final _api = ApiClient();
  final _nick = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _notice; // 오류는 아니지만 알려줘야 하는 것(이메일 확인 요청 등)

  /// 로그인 성공 후 공통 처리 — 게스트·이메일 로그인 모두 여기로 모인다.
  Future<void> _afterLogin() async {
    await ScenarioStore.I.load(); // 이 유저의 저장된 탐험 복원
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const MainShell()));
  }

  Future<void> _guest() async {
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      await _api
          .guestLogin(_nick.text.trim().isEmpty ? '탐험가' : _nick.text.trim());
      await _afterLogin();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canSubmitEmail =>
      _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _emailSignIn() async {
    if (!_canSubmitEmail) return;
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      final token = res.session?.accessToken;
      if (token == null) throw Exception('로그인에 실패했습니다.');
      await _api.supabaseLogin(token, nickname: _nick.text.trim());
      await _afterLogin();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _emailSignUp() async {
    if (!_canSubmitEmail) return;
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
      );
      final token = res.session?.accessToken;
      if (token == null) {
        // 이메일 확인이 켜져 있으면(기본값) 가입 직후엔 세션이 없다.
        setState(() => _notice = '확인 이메일을 보냈습니다. 메일의 링크를 연 뒤 로그인해 주세요.');
        return;
      }
      await _api.supabaseLogin(token, nickname: _nick.text.trim());
      await _afterLogin();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // 이메일 로그인 필드·버튼이 늘어나면서 작은 화면(iPhone SE 등)에서
        // 오버플로가 났다 — 화면이 좁으면 스크롤되게 하고, 넉넉하면 기존처럼 중앙 정렬.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 기억석 글로우
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        margin: const EdgeInsets.only(bottom: 28),
                        child: Transform.rotate(
                          angle: 0.785,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [AppColors.teal, AppColors.blue]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.teal.withOpacity(0.5),
                                    blurRadius: 32,
                                    spreadRadius: 2)
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Text('도깨비: 팔도의 비밀',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('이름을 정하고 탐사를 시작하세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _nick,
                      textAlign: TextAlign.center,
                      decoration:
                          const InputDecoration(hintText: '닉네임 (예: 지민)'),
                      onSubmitted: (_) => _guest(),
                    ),
                    const SizedBox(height: 8),
                    if (_error != null)
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12)),
                    if (_notice != null)
                      Text(_notice!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.teal, fontSize: 12)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loading ? null : _guest,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('게스트로 시작'),
                    ),
                    const SizedBox(height: 8),
                    const Text('게스트는 앱을 지우거나 로그아웃하면 진행도가 사라집니다',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 24),
                    Row(children: const [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('또는 이메일로 이어하기',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                      ),
                      Expanded(child: Divider(color: Colors.white24)),
                    ]),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _email,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(hintText: '이메일'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _password,
                      textAlign: TextAlign.center,
                      obscureText: true,
                      decoration:
                          const InputDecoration(hintText: '비밀번호 (6자 이상)'),
                      onSubmitted: (_) => _emailSignIn(),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading || !_canSubmitEmail
                              ? null
                              : _emailSignIn,
                          child: const Text('로그인'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading || !_canSubmitEmail
                              ? null
                              : _emailSignUp,
                          child: const Text('회원가입'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    const Text('카카오·구글 로그인 (준비 중)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                    if (kDebugMode) ...[
                      const SizedBox(height: 20),
                      _ServerBanner(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
