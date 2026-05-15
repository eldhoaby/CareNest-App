const fs = require('fs');

const elderlyPath = process.cwd() + '/lib/screens/elderly/elderly_home_tab.dart';
const caregiverPath = process.cwd() + '/lib/screens/caregiver/caregiver_home_tab.dart';

let content = fs.readFileSync(elderlyPath, 'utf8');

// 1. Replace imports and setup
content = content.replace(/ElderlyHomeTab/g, 'CaregiverHomeTab');
content = content.replace('ELDERLY HOME TAB', 'CAREGIVER HOME TAB');
content = content.replace(
    "import '../../widgets/premium/premium_animated_button.dart';",
    "import '../../widgets/premium/premium_animated_button.dart';\nimport '../../models/user_model.dart';"
);

// 2. Modify class declaration
content = content.replace(
    /class CaregiverHomeTab extends StatefulWidget \{[\s\S]*?State<CaregiverHomeTab> createState\(\) => _CaregiverHomeTabState\(\);\n\}/,
    `class CaregiverHomeTab extends StatefulWidget {\n  final Function(int)? onSwitchTab;\n  final ValueNotifier<int>? activeAlertsCount;\n\n  const CaregiverHomeTab({\n    super.key,\n    this.onSwitchTab,\n    this.activeAlertsCount,\n  });\n\n  @override\n  State<CaregiverHomeTab> createState() => _CaregiverHomeTabState();\n}`
);

// 3. Add state variables
const stateVarsInject = `  String _caregiverName = 'Caregiver';
  List<UserModel> _linkedElderlies = [];
  UserModel? _selectedElderly;
  bool _profileLoaded = false;
  StreamSubscription? _profileSub;

`;
content = content.replace('  // ── Animations ──────────────────────────────────────────────────', stateVarsInject + '  // ── Animations ──────────────────────────────────────────────────');

// 4. Modify initState / dispose
const initStateFind = `    _cardStaggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _startSensorStream();
    _startAlertsStream();

    // Tick every second for relative timestamps & inactivity timer`;
const initStateReplace = `    _cardStaggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _startProfileStream();

    // Tick every second for relative timestamps & inactivity timer`;
content = content.replace(initStateFind, initStateReplace);

const startProfileStreamCode = `

  void _startProfileStream() {
    _profileSub = FirebaseService.instance.userProfileStream().listen((snapshot) async {
      if (!mounted) return;
      final data = snapshot.data();
      if (data == null) return;

      List<String> linkedUids = [];
      if (data['linkedElderlyUids'] is List) {
        linkedUids = List<String>.from(data['linkedElderlyUids']);
      } else if (data['linkedElderlyUid'] != null) {
        linkedUids = [data['linkedElderlyUid']];
      }
      
      List<UserModel> elderlies = [];
      for (String uid in linkedUids) {
        final user = await FirebaseService.instance.getLinkedElderly(uid);
        if (user != null) {
          elderlies.add(user);
        }
      }

      if (mounted) {
        setState(() {
          _caregiverName = data['name'] ?? 'Caregiver';
          _linkedElderlies = elderlies;
          if (_selectedElderly == null || !elderlies.any((e) => e.uid == _selectedElderly!.uid)) {
            _selectedElderly = elderlies.isNotEmpty ? elderlies.first : null;
            if (_selectedElderly != null) {
              _startAlertsStream();
              _startSensorStream();
            }
          }
          _profileLoaded = true;
        });
      }
    });
  }`;
content = content.replace('  void _startSensorStream() {', startProfileStreamCode + '\n\n  void _startSensorStream() {');

content = content.replace('    _sensorSub?.cancel();\n    _alertsSub?.cancel();', '    _profileSub?.cancel();\n    _sensorSub?.cancel();\n    _alertsSub?.cancel();');

content = content.replace(/if \(widget\.userId\.isEmpty\) return;/g, 'if (_selectedElderly == null) return;');
content = content.replace(/widget\.userId/g, '_selectedElderly!.uid');

// Remove SOS method entirely
content = content.replace(/  Future<void> _sendSOS\(\) async \{[\s\S]*?  \}\n/g, '');

