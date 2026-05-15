import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // Staggered entrance start
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _selectRole(String role) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            LoginScreen(role: role),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          return SlideTransition(
            position: animation.drive(Tween(begin: begin, end: end).chain(CurveTween(curve: curve))),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep fallback base
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── 1. Premium Layered Background ──────────────────────────
          const PremiumLayeredBackground(),

          // ── 2. Screen Fade-in wrapper ────────────────────────────────
          FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: _entranceController,
                curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    // ── Header Area ──────────────────────────────────────
                    Column(
                      children: [
                        // Logo (Scale-in from 0.9 to 1.0)
                        ScaleTransition(
                          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                            CurvedAnimation(
                              parent: _entranceController,
                              curve: const Interval(0.1, 0.6, curve: Curves.easeOutCubic),
                            ),
                          ),
                          child: FadeTransition(
                            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                parent: _entranceController,
                                curve: const Interval(0.1, 0.4, curve: Curves.easeOut),
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    // Subtle light glow
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.35),
                                      blurRadius: 18,
                                      spreadRadius: 2,
                                    ),
                                    // Soft elevation shadow
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Image.asset(
                                      'assets/images/safenest_logo.png',
                                      width: 68,
                                      height: 68,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title (Fade + Slight Upward Motion)
                        FadeTransition(
                          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                            CurvedAnimation(
                              parent: _entranceController,
                              curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
                            ),
                          ),
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _entranceController,
                                curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic),
                              ),
                            ),
                            child: Text(
                              'Choose Your Access',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 28,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtitle (Delayed fade-in, distinct letter spacing)
                        FadeTransition(
                          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                            CurvedAnimation(
                              parent: _entranceController,
                              curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
                            ),
                          ),
                          child: Text(
                            'Care That Never Sleeps',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                  letterSpacing: 1.5,
                                ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // ── Role Cards (Staggered Appearance) ──────────────────
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 40),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildAnimatedCard(
                            index: 0,
                            title: 'Elderly / Patient',
                            description: 'Personal safety monitoring',
                            iconData: Icons.person_rounded,
                            roleValue: 'elderly',
                            gradient: AppColors.primaryGradient,
                          ),
                          const SizedBox(height: 20),
                          _buildAnimatedCard(
                            index: 1,
                            title: 'Caregiver / Family',
                            description: 'Monitor loved ones & receive alerts',
                            iconData: Icons.group_rounded,
                            roleValue: 'caregiver',
                            gradient: AppColors.secondaryGradient,
                          ),
                          const SizedBox(height: 20),
                          _buildAnimatedCard(
                            index: 2,
                            title: 'Emergency Services',
                            description: 'Respond instantly to safety alerts',
                            iconData: Icons.local_hospital_rounded,
                            roleValue: 'emergency',
                            gradient: AppColors.emergencyGradient,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCard({
    required int index,
    required String title,
    required String description,
    required IconData iconData,
    required String roleValue,
    required LinearGradient gradient,
  }) {
    // Stagger calculation
    final double start = 0.4 + (index * 0.12);
    final double end = (start + 0.35).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.0, 0.15), end: Offset.zero)
            .animate(animation),
        child: _RoleCard(
          title: title,
          description: description,
          iconData: iconData,
          gradient: gradient,
          onTap: () => _selectRole(roleValue),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM LAYERED BACKGROUND
// ═══════════════════════════════════════════════════════════════════════════

class PremiumLayeredBackground extends StatefulWidget {
  const PremiumLayeredBackground({super.key});

  @override
  State<PremiumLayeredBackground> createState() => _PremiumLayeredBackgroundState();
}

class _PremiumLayeredBackgroundState extends State<PremiumLayeredBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    // Ultra slow, natural premium motion
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          return CustomPaint(
            painter: _BackgroundPainter(progress: _bgController.value),
          );
        },
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double progress;

  _BackgroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Because the animation drives 0 -> 1 -> 0, smooth transitions naturally occur
    final t = progress * 2 * math.pi;

    // ── LAYER 1: Deep gradient slowly shifting direction ──
    // Shift top-left to bottom-right dynamically
    final originOffset = progress * 0.4; // 0 to 0.4 sweep
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1.0 + originOffset, -1.0),
        end: Alignment(1.0 - originOffset, 1.0),
        colors: const [
          Color(0xFF0F172A), // Top: Dark Blue Slate
          Color(0xFF0F766E), // Middle: Deep Teal
          Color(0xFF064E3B), // Bottom: Forest Green
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // ── LAYER 3: Large blurred shapes moving slowly (8% - 12% opacity) ──
    final shapePaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);

    // Teal off-center shape
    shapePaint.color = const Color(0xFF0f766e).withValues(alpha: 0.12);
    canvas.drawCircle(
      Offset(
        size.width * 0.2 + math.sin(t) * 60,
        size.height * 0.4 + math.cos(t * 1.5) * 80,
      ),
      200,
      shapePaint,
    );

    // Mint/Aqua off-center shape
    shapePaint.color = const Color(0xFF14B8A6).withValues(alpha: 0.08);
    canvas.drawCircle(
      Offset(
        size.width * 0.8 + math.cos(t * 0.8) * 80,
        size.height * 0.75 + math.sin(t * 1.2) * 60,
      ),
      250,
      shapePaint,
    );

    // ── LAYER 2: Radial light glow behind logo (Pulsing very slightly) ──
    // Visual center for the logo is roughly around height * 0.15 - 0.2
    final pulse = 1.0 + 0.1 * math.sin(progress * math.pi * 4); // Subtle pulsing
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.18 * pulse),
          const Color(0xFF3B82F6).withValues(alpha: 0.05 * pulse),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width / 2, size.height * 0.16),
        radius: 180 * pulse,
      ));

    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.16),
      180 * pulse,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ROLE CARD
// ═══════════════════════════════════════════════════════════════════════════

class _RoleCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData iconData;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.iconData,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    // Tap scaling (1.0 -> 0.96)
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    // Shadow depth dynamically increases inversely to the press
    _elevationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _scaleController.reverse();
    // Trigger navigation slightly after releasing to allow bounce back (1.0 -> 0.96 -> 1.0)
    Future.delayed(const Duration(milliseconds: 150), widget.onTap);
  }

  void _handleTapCancel() => _scaleController.reverse();

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.gradient.colors.first;

    return AnimatedBuilder(
      animation: _scaleController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  // Shadow increases slightly upon press via interpolation
                  color: Colors.black.withValues(
                      alpha: 0.12 + (_elevationAnimation.value * 0.1)),
                  blurRadius: 30 + (_elevationAnimation.value * 10),
                  offset: Offset(0, 12 + (_elevationAnimation.value * 4)),
                  spreadRadius: _elevationAnimation.value * 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              // Soft glass effect with subtle transparency
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.78),
                  child: InkWell(
                    onTapDown: _handleTapDown,
                    onTapUp: _handleTapUp,
                    onTapCancel: _handleTapCancel,
                    onTap: () {}, // Event handled in tap up
                    splashColor: baseColor.withValues(alpha: 0.06),
                    highlightColor: baseColor.withValues(alpha: 0.03),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          // Icon Sphere
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              gradient: widget.gradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: baseColor.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              widget.iconData,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),

                          const SizedBox(width: 20),

                          // Text Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.description,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                        height: 1.3,
                                      ),
                                ),
                              ],
                            ),
                          ),

                          // Chevron
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: baseColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: baseColor,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}