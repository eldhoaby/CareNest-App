import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/services/sound_service.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/unseen_alert_service.dart';
import '../../core/services/global_alert_cache_service.dart';
import '../../models/alert_model.dart';
import '../../widgets/premium/glass_card.dart';
import '../../widgets/global_loader.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ELDERLY ALERTS TAB — Premium, Filtered, Stable Alert Screen
// ═══════════════════════════════════════════════════════════════════════════

class ElderlyAlertsTab extends StatefulWidget {
  final String userId;

  const ElderlyAlertsTab({super.key, required this.userId});

  @override
  State<ElderlyAlertsTab> createState() => _ElderlyAlertsTabState();
}

class _ElderlyAlertsTabState extends State<ElderlyAlertsTab>
    with SingleTickerProviderStateMixin {
  // ── State ────────────────────────────────────────────────────
  List<AlertModel> _allAlerts = [];
  List<AlertModel> _historicalAlerts = [];
  List<AlertModel> _liveAlerts = [];
  bool _isLoaded = false;
  StreamSubscription? _alertsSub;
  
  final AudioPlayer _player = AudioPlayer();
  final Set<String> _shownAlertIds = {};

  /// Tracks alert IDs currently being resolved — prevents double-tap
  /// and guards against Firestore stream overwriting optimistic state.
  final Set<String> _resolvingIds = {};

  // ── Filter ──────────────────────────────────────────────────
  _FilterTab _selectedFilter = _FilterTab.all;

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

  Future<void> _startAlertsStream() async {
    if (widget.userId.isEmpty) return;
    _alertsSub?.cancel();

    // ── 1. Listen to Live Cache (always on for active changes) ──
    GlobalAlertCacheService.instance.alertsNotifier.addListener(_onGlobalCacheUpdated);
    GlobalAlertCacheService.instance.isLoadedNotifier.addListener(_onGlobalCacheLoadedChanged);
    _onGlobalCacheUpdated();
    _onGlobalCacheLoadedChanged();

    // ── 2. Fetch Robust Historic Chunk ──
    // Fetch both alerts and admin notifications concurrently
    try {
      setState(() => _isLoaded = false);
      
      final responses = await Future.wait([
        FirebaseService.instance.getRecentAlerts(limit: 200),
        FirebaseService.instance.getRecentNotifications(limit: 200),
      ]);
      
      if (!mounted) return;
      
      final alertsFromDB = responses[0].docs.map((d) => AlertModel.fromDoc(d));
      final notifsFromDB = responses[1].docs.map((d) => AlertModel.fromDoc(d));

      final combined = [...alertsFromDB, ...notifsFromDB]
        // Apply client-side target filtering for notifications
        .where((msg) {
          if (!msg.isAdminMessage) return true;
          final tgt = msg.target?.toLowerCase() ?? '';
          if (tgt == 'all users' || tgt == 'all' || tgt.isEmpty) return true;
          if (tgt.contains(widget.userId.toLowerCase())) return true;
          return false;
        }).toList();

      // Sort recent first
      combined.sort((a, b) => (b.timestamp ?? DateTime.now())
          .compareTo(a.timestamp ?? DateTime.now()));

      _historicalAlerts = combined;
      _updateMergedAlerts();
      
      setState(() {
        _isLoaded = true;
      });
    } catch (error) {
      debugPrint('Alerts fetch error: $error');
      if (mounted) {
        setState(() {
          _isLoaded = true;
        });
      }
    }
  }

  void _onGlobalCacheLoadedChanged() {
    if (!mounted) return;
    setState(() {
      _isLoaded = GlobalAlertCacheService.instance.isLoadedNotifier.value;
    });
  }

  void _onGlobalCacheUpdated() {
    if (!mounted) return;
    _liveAlerts = GlobalAlertCacheService.instance.alertsNotifier.value;
    _updateMergedAlerts();
    
    setState(() {
      _isLoaded = GlobalAlertCacheService.instance.isLoadedNotifier.value;
    });
  }

  void _updateMergedAlerts() {
    final Map<String, AlertModel> merged = {};
    for (var a in _historicalAlerts) {
      merged[a.id] = a;
    }
    for (var a in _liveAlerts) {
      merged[a.id] = a; // Live overrides historical (optimistic + active changes)
    }
    
    _processAlertsData(merged.values.toList());
  }

  Future<void> _processAlertsData(List<AlertModel> newAlerts) async {
    // Sort recent first
    newAlerts.sort((a, b) => (b.timestamp ?? DateTime.now())
        .compareTo(a.timestamp ?? DateTime.now()));

    // ── Merge local optimistic state ──
    for (int i = 0; i < newAlerts.length; i++) {
      final alert = newAlerts[i];
      if (_resolvingIds.contains(alert.id)) {
        final localCopy = _allAlerts.where((a) => a.id == alert.id).firstOrNull;
        if (localCopy != null) {
          newAlerts[i] = localCopy;
        }
      }
    }

    // Sound & Popup for new alerts — skip on initial load
    bool playSound = false;
    for (final alert in newAlerts) {
      if (alert.isActive && !_shownAlertIds.contains(alert.id)) {
        _shownAlertIds.add(alert.id);
        // Only play sound for alerts arriving AFTER the first data fetch
        if (_isLoaded) playSound = true;
      }
    }

    if (playSound) {
      try {
        await _player.stop();
        await _player.play(AssetSource('sounds/alert_sound.mp3'));
      } catch (e) {
        debugPrint('Error playing alert sound: $e');
      }
    }

    // Only update if actually changed (prevents flickering)
    bool changed = newAlerts.length != _allAlerts.length || playSound;
    if (!changed) {
      for (int i = 0; i < newAlerts.length; i++) {
        if (newAlerts[i].id != _allAlerts[i].id || newAlerts[i].status != _allAlerts[i].status) {
          changed = true;
          break;
        }
      }
    }

    if (changed || !_isLoaded) {
      if (mounted) {
        setState(() {
          _allAlerts = newAlerts;
          _isLoaded = true;
        });
        if (!_entranceController.isCompleted) {
          _entranceController.forward(from: 0.0);
        }
      }
    }

    // Mark all active alerts as "seen" — user is viewing the Alerts tab
    final activeIds = newAlerts.where((a) => a.isActive).map((a) => a.id).toList();
    UnseenAlertService.instance.markAllSeen(activeIds);
  }

  @override
  void dispose() {
    GlobalAlertCacheService.instance.alertsNotifier.removeListener(_onGlobalCacheUpdated);
    GlobalAlertCacheService.instance.isLoadedNotifier.removeListener(_onGlobalCacheLoadedChanged);
    _alertsSub?.cancel();
    _entranceController.dispose();
    _player.dispose();
    super.dispose();
  }

  /// Filtered alert list based on selected tab
  List<AlertModel> get _filteredAlerts {
    switch (_selectedFilter) {
      case _FilterTab.all:
        return _allAlerts;
      case _FilterTab.admin:
        return _allAlerts.where((a) => a.isAdminMessage).toList();
      case _FilterTab.critical:
        return _allAlerts
            .where((a) => a.category == AlertCategory.critical)
            .toList();
      case _FilterTab.warning:
        return _allAlerts
            .where((a) => a.category == AlertCategory.warning)
            .toList();
      case _FilterTab.info:
        return _allAlerts
            .where((a) => a.category == AlertCategory.info)
            .toList();
      case _FilterTab.resolved:
        return _allAlerts.where((a) => a.isResolved).toList();
    }
  }

  Future<void> _resolveAlert(AlertModel alert) async {
    // ── Guard: prevent double-tap ──
    if (_resolvingIds.contains(alert.id)) return;

    setState(() {
      _resolvingIds.add(alert.id);
    });

    // ── Optimistic update: mutate local state instantly ──
    final resolvedCopy = alert.copyWith(
      status: AlertStatus.resolved,
      resolvedAt: DateTime.now(),
    );

    setState(() {
      final idx = _allAlerts.indexWhere((a) => a.id == alert.id);
      if (idx != -1) {
        _allAlerts[idx] = resolvedCopy;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Alert marked as resolved'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    // ── Play resolved sound ──
    SoundService.instance.playAlertResolved();

    // ── Firebase write (background) ──
    try {
      await FirebaseService.instance.resolveAlert(alert.id, resolverUid: FirebaseService.instance.currentUid);
    } catch (e) {
      debugPrint('Failed to resolve alert: $e');
      if (mounted) {
        setState(() {
          final idx = _allAlerts.indexWhere((a) => a.id == alert.id);
          if (idx != -1) {
            _allAlerts[idx] = alert;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to resolve alert. Please try again.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _resolvingIds.remove(alert.id);
        });
      }
    }
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

          // Date Picker removed in favor of sectioned list
          const SizedBox(height: 12),

          // 2. Filter Tabs
          _buildFilterTabs(),

          const SizedBox(height: 8),

          // 3. Alert count summary
          _buildCountBar(),

          // 4. Alert List
          Expanded(
            child: !_isLoaded
                ? _buildLoadingState()
                : _filteredAlerts.isEmpty
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
    final activeCount = _allAlerts.where((a) => a.isActive).length;

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
                  'Alerts',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Monitor safety events',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Active count badge
          if (activeCount > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$activeCount active',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 2. FILTER TABS
  // ════════════════════════════════════════════════════════════════

  Widget _buildFilterTabs() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: _FilterTab.values.map((tab) {
          final isSelected = _selectedFilter == tab;
          final count = _countForTab(tab);

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Material(
              color: isSelected ? tab.activeColor : Colors.white,
              borderRadius: BorderRadius.circular(22),
              elevation: isSelected ? 0 : 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedFilter = tab);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected
                          ? tab.activeColor
                          : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tab.emoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : tab.activeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : tab.activeColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  int _countForTab(_FilterTab tab) {
    switch (tab) {
      case _FilterTab.all:
        return _allAlerts.length;
      case _FilterTab.admin:
        return _allAlerts.where((a) => a.isAdminMessage).length;
      case _FilterTab.critical:
        return _allAlerts
            .where((a) => a.category == AlertCategory.critical)
            .length;
      case _FilterTab.warning:
        return _allAlerts
            .where((a) => a.category == AlertCategory.warning)
            .length;
      case _FilterTab.info:
        return _allAlerts
            .where((a) => a.category == AlertCategory.info)
            .length;
      case _FilterTab.resolved:
        return _allAlerts.where((a) => a.isResolved).length;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // 3. COUNT BAR
  // ════════════════════════════════════════════════════════════════

  Widget _buildCountBar() {
    final count = _filteredAlerts.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Text(
        '$count ${_selectedFilter == _FilterTab.all ? 'total' : _selectedFilter.label.toLowerCase()} alert${count == 1 ? '' : 's'}',
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 4. ALERT LIST
  // ════════════════════════════════════════════════════════════════

  String _getDateGroupKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Widget _buildAlertList() {
    final alerts = _filteredAlerts;

    // Group by Date
    final Map<String, List<AlertModel>> grouped = {};
    for (var a in alerts) {
      final key = _getDateGroupKey(a.timestamp ?? DateTime.now());
      grouped.putIfAbsent(key, () => []).add(a);
    }

    final children = <Widget>[];
    int globalIndex = 0;

    for (final entry in grouped.entries) {
      // Header
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 0, 12),
          child: Text(
            entry.key,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
      );

      // Items
      for (final alert in entry.value) {
        final index = globalIndex++;
        final delay = (index * 0.08).clamp(0.0, 0.6);
        final end = (delay + 0.4).clamp(0.0, 1.0);

        children.add(
          AnimatedBuilder(
            animation: _entranceController,
            builder: (context, child) {
              final t = Curves.easeOutCubic.transform(
                ((_entranceController.value - delay) / (end - delay)).clamp(0.0, 1.0),
              );
              return Transform.translate(
                offset: Offset(0, 20 * (1 - t)),
                child: Opacity(opacity: t, child: child),
              );
            },
            child: _PremiumAlertCard(
              alert: alert,
              isResolving: _resolvingIds.contains(alert.id),
              onResolve: () => _resolveAlert(alert),
            ),
          ),
        );
      }
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: children,
    );
  }

  // ════════════════════════════════════════════════════════════════
  // LOADING & EMPTY STATES
  // ════════════════════════════════════════════════════════════════

  Widget _buildLoadingState() {
    return const GlobalLoader(isFullScreen: false);
  }

  Widget _buildEmptyState() {
    final isFiltered = _selectedFilter != _FilterTab.all;

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
                color: (isFiltered
                        ? _selectedFilter.activeColor
                        : AppColors.success)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                isFiltered
                    ? Icons.filter_alt_off_rounded
                    : Icons.check_circle_outline_rounded,
                size: 40,
                color: isFiltered
                    ? _selectedFilter.activeColor
                    : AppColors.success,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isFiltered
                  ? 'No ${_selectedFilter.label} Alerts'
                  : 'All Clear!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'No alerts match this filter.\nTry a different category.'
                  : 'No alerts found.\nYour patients are safe.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 20),
              Material(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selectedFilter = _FilterTab.all),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text(
                      'Show All Alerts',
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
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FILTER TAB ENUM
// ══════════════════════════════════════════════════════════════════════════════

enum _FilterTab {
  all,
  admin,
  critical,
  warning,
  info,
  resolved;

  String get label {
    switch (this) {
      case _FilterTab.all:
        return 'All';
      case _FilterTab.admin:
        return 'Admin';
      case _FilterTab.critical:
        return 'Critical';
      case _FilterTab.warning:
        return 'Warning';
      case _FilterTab.info:
        return 'Info';
      case _FilterTab.resolved:
        return 'Resolved';
    }
  }

  String get emoji {
    switch (this) {
      case _FilterTab.all:
        return '📋';
      case _FilterTab.admin:
        return '🏢';
      case _FilterTab.critical:
        return '🚨';
      case _FilterTab.warning:
        return '⚠️';
      case _FilterTab.info:
        return 'ℹ️';
      case _FilterTab.resolved:
        return '✅';
    }
  }

  Color get activeColor {
    switch (this) {
      case _FilterTab.all:
        return AppColors.primary;
      case _FilterTab.admin:
        return const Color(0xFF8B5CF6);
      case _FilterTab.critical:
        return AppColors.danger;
      case _FilterTab.warning:
        return AppColors.warning;
      case _FilterTab.info:
        return const Color(0xFF3B82F6);
      case _FilterTab.resolved:
        return AppColors.success;
    }
  }
}

class _TimeSection {
  final String title;
  final List<AlertModel> alerts;
  _TimeSection(this.title, this.alerts);
}

// ══════════════════════════════════════════════════════════════════════════════
// PREMIUM ALERT CARD
// ══════════════════════════════════════════════════════════════════════════════

class _PremiumAlertCard extends StatefulWidget {
  final AlertModel alert;
  final bool isResolving;
  final VoidCallback? onResolve;

  const _PremiumAlertCard({
    required this.alert,
    this.isResolving = false,
    this.onResolve,
  });

  @override
  State<_PremiumAlertCard> createState() => _PremiumAlertCardState();
}

class _PremiumAlertCardState extends State<_PremiumAlertCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final isResolved = alert.isResolved;
    final accentColor = alert.isAdminMessage ? const Color(0xFF8B5CF6) : alert.categoryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          HapticFeedback.lightImpact();
          _showAlertDetail(context, alert, widget.isResolving, widget.onResolve);
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isResolved ? 0.7 : 1.0,
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
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      alert.typeIcon,
                      color: accentColor,
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
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isResolved
                                      ? AppColors.textMuted
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            // Status badge
                            if (!alert.isActive && !alert.isAdminMessage)
                              _StatusBadge(
                                label: alert.statusLabel,
                                color: alert.statusColor,
                                isActive: alert.isActive,
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Description sub
                        Text(
                          alert.typeLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isResolved
                                ? AppColors.textMuted.withValues(alpha: 0.7)
                                : AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Bottom row — time + priority
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
                              style: TextStyle(
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
                                color: accentColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                alert.isAdminMessage ? 'ADMIN' : alert.category.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppColors.textMuted.withValues(alpha: 0.4),
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

  void _showAlertDetail(BuildContext context, AlertModel alert, bool isResolving, VoidCallback? onResolve) {
    final accentColor = alert.categoryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Icon + title
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(alert.typeIcon, color: accentColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.description,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (!(alert.isActive && alert.category != AlertCategory.critical) && !alert.isAdminMessage)
                        _StatusBadge(
                          label: alert.statusLabel,
                          color: alert.statusColor,
                          isActive: alert.isActive,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Description
            Text(
              alert.typeLabel,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // Info grid
            _detailRow(Icons.schedule_rounded, 'Time',
                alert.formattedTime.isNotEmpty ? alert.formattedTime : alert.timeAgo),
            const SizedBox(height: 12),
            if (!alert.isAdminMessage) ...[
              _detailRow(Icons.warning_amber_rounded, 'Priority',
                  alert.priorityLabel),
              const SizedBox(height: 12),
              _detailRow(Icons.category_rounded, 'Category',
                  alert.category.name.toUpperCase()),
            ],
            if (alert.isResolved && alert.resolvedAt != null) ...[
              const SizedBox(height: 12),
              _detailRow(Icons.check_circle_rounded, 'Resolved at',
                  _formatDateTime(alert.resolvedAt!)),
            ],
            const SizedBox(height: 24),


          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hour12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour12:$m $ampm';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STATUS BADGE
// ══════════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
