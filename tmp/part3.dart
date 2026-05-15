  // ════════════════════════════════════════════════════════════════
  // 4. SMART STATUS CARD
  // ════════════════════════════════════════════════════════════════

  Widget _buildSmartStatusCard() {
    final alertPhase = AlertService.instance.overallPhase;
    final message = AlertService.instance.smartMessage;

    Color bgColor;
    Color accentColor;
    IconData icon;
    String phaseLabel;

    switch (alertPhase) {
      case AlertPhase.critical:
        bgColor = const Color(0xFFFEE2E2);
        accentColor = AppColors.danger;
        icon = Icons.warning_rounded;
        phaseLabel = '🔴 Critical';
        break;
      case AlertPhase.warning:
        bgColor = const Color(0xFFFEF3C7);
        accentColor = AppColors.warning;
        icon = Icons.info_rounded;
        phaseLabel = '🟡 Warning';
        break;
      case AlertPhase.normal:
        bgColor = AppColors.primarySoft.withValues(alpha: 0.1);
        accentColor = AppColors.primarySoft;
        icon = Icons.psychology_rounded;
        phaseLabel = '🟢 Normal';
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: accentColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Smart Insight', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor.withValues(alpha: 0.7), letterSpacing: 0.5)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(phaseLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accentColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: Text(message, key: ValueKey(message), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: accentColor, height: 1.3)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 5. ALERTS PREVIEW
  // ════════════════════════════════════════════════════════════════

  Widget _buildAlertsPreview() {
    if (_selectedElderly == null || _selectedElderly!.uid.isEmpty) return const SizedBox.shrink();

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle('Alerts', Icons.notifications_active_outlined)),
              Material(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () { HapticFeedback.lightImpact(); widget.onSwitchTab?.call(1); },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('See all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        SizedBox(width: 4), Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: !_alertsLoaded
                ? const _SkeletonBlock(height: 60)
                : _cachedAlerts.isEmpty
                    ? Container(
                        key: const ValueKey('empty'),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                            SizedBox(width: 10),
                            Text('No alerts — all clear!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          ],
                        ),
                      )
                    : Column(
                        key: ValueKey('alerts_${_cachedAlerts.length}_${_cachedAlerts.first.id}'),
                        children: _cachedAlerts.take(2).map((alert) => _alertPreviewRow(alert)).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _alertPreviewRow(AlertModel alert) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: alert.isActive ? alert.priorityColor.withValues(alpha: 0.05) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () { HapticFeedback.lightImpact(); widget.onSwitchTab?.call(1); },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border(left: BorderSide(color: alert.priorityColor, width: 3))),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: alert.priorityColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(alert.typeIcon, color: alert.priorityColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.typeLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(alert.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(alert.timeAgo, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                    if (alert.isActive) Container(margin: const EdgeInsets.only(top: 4), width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 6. ACTIVITY SUMMARY
  // ════════════════════════════════════════════════════════════════

  Widget _buildActivitySummary() {
    final today = DateTime.now();
    final alertsTodayCount = _cachedAlerts.where((a) => a.timestamp != null && a.timestamp!.year == today.year && a.timestamp!.month == today.month && a.timestamp!.day == today.day).length;

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle('Activity', Icons.directions_run_rounded)),
              Material(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () { HapticFeedback.lightImpact(); widget.onSwitchTab?.call(2); },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        SizedBox(width: 4), Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _infoRow(icon: Icons.directions_run_rounded, label: 'Active Time', value: '1h 30m', valueColor: AppColors.success),
          const Divider(height: 24, color: Color(0xFFF0F0F0)),
          _infoRow(icon: Icons.directions_walk_rounded, label: 'Movement Time', value: '45 min', valueColor: AppColors.primary),
          const Divider(height: 24, color: Color(0xFFF0F0F0)),
          _infoRow(icon: Icons.warning_rounded, label: 'Alerts Today', value: alertsTodayCount.toString(), valueColor: alertsTodayCount > 0 ? AppColors.danger : AppColors.textSecondary),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 7. SLEEP STATUS CARD
  // ════════════════════════════════════════════════════════════════

  Widget _buildSleepCard() {
    final isSleeping = _sensorData.isSleeping;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSleeping ? AppColors.primarySoft.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSleeping ? AppColors.primarySoft.withValues(alpha: 0.2) : AppColors.border, width: 1),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
            child: Icon(isSleeping ? Icons.bedtime_rounded : Icons.wb_sunny_rounded, color: AppColors.primarySoft, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sleep Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(isSleeping ? 'Sleeping' : 'Awake', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isSleeping ? AppColors.primarySoft : AppColors.textPrimary)),
              ],
            ),
          ),
          if (isSleeping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(_sleepDuration, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primarySoft)),
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // HELPER METHDOS
  // ════════════════════════════════════════════════════════════════

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _infoRow({required IconData icon, required String label, required String value, required Color valueColor}) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: valueColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: valueColor),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500))),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _SkeletonBlock(height: 120), SizedBox(height: 20),
            _SkeletonBlock(height: 180), SizedBox(height: 16),
            _SkeletonBlock(height: 120), SizedBox(height: 16),
            _SkeletonBlock(height: 80), SizedBox(height: 16),
            _SkeletonBlock(height: 100),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REUSABLE PRIVATE WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.white.withValues(alpha: 0.2),
        onTap: onTap,
        child: Container(width: 48, height: 48, alignment: Alignment.center, child: Icon(icon, color: Colors.white, size: 24)),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final Widget child;

  const _DashboardCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return GlassCard(padding: const EdgeInsets.all(24), borderRadius: 24, child: child);
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double height;

  const _SkeletonBlock({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final minVal = data.reduce(math.min);
    final maxVal = data.reduce(math.max);
    final range = maxVal - minVal;
    if (range == 0) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();
    final step = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * step;
      final y = size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y); fillPath.moveTo(x, size.height); fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y); fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height); fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.data.length != data.length || (data.isNotEmpty && old.data.isNotEmpty && old.data.last != data.last);
}
