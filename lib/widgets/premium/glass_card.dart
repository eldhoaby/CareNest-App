import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Premium GlassCard
///
/// Light mode: semi-solid white (0.92 opacity) with a very soft shadow.
/// Backdrop blur is disabled in light mode since the near-white surface
/// makes the glass effect invisible and wastes GPU.
///
/// Dark mode: true glass — low-opacity frosted background with blur.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double blurX;
  final double blurY;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? color;
  final bool showShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.blurX = 12.0,
    this.blurY = 12.0,
    this.borderRadius = 24.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.color,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Light mode: semi-solid white card (readability > glass effect)
    if (!isDark) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: color ?? Colors.white,
          boxShadow: showShadow ? AppColors.cardShadow : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      );
    }

    // Dark mode: proper glass card with backdrop blur
    final darkBg = color ?? Colors.white.withValues(alpha: 0.07);
    final darkBorder = Colors.white.withValues(alpha: 0.08);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: darkBg,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: darkBorder, width: 1.0),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
