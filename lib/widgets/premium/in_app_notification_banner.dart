import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// IN-APP NOTIFICATION BANNER — WhatsApp / Instagram-style Toast v2
//
// Modern floating notification with:
//  • Glassmorphism backdrop + severity color accent
//  • App icon + title + body + relative timestamp
//  • Auto-dismiss countdown progress bar
//  • Smooth slide-down + fade entry, slide-up + fade exit
//  • Swipe-up to dismiss, tap to interact
//  • Stack offset support for multiple notifications
//  • Dark/light mode adaptive
// ═══════════════════════════════════════════════════════════════════════════

class InAppNotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final String priority; // 'high', 'medium', 'low'
  final IconData? iconData;
  final int stackIndex; // 0 = newest (top), 1, 2 = older (below)
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const InAppNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    this.priority = 'medium',
    this.iconData,
    this.stackIndex = 0,
    this.onTap,
    required this.onDismiss,
  });

  @override
  State<InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _progressController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  static const _autoDismissDuration = Duration(seconds: 5);
  static const _entryDuration = Duration(milliseconds: 480);
  static const _exitDuration = Duration(milliseconds: 280);

  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    // ── Entry animation ──
    _entryController = AnimationController(
      vsync: this,
      duration: _entryDuration,
      reverseDuration: _exitDuration,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOutCubic,
      ),
    );

    // ── Progress bar (auto-dismiss countdown) ──
    _progressController = AnimationController(
      vsync: this,
      duration: _autoDismissDuration,
    );

    _entryController.forward();
    _progressController.forward();

    // Auto-dismiss when countdown completes
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isDismissing) {
        _dismiss();
      }
    });
  }

  Future<void> _dismiss() async {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    _progressController.stop();
    await _entryController.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  // ── Severity-based theming ──

  Color get _accentColor {
    switch (widget.priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFEF4444); // Vivid red
      case 'medium':
        return const Color(0xFFF59E0B); // Amber
      default:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  Color get _accentBg {
    switch (widget.priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFFEE2E2);
      case 'medium':
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFDBEAFE);
    }
  }

  IconData get _fallbackIcon {
    switch (widget.priority.toLowerCase()) {
      case 'high':
        return Icons.warning_amber_rounded;
      case 'medium':
        return Icons.notification_important_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String get _priorityLabel {
    switch (widget.priority.toLowerCase()) {
      case 'high':
        return 'CRITICAL';
      case 'medium':
        return 'WARNING';
      default:
        return 'INFO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icon = widget.iconData ?? _fallbackIcon;

    // Stack offset: each subsequent notification shifts down
    final stackOffset = widget.stackIndex * 8.0;
    final stackScale = 1.0 - (widget.stackIndex * 0.03);
    final stackOpacity = (1.0 - (widget.stackIndex * 0.15)).clamp(0.4, 1.0);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            alignment: Alignment.topCenter,
            child: Opacity(
              opacity: stackOpacity,
              child: Transform.translate(
                offset: Offset(0, stackOffset),
                child: Transform.scale(
                  scale: stackScale,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _dismiss();
                      widget.onTap?.call();
                    },
                    onVerticalDragEnd: (details) {
                      if (details.velocity.pixelsPerSecond.dy < -80) {
                        HapticFeedback.lightImpact();
                        _dismiss();
                      }
                    },
                    child: Container(
                      margin: EdgeInsets.fromLTRB(
                        14, topPadding + 10, 14, 0,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                      .withValues(alpha: 0.94)
                                  : Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? _accentColor.withValues(alpha: 0.25)
                                    : _accentColor.withValues(alpha: 0.15),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _accentColor.withValues(alpha: 0.15),
                                  blurRadius: 28,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ── Main content ──
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14, 14, 14, 10,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // ── Severity icon pill ──
                                      _buildIconPill(icon, isDark),
                                      const SizedBox(width: 12),

                                      // ── Text content ──
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // App name + timestamp row
                                            _buildHeaderRow(isDark),
                                            const SizedBox(height: 5),

                                            // Title
                                            Text(
                                              widget.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: isDark
                                                    ? Colors.white
                                                    : AppColors.textPrimary,
                                                letterSpacing: -0.3,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 3),

                                            // Body
                                            Text(
                                              widget.body,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                height: 1.35,
                                                color: isDark
                                                    ? Colors.white
                                                        .withValues(alpha: 0.7)
                                                    : AppColors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 6),

                                            // Severity badge + action hint
                                            _buildFooterRow(isDark),
                                          ],
                                        ),
                                      ),

                                      // ── Close button ──
                                      _buildCloseButton(isDark),
                                    ],
                                  ),
                                ),

                                // ── Auto-dismiss progress bar ──
                                _buildProgressBar(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Icon pill (left side) ──
  Widget _buildIconPill(IconData icon, bool isDark) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isDark
            ? _accentColor.withValues(alpha: 0.18)
            : _accentBg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: _accentColor.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: _accentColor,
        size: 21,
      ),
    );
  }

  // ── Header: app label + "Just now" ──
  Widget _buildHeaderRow(bool isDark) {
    return Row(
      children: [
        // App name
        Text(
          'CareNest',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : AppColors.textMuted,
            letterSpacing: 0.3,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.3)
                : AppColors.textMuted.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
        ),
        Text(
          'Just now',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : AppColors.textMuted.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  // ── Footer: severity badge + tap hint ──
  Widget _buildFooterRow(bool isDark) {
    return Row(
      children: [
        // Priority badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: isDark ? 0.18 : 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _priorityLabel,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: _accentColor,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const Spacer(),
        // Tap to view hint
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tap to view',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.35)
                    : AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : AppColors.primary.withValues(alpha: 0.4),
            ),
          ],
        ),
      ],
    );
  }

  // ── Close button (top-right) ──
  Widget _buildCloseButton(bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _dismiss();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, top: 2),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.close_rounded,
            size: 13,
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  // ── Auto-dismiss progress bar ──
  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, child) {
        return Container(
          height: 3,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            color: Colors.transparent,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: LinearProgressIndicator(
              value: 1.0 - _progressController.value,
              backgroundColor: _accentColor.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(
                _accentColor.withValues(alpha: 0.35),
              ),
              minHeight: 3,
            ),
          ),
        );
      },
    );
  }
}
