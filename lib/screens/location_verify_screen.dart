// ============================================================
// [v1] 화면: 위치 확인 완료 (시안 5)
// pipeline: 모바일 클라이언트 / 화면 (GPS 인증 전환)
// 구현(요약): 글로우 원 + "위치 확인 완료!" + 해제 중 로딩 → 잠시 후 자동 진행(pop true).
//            실제 GPS 판정은 TODO(정찬희, geolocator) — 지금은 연출 + 전환.
// 구현일: 2026-06-18 | 작성: kys (app-theme/kys/v1)
// ============================================================
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

class LocationVerifyScreen extends StatefulWidget {
  final String placeName;
  const LocationVerifyScreen({super.key, this.placeName = '경복궁'});
  @override
  State<LocationVerifyScreen> createState() => _LocationVerifyScreenState();
}

class _LocationVerifyScreenState extends State<LocationVerifyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void initState() {
    super.initState();
    // 연출 후 자동 진행(인증 완료로 pop). 실제론 GPS 판정 결과로 분기(정찬희).
    Timer(const Duration(milliseconds: 1800), () {
      if (mounted) Navigator.pop(context, true);
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 펄스 글로우 원
                  ScaleTransition(
                    scale: Tween(begin: 0.85, end: 1.15).animate(
                        CurvedAnimation(parent: _ac, curve: Curves.easeInOut)),
                    child: Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.teal.withOpacity(0.15),
                        border: Border.all(color: AppColors.teal),
                        boxShadow: [BoxShadow(color: AppColors.teal.withOpacity(0.4), blurRadius: 30, spreadRadius: 4)],
                      ),
                      child: const Icon(Icons.my_location, color: AppColors.teal, size: 36),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('위치 확인 완료!',
                      style: TextStyle(color: AppColors.teal, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('${widget.placeName} 근처에 있습니다.',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const Text('퀘스트를 해제하는 중...',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.place, size: 14, color: AppColors.teal),
                    const SizedBox(width: 6),
                    Text('${widget.placeName}, 서울 종로구',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
