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

/// 둥근 다크 카드 (보더 + 옵션 글로우). 항상 은은한 입체 그림자 + 상단 하이라이트를 두르고,
/// onTap이 있으면 누를 때 살짝 눌리는 스케일 피드백을 준다.
class GlowCard extends StatefulWidget {
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
  State<GlowCard> createState() => _GlowCardState();
}

class _GlowCardState extends State<GlowCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.onTap == null) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.glow;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: glow?.withOpacity(0.5) ?? AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_pressed ? 0.15 : 0.35),
                blurRadius: _pressed ? 5 : 12,
                offset: Offset(0, _pressed ? 1 : 5),
              ),
              if (glow != null)
                BoxShadow(
                    color: glow.withOpacity(_pressed ? 0.10 : 0.18),
                    blurRadius: 20,
                    spreadRadius: -4),
            ],
          ),
          // 위에서 빛이 떨어지는 듯한 은은한 하이라이트 (상단만 밝게 washed).
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [AppColors.textPrimary.withOpacity(0.05), Colors.transparent],
            ),
          ),
          child: widget.child,
        ),
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

/// 스탯 타일 (원형 메달 아이콘 + 값 + 라벨) — 게임 업적 배지 느낌.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const StatTile(this.icon, this.value, this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.14),
            border: Border.all(color: color.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.25), blurRadius: 14, spreadRadius: -2),
              BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ]),
    );
  }
}

/// 진행률 바 — 그라데이션 채움 + 값이 바뀔 때 부드럽게 차오르는 애니메이션.
class ProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  const ProgressBar(this.value, {super.key, this.color = AppColors.teal});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 1).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 8,
        color: AppColors.border,
        child: Align(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: v),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, animatedV, _) => FractionallySizedBox(
              widthFactor: animatedV,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.75), color],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
