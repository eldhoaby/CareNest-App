import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Premium Animated Button with press-scale micro-interaction.
/// Glow is disabled by default (showGlow: false) for a clean, minimal look.
/// Enable it only for high-emphasis CTAs.
class PremiumAnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final LinearGradient? gradient;
  final Color? color;
  final double borderRadius;
  final double scaleDownFactor;
  final Duration animationDuration;
  final EdgeInsetsGeometry? padding;
  final bool showGlow;
  final double? width;
  final double? height;

  const PremiumAnimatedButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.gradient,
    this.color,
    this.borderRadius = 30.0,
    this.scaleDownFactor = 0.97,
    this.animationDuration = const Duration(milliseconds: 120),
    this.padding,
    this.showGlow = false,
    this.width,
    this.height,
  });

  @override
  State<PremiumAnimatedButton> createState() => _PremiumAnimatedButtonState();
}

class _PremiumAnimatedButtonState extends State<PremiumAnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDownFactor)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onPressed();
  }
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final activeGradient =
        widget.gradient ?? (widget.color == null ? AppColors.primaryGradient : null);
    final activeColor =
        widget.color ?? (activeGradient == null ? AppColors.primary : null);
    final glowBase =
        activeGradient?.colors.first ?? activeColor ?? AppColors.primary;

    // When height is explicitly set, use no padding to avoid clipping.
    // Otherwise use provided padding or default.
    final effectivePadding = widget.height != null
        ? (widget.padding ?? const EdgeInsets.symmetric(horizontal: 16))
        : (widget.padding ?? const EdgeInsets.symmetric(horizontal: 32, vertical: 18));

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: activeGradient,
              color: activeColor,
              boxShadow: widget.showGlow
                  ? [
                      BoxShadow(
                        color: glowBase.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: effectivePadding,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: widget.child,
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
