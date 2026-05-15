// ════════════════════════════════════════════════════════════════
  // 1. GRADIENT HEADER & PROFILE MODAL
  // ════════════════════════════════════════════════════════════════

  Widget _buildGradientHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.dashboardGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 20, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_greeting 👋',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Clickable Elderly Name
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (_selectedElderly != null) {
                          _showElderlyProfileModal(context, _selectedElderly!);
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedElderly?.name ?? 'Elderly Profile',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _blinkAnimation,
                            builder: (context, child) => Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? AppColors.success.withValues(alpha: _blinkAnimation.value)
                                    : Colors.orange.withValues(alpha: _blinkAnimation.value),
                                shape: BoxShape.circle,
                                boxShadow: isConnected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.success.withValues(alpha: _blinkAnimation.value * 0.6),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isConnected ? 'Monitoring Active' : 'Connecting...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Stack(
                clipBehavior: Clip.none,
                children: [
                  _HeaderIconButton(
                    icon: Icons.notifications_outlined,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onSwitchTab?.call(1);
                    },
                  ),
                  if (widget.activeAlertsCount != null && widget.activeAlertsCount!.value > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: ValueListenableBuilder<int>(
                            valueListenable: widget.activeAlertsCount!,
                            builder: (context, count, child) {
                              return Text(
                                '$count',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    )
                  else if (_cachedAlerts.where((a) => a.isActive).isNotEmpty)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${_cachedAlerts.where((a) => a.isActive).length}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showElderlyProfileModal(BuildContext context, UserModel elderly) {
    int age = _calculateAge(elderly.dateOfBirth);
    String ageStr = age > 0 ? '$age yrs' : 'N/A';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    top: -50,
                    right: -50,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primarySoft.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -40,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondarySoft.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    elderly.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    'Age: $ageStr',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        _modalInfoRow(Icons.phone_rounded, 'Phone', elderly.phone.isNotEmpty ? elderly.phone : 'Not Available'),
                        const SizedBox(height: 12),
                        _modalInfoRow(Icons.email_rounded, 'Email', elderly.email.isNotEmpty ? elderly.email : 'Not Available'),
                        const SizedBox(height: 12),
                        _modalInfoRow(Icons.home_rounded, 'Address', elderly.address ?? 'Not Available'),
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(color: AppColors.border),
                        ),
                        
                        Row(
                          children: [
                            Expanded(child: _modalMiniCard(Icons.bloodtype_rounded, 'Blood Gro...', elderly.bloodGroup ?? 'N/A', AppColors.danger)),
                            const SizedBox(width: 10),
                            Expanded(child: _modalMiniCard(Icons.accessible_rounded, 'Mobility', elderly.mobilityStatus ?? 'N/A', AppColors.info)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _modalMiniCard(Icons.medical_information_rounded, 'Medical Conditions', elderly.medicalConditions ?? 'None reported', AppColors.primary),
                        
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8 * anim1.value, sigmaY: 8 * anim1.value),
          child: FadeTransition(
            opacity: anim1,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _modalInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modalMiniCard(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 2. LIVE STATUS CARD
  // ════════════════════════════════════════════════════════════════

  Widget _buildLiveStatusCard() {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle('Live Status', Icons.monitor_heart_outlined),
              const Spacer(),
              AnimatedBuilder(
                animation: _blinkAnimation,
                builder: (context, child) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08 + _blinkAnimation.value * 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: _blinkAnimation.value),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statusGridItem(
                  icon: Icons.person_rounded,
                  label: 'Presence',
                  value: isConnected ? _sensorData.presenceLabel : '--',
                  color: !isConnected ? AppColors.textMuted : (_sensorData.presence ? AppColors.success : AppColors.warning),
                  description: !isConnected ? 'Sensor is offline. Cannot determine presence.' : (_sensorData.presence ? 'User is currently present in the monitored area.' : 'No user presence detected in the monitored area.'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statusGridItem(
                  icon: Icons.sensors_rounded,
                  label: 'Sensor',
                  value: isConnected ? 'Online' : 'Offline',
                  color: isConnected ? AppColors.success : AppColors.danger,
                  description: isConnected ? 'Device is online and actively sending real-time data.' : 'Device is offline and disconnected. Please check device power and connectivity.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _statusGridItem(
                  icon: Icons.swap_vert_rounded,
                  label: 'Position',
                  value: isConnected ? _sensorData.positionLabel : '--',
                  color: !isConnected ? AppColors.textMuted : AppColors.success,
                  description: !isConnected ? 'Sensor is offline. Cannot track position.' : 'User is currently ${_sensorData.positionLabel.toLowerCase()}.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statusGridItem(
                  icon: Icons.air_rounded,
                  label: 'Respiration',
                  value: isConnected ? _sensorData.breathingLabel : '--',
                  color: !isConnected ? AppColors.textMuted : (_sensorData.abnormalBreathing ? AppColors.danger : AppColors.success),
                  description: !isConnected ? 'Sensor is offline. Cannot track respiration.' : (_sensorData.abnormalBreathing ? 'Breathing rate is abnormal. Please monitor the user.' : 'Breathing rate is within normal range.'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusGridItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String description,
  }) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          _showStatusDialog(
            context,
            title: label,
            value: value,
            icon: icon,
            color: color,
            description: description,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusDialog(BuildContext context, {required String title, required String value, required IconData icon, required Color color, required String description}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 40, offset: const Offset(0, 20)),
                const BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(top: -50, right: -50, child: Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.07)))),
                  Positioned(bottom: -30, left: -40, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.05)))),
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 8)),
                              BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8, spreadRadius: -2, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Container(margin: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 36)),
                        ),
                        const SizedBox(height: 24),
                        Text('$title Status', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.25), width: 1)),
                          child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
                        ),
                        const SizedBox(height: 20),
                        Text(description, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.textSecondary.withValues(alpha: 0.9), height: 1.5, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () { HapticFeedback.lightImpact(); Navigator.pop(ctx); },
                            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            child: const Text('Got it', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(top: 12, right: 12, child: IconButton(onPressed: () { HapticFeedback.lightImpact(); Navigator.pop(ctx); }, icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22))),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return BackdropFilter(filter: ImageFilter.blur(sigmaX: 12 * anim1.value, sigmaY: 12 * anim1.value), child: FadeTransition(opacity: anim1, child: ScaleTransition(scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic), child: child)));
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 3. VITAL SIGNS CARD
  // ════════════════════════════════════════════════════════════════

  Widget _buildVitalSignsCard() {
    final hrValue = isConnected ? _sensorData.heartRate : 0;
    final brValue = isConnected ? _sensorData.breathingRate : 0.0;
    final hrNormal = hrValue >= 50 && hrValue <= 100;
    final brNormal = brValue >= 10 && brValue <= 24;
    final hrColor = !isConnected ? AppColors.textMuted : (hrNormal ? AppColors.success : AppColors.danger);
    final brColor = !isConnected ? AppColors.textMuted : (_sensorData.abnormalBreathing ? AppColors.danger : (brNormal ? AppColors.success : AppColors.warning));

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle('Vital Signs', Icons.favorite_rounded),
              const Spacer(),
              if (_sensorData.abnormalBreathing && isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_rounded, color: AppColors.danger, size: 14),
                      const SizedBox(width: 4),
                      Text(_sensorData.abnormalReason.isNotEmpty ? _sensorData.abnormalReason : 'Abnormal', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _vitalBlock(icon: Icons.favorite_rounded, label: 'Heart Rate', value: isConnected ? '$hrValue' : '--', unit: 'BPM', color: hrColor, sparkline: _hrHistory)),
              Container(width: 1, height: 80, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
              Expanded(child: _vitalBlock(icon: Icons.air_rounded, label: 'Respiration', value: isConnected ? brValue.toStringAsFixed(0) : '--', unit: '/min', color: brColor, sparkline: _brHistory)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vitalBlock({required IconData icon, required String label, required String value, required String unit, required Color color, List<double>? sparkline}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: double.tryParse(value) ?? 0.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, animVal, _) => Text(
                animVal.toStringAsFixed(0),
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: color, height: 1.0),
              ),
            ),
            const SizedBox(width: 4),
            Text(unit, style: TextStyle(fontSize: 14, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
          ],
        ),
        if (sparkline != null && sparkline.length > 3) ...[
          const SizedBox(height: 10),
          SizedBox(height: 28, child: CustomPaint(size: const Size(double.infinity, 28), painter: _SparklinePainter(sparkline, color))),
        ],
      ],
    );
  }
