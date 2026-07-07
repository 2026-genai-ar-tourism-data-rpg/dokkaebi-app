// ============================================================
// [v1] 공통 UI 위젯 — 시안 디자인 시스템 부품
// pipeline: 모바일 클라이언트 / 디자인 시스템 (재사용 위젯)
// 구현(요약): SectionHeader(영문라벨+한글제목)·GlowCard·Pill·StatTile·ProgressBar.
// 구현일: 2026-06-18 | 작성: kys (app-theme/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../theme.dart';

/// 영문 작은 라벨 + 한글 큰 제목 (시안 헤더 패턴)
class SectionHeader extends StatelessWidget {
  final String eng;
  final String ko;
  final Widget? trailing;
  const SectionHeader(this.eng, this.ko, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eng,
                  style: const TextStyle(
                      color: AppColors.teal,
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(ko,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// 둥근 다크 카드 (보더 + 옵션 글로우)
class GlowCard extends StatelessWidget {
  final Widget child;
  final Color? glow;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const GlowCard({
    super.key,
    required this.child,
    this.glow,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: glow?.withOpacity(0.5) ?? AppColors.border),
          boxShadow: glow != null
              ? [BoxShadow(color: glow!.withOpacity(0.18), blurRadius: 20, spreadRadius: -4)]
              : null,
        ),
        child: child,
      ),
    );
  }
}

/// 알약형 칩 (탭/필터). active면 채움.
class Pill extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback? onTap;
  const Pill(this.label,
      {super.key, this.active = false, this.color = AppColors.teal, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? color : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// 스탯 타일 (아이콘 + 값 + 라벨)
class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const StatTile(this.icon, this.value, this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlowCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ]),
      ),
    );
  }
}

/// 진행률 바 (그라데이션)
class ProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  const ProgressBar(this.value, {super.key, this.color = AppColors.teal});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 8,
        backgroundColor: AppColors.border,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}
