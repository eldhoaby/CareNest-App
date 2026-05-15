import 'package:flutter/material.dart';

class AppColors {
  // ── Primary Palette (Medical-Grade Deep Blue & Teal) ──────────
  static const primary       = Color(0xFF1E3A8A); // Deep Blue
  static const primarySoft   = Color(0xFF3B82F6); // Standard Blue
  static const secondary     = Color(0xFF0D9488); // Deep Teal
  static const secondarySoft = Color(0xFF14B8A6); // Soft Teal

  static const background    = Color(0xFFF1F5F9); // Soft grey-blue
  static const surface       = Color(0xFFFFFFFF);

  // ── Status Colors ────────────────────────────────────────────
  static const danger        = Color(0xFFDC3545); // Muted Red (medical)
  static const warning       = Color(0xFFF59E0B); // Amber
  static const success       = Color(0xFF10B981); // Muted Green
  static const info          = Color(0xFF0EA5E9); // Sky Blue

  // ── Text Colors ──────────────────────────────────────────────
  static const textPrimary   = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted     = Color(0xFF94A3B8);

  // ── Borders & Subtleties ─────────────────────────────────────
  static const border        = Color(0xFFE2E8F0);

  // ── Card Backgrounds ─────────────────────────────────────────
  // Light mode: semi-solid white (readable, not transparent)
  static final cardLight = Colors.white.withValues(alpha: 0.92);
  // Dark mode: glass effect (very low opacity)
  static final cardDark  = Colors.white.withValues(alpha: 0.06);

  // ── Alert Priority Colors ────────────────────────────────────
  static const alertHigh   = Color(0xFFDC3545); // Muted Red
  static const alertMedium = warning;
  static const alertLow    = primarySoft;

  // ── Strict Gradients (only 2 used across app) ────────────────
  /// Deep blue header gradient — used only for page headers
  static const dashboardGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF172554)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle primary gradient for filled buttons
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF1E40AF), Color(0xFF1E3A8A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Soft teal gradient used sparingly for secondary actions
  static const secondaryGradient = LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Emergency gradient — SOS only
  static const emergencyGradient = LinearGradient(
    colors: [Color(0xFFDC3545), Color(0xFFB91C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Splash screen gradient
  static const splashGradient = LinearGradient(
    colors: [Color(0xFF0F172A), primary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Minimal Shadows ──────────────────────────────────────────
  static const cardShadow = [
    BoxShadow(
      color: Color(0x06000000),
      blurRadius: 12,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
  ];

  static const cardShadowMedium = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 16,
      spreadRadius: 0,
      offset: Offset(0, 6),
    ),
  ];
}