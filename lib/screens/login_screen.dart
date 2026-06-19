// ============================================================
// [v1] 화면: 로그인 (게스트)
// pipeline: 모바일 클라이언트 / 인증
// 구현(요약): 닉네임 입력 → 서버 게스트 로그인(토큰) → 세션 저장 → 메인.
//            카카오/구글은 같은 화면에 버튼 추가 예정(키 발급 후).
// 구현일: 2026-06-18 | 작성: kys (auth-guest/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../main.dart';
import '../store.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _api = ApiClient();
  final _nick = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _guest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.guestLogin(_nick.text.trim().isEmpty ? '탐험가' : _nick.text.trim());
      await ScenarioStore.I.load(); // 이 유저의 저장된 탐험 복원
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MainShell()));
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
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                        gradient: const LinearGradient(colors: [AppColors.teal, AppColors.blue]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: AppColors.teal.withOpacity(0.5), blurRadius: 32, spreadRadius: 2)],
                      ),
                    ),
                  ),
                ),
              ),
              const Text('도깨비: 팔도의 비밀',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('이름을 정하고 탐사를 시작하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 28),
              TextField(
                controller: _nick,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(hintText: '닉네임 (예: 지민)'),
                onSubmitted: (_) => _guest(),
              ),
              const SizedBox(height: 8),
              if (_error != null)
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 12)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loading ? null : _guest,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('게스트로 시작'),
              ),
              const SizedBox(height: 16),
              const Text('카카오·구글 로그인 (준비 중)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