const alertsSubReplace = `
      final activeCount = newAlerts.where((a) => a.isActive).length;
      if (widget.activeAlertsCount != null) {
        widget.activeAlertsCount!.value = activeCount;
      }
      
      final changed = newAlerts.length != _cachedAlerts.length ||
          (newAlerts.isNotEmpty &&
              _cachedAlerts.isNotEmpty &&
              newAlerts.first.id != _cachedAlerts.first.id);

      if (changed || !_alertsLoaded) {`;
content = content.replace(/      final changed = newAlerts\.length != _cachedAlerts\.length[\s\S]*?if \(changed \|\| !_alertsLoaded\) \{/, alertsSubReplace);


// Re-route links
content = content.replace(/widget\.onNavigateToAlerts\?\.call\(\);/g, 'widget.onSwitchTab?.call(1);');
content = content.replace(/widget\.onNavigateToActivity\?\.call\(\);/g, 'widget.onSwitchTab?.call(2);');


// Modify build
const buildFind = `  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingSkeleton();
    }`;
const buildReplace = `  @override
  Widget build(BuildContext context) {
    if (!_profileLoaded || isLoading && _selectedElderly != null) {
      return _buildLoadingSkeleton();
    }
    if (_selectedElderly == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.link_off_rounded, size: 60, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Text('No Elderly Linked', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              const Text('Link an elderly account to view their dashboard.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }`;
content = content.replace(buildFind, buildReplace);


// Modify build banner
const sosRemoveFind = `                // 8. Emergency SOS
                _staggeredCard(6, _buildSOSButton()),`;
content = content.replace(sosRemoveFind, '');

// Modify SOS Widget (Remove entirely)
content = content.replace(/  \/\/ ════════════════════════════════════════════════════════════════\n  \/\/ 8\. EMERGENCY SOS BUTTON\n  \/\/ ════════════════════════════════════════════════════════════════[\s\S]*/, `}\n`);


// Ensure user.userName is replaced with Caregiver
content = content.replace(/widget\.userName\.isEmpty \? 'User' : widget\.userName/g, "_caregiverName");


// Modify Header with Dropdown
const headerFind = `                    Text(
                      _caregiverName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),`;
const headerReplace = `                    if (_linkedElderlies.length > 1)
                      DropdownButtonHideUnderline(
                        child: DropdownButton<UserModel>(
                          value: _selectedElderly,
                          dropdownColor: AppColors.primary,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5, fontFamily: 'Inter'),
                          onChanged: (UserModel? newValue) {
                            if (newValue != null && newValue.uid != _selectedElderly?.uid) {
                              setState(() {
                                _selectedElderly = newValue;
                                _sensorData = SensorData.empty;
                                _cachedAlerts = [];
                                isConnected = false;
                              });
                              _startAlertsStream();
                            }
                          },
                          items: _linkedElderlies.map((UserModel user) {
                            return DropdownMenuItem<UserModel>(
                              value: user,
                              child: Text(user.name.isNotEmpty ? user.name : 'Elderly', style: const TextStyle(color: Colors.white)),
                            );
                          }).toList(),
                        ),
                      )
                    else
                      Text(
                        _selectedElderly?.name ?? 'Elderly Profile',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),`;
content = content.replace(headerFind, headerReplace);


// Notifications Bell Badge Logic
const bellBadgeFind = `                  // Badge: show count of active (unread) alerts
                  if (_cachedAlerts.where((a) => a.isActive).isNotEmpty)`;
const bellBadgeReplace = `                  // Badge: show count of active (unread) alerts
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
                                '\${count}',
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
                  else if (_cachedAlerts.where((a) => a.isActive).isNotEmpty)`;
content = content.replace(bellBadgeFind, bellBadgeReplace);


// Make sure sensor streams get properly updated
content = content.replace('              _startAlertsStream();\n              _startSensorStream();', '              _startAlertsStream();\n              _startSensorStream();\n              isLoading = true;');
content = content.replace('                              _startAlertsStream();\n                            }\n                          },', '                              _startAlertsStream();\n                              // Note: sensor stream natively uses device assigned to elderly\n                            }\n                          },');


fs.writeFileSync(caregiverPath, content);
console.log('done');
