import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../core/services/firebase_service.dart';
import '../../models/alert_model.dart';
import '../../widgets/premium/glass_card.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EMERGENCY HISTORY TAB — Global Resolved Dashboard
// ═══════════════════════════════════════════════════════════════════════════

class EmergencyHistoryTab extends StatefulWidget {
  final String userId;

  const EmergencyHistoryTab({super.key, required this.userId});

  @override
  State<EmergencyHistoryTab> createState() => _EmergencyHistoryTabState();
}

class _EmergencyHistoryTabState extends State<EmergencyHistoryTab>
    with SingleTickerProviderStateMixin {
  // ── State ────────────────────────────────────────────────────
  List<AlertModel> _allAlerts = [];
  bool _isLoaded = false;
  String? _errorMessage;
  StreamSubscription? _alertsSub;
  
  // ── Animation ───────────────────────────────────────────────
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _startAlertsStream();
  }

  void _startAlertsStream() {
    _alertsSub?.cancel();
    setState(() {
      _errorMessage = null;
      _isLoaded = false;
    });

    _alertsSub = FirebaseService.instance
        .globalResolvedAlertsStream()
        .listen(
      (snapshot) {
        if (!mounted) return;

        final newAlerts =
            snapshot.docs.map((d) => AlertModel.fromDoc(d)).toList();

        // Client-side sort: prefer resolvedAt, fall back to timestamp
        newAlerts.sort((a, b) {
          final aDate = a.resolvedAt ?? a.timestamp ?? DateTime(2000);
          final bDate = b.resolvedAt ?? b.timestamp ?? DateTime(2000);
          return bDate.compareTo(aDate); // Most recent first
        });

        final changed = newAlerts.length != _allAlerts.length ||
            (newAlerts.isNotEmpty &&
                _allAlerts.isNotEmpty &&
                newAlerts.first.id != _allAlerts.first.id);

        if (changed || !_isLoaded) {
          setState(() {
            _allAlerts = newAlerts;
            _isLoaded = true;
            _errorMessage = null;
          });
          if (!_entranceController.isCompleted) {
            _entranceController.forward(from: 0.0);
          }
        }
      },
      onError: (error) {
        debugPrint('EmergencyHistoryTab stream error: $error');
        if (!mounted) return;
        setState(() {
          _isLoaded = true;
          _errorMessage =
              'Unable to load resolved alerts. Please check your connection.';
        });
      },
    );
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    _entranceController.dispose();
    super.dispose();
  }
  
  // ════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          _buildHeader(),

          // 2. Alert count summary
          _buildCountBar(),

          // 3. Alert List
          Expanded(
            child: !_isLoaded
                ? _buildLoadingState()
                : _errorMessage != null
                    ? _buildErrorState()
                    : _allAlerts.isEmpty
                        ? _buildEmptyState()
                        : _buildAlertList(),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 1. HEADER
  // ════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          // Title
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alert History',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Past emergencies and resolutions',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          
          // History Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 24),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 2. COUNT BAR
  // ════════════════════════════════════════════════════════════════

  Widget _buildCountBar() {
    final count = _allAlerts.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Text(
        '$count resolved emergency incident${count == 1 ? '' : 's'}',
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 3. ALERT LIST
  // ════════════════════════════════════════════════════════════════

  Widget _buildAlertList() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: _allAlerts.length,
      itemBuilder: (context, index) {
        // Staggered entrance
        final delay = (index * 0.08).clamp(0.0, 0.6);
        final end = (delay + 0.4).clamp(0.0, 1.0);

        return AnimatedBuilder(
          animation: _entranceController,
          builder: (context, child) {
            final t = Curves.easeOutCubic.transform(
              ((_entranceController.value - delay) / (end - delay))
                  .clamp(0.0, 1.0),
            );
            return Transform.translate(
              offset: Offset(0, 20 * (1 - t)),
              child: Opacity(opacity: t, child: child),
            );
          },
          child: _PremiumEmergencyHistoryCard(alert: _allAlerts[index]),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // LOADING, ERROR & EMPTY STATES
  // ════════════════════════════════════════════════════════════════

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(
          4,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Something Went Wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Material(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _startAlertsStream,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.inbox_rounded,
                size: 40,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No History Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'There are no resolved emergencies\nin your log right now.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PREMIUM ALERT CARD (EMERGENCY HISTORY)
// ══════════════════════════════════════════════════════════════════════════════

class _PremiumEmergencyHistoryCard extends StatefulWidget {
  final AlertModel alert;

  const _PremiumEmergencyHistoryCard({required this.alert});

  @override
  State<_PremiumEmergencyHistoryCard> createState() => _PremiumEmergencyHistoryCardState();
}

class _PremiumEmergencyHistoryCardState extends State<_PremiumEmergencyHistoryCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final accentColor = alert.categoryColor.withValues(alpha: 0.5); // Subdued for history

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          HapticFeedback.lightImpact();
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: 0.7, // Dimming entire card structurally to indicate "Resolved" history
            child: GlassCard(
              padding: const EdgeInsets.all(0),
              borderRadius: 18,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border(
                    left: BorderSide(color: accentColor, width: 4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        alert.typeIcon,
                        color: accentColor.withAlpha(255),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  alert.description,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              // Resolved Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('RESOLVED', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Description
                          Text(
                            alert.typeLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted.withValues(alpha: 0.8),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Patient Name
                          if (alert.elderlyName != null && alert.elderlyName!.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.person_rounded, size: 14, color: AppColors.primary.withValues(alpha: 0.7)),
                                const SizedBox(width: 4),
                                Text(
                                  alert.elderlyName!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],

                          // Address
                          if (alert.address != null && alert.address!.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded, size: 14, color: AppColors.textMuted.withValues(alpha: 0.7)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    alert.address!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ] else ...[
                            const SizedBox(height: 4),
                          ],

                          // ── Resolved At row ──
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: AppColors.success.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Resolved: ${alert.formattedResolvedAt}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.success.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Bottom row — alert time + priority
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: AppColors.textMuted.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                alert.formattedTime.isNotEmpty
                                    ? alert.formattedTime
                                    : alert.timeAgo,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  alert.category.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: accentColor.withAlpha(255),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
