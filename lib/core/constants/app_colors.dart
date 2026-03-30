import 'package:flutter/material.dart';

class AppColors {
  // ── Primary Palette ──────────────────────────────────────────
  static const primary     = Color(0xFF2A7FFF);
  static const secondary   = Color(0xFF4CB8A4);
  static const background  = Color(0xFFF5F7FA);
  static const surface     = Color(0xFFFFFFFF);

  // ── Status Colors ────────────────────────────────────────────
  static const danger      = Color(0xFFEF4444);
  static const warning     = Color(0xFFF59E0B);
  static const success     = Color(0xFF22C55E);
  static const info        = Color(0xFF3B82F6);

  // ── Role Colors ──────────────────────────────────────────────
  static const elderlyColor   = Color(0xFF2A7FFF);
  static const caregiverColor = Color(0xFF4CB8A4);
  static const emergencyColor = Color(0xFFEF4444);

  // ── Text Colors ──────────────────────────────────────────────
  static const textPrimary   = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted     = Color(0xFF9CA3AF);

  // ── Sensor Status Colors ─────────────────────────────────────
  static const sensorActive   = Color(0xFF22C55E);
  static const sensorInactive = Color(0xFF9CA3AF);
  static const sensorAlert    = Color(0xFFEF4444);

  // ── Alert Priority Colors ────────────────────────────────────
  static const alertHigh   = Color(0xFFEF4444);
  static const alertMedium = Color(0xFFF59E0B);
  static const alertLow    = Color(0xFF3B82F6);

  // ── Dashboard-Specific ───────────────────────────────────────
  static const emergencyBg = Color(0xFFFFF5F5);
  static const caregiverBg = Color(0xFFF0FDF4);
  static const elderlyBg   = Color(0xFFF0F4FF);

  // ── Gradient Presets ─────────────────────────────────────────
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF2A7FFF), Color(0xFF1A5FCC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const dangerGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const successGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const splashGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 20,
      spreadRadius: 0,
      offset: Offset(0, 8),
    ),
  ];
}