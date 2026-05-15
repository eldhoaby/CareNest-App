import re

elderly_path = 'd:\\aal_app\\lib\\screens\\elderly\\elderly_activity_tab.dart'
caregiver_path = 'd:\\aal_app\\lib\\screens\\caregiver\\caregiver_activity_tab.dart'

with open(elderly_path, 'r', encoding='utf-8') as f:
    elderly_content = f.read()

# 1. Replace imports and setup
content = elderly_content.replace('ElderlyActivityTab', 'CaregiverActivityTab')
content = content.replace('ELDERLY ACTIVITY TAB', 'CAREGIVER ACTIVITY TAB')
content = content.replace(
    '''import '../../widgets/premium/glass_card.dart';''',
    '''import '../../widgets/premium/glass_card.dart';\nimport '../../models/user_model.dart';'''
)

# 2. Modify class declaration
content = re.sub(
    r'class CaregiverActivityTab extends StatefulWidget \{.*?\}',
    '''class CaregiverActivityTab extends StatefulWidget {\n  const CaregiverActivityTab({super.key});\n\n  @override\n  State<CaregiverActivityTab> createState() => _CaregiverActivityTabState();\n}''',
    content,
    flags=re.DOTALL
)

# 3. Add state variables
state_vars_inject = '''  List<UserModel> _linkedElderlies = [];
  UserModel? _selectedElderly;
  bool _profileLoaded = false;
  StreamSubscription? _profileSub;

'''
content = content.replace('  // ── Sensor state ────────────────────────────────────────────────', state_vars_inject + '  // ── Sensor state ────────────────────────────────────────────────')

# 4. Modify initState / dispose
init_state_find = '''  @override
  void initState() {
    super.initState();
    _chartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _startSensorStream();
    _startAlertsStream();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }'''
init_state_replace = '''  @override
  void initState() {
    super.initState();
    _startProfileStream();
    _chartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _startSensorStream();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

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
        final doc = await FirebaseService.instance.userProfileStreamById(uid).first;
        if (doc.exists) {
          elderlies.add(UserModel.fromDoc(doc));
        }
      }

      if (mounted) {
        setState(() {
          _linkedElderlies = elderlies;
          if (_selectedElderly == null || !elderlies.any((e) => e.uid == _selectedElderly!.uid)) {
            _selectedElderly = elderlies.isNotEmpty ? elderlies.first : null;
            if (_selectedElderly != null) {
              _startAlertsStream();
            }
          }
          _profileLoaded = true;
        });
      }
    });
  }'''
content = content.replace(init_state_find, init_state_replace)

dispose_find = '''    _sensorSub?.cancel();
    _alertsSub?.cancel();'''
dispose_replace = '''    _profileSub?.cancel();
    _sensorSub?.cancel();
    _alertsSub?.cancel();'''
content = content.replace(dispose_find, dispose_replace)

# 5. Modify _startAlertsStream
start_alerts_find = '''  void _startAlertsStream() {
    if (widget.userId.isEmpty) return;

    _alertsSub = FirebaseService.instance
        .alertsStream(widget.userId)
        .listen((snapshot) {'''
start_alerts_replace = '''  void _startAlertsStream() {
    _alertsSub?.cancel();
    if (_selectedElderly == null) return;

    _alertsSub = FirebaseService.instance
        .alertsStream(_selectedElderly!.uid)
        .listen((snapshot) {'''
content = content.replace(start_alerts_find, start_alerts_replace)

# 6. Modify build() to check profileLoaded and selectedElderly
build_find = '''  @override
  Widget build(BuildContext context) {
    return SafeArea('''
build_replace = '''  @override
  Widget build(BuildContext context) {
    if (!_profileLoaded) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
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
              const Text('Link an elderly account to view activity history.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }
    return SafeArea('''
content = content.replace(build_find, build_replace)

# 7. Modify _buildHeader() to have dropdown
header_find = '''        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppColors.cardShadow,
          ),
          child: Icon(Icons.tune_rounded, size: 22, color: AppColors.textSecondary),
        ),'''
header_replace = '''        if (_linkedElderlies.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppColors.cardShadow,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<UserModel>(
                value: _selectedElderly,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                onChanged: (UserModel? newValue) {
                  if (newValue != null && newValue.uid != _selectedElderly?.uid) {
                    setState(() {
                      _selectedElderly = newValue;
                      _startAlertsStream();
                    });
                  }
                },
                items: _linkedElderlies.map((UserModel user) {
                  return DropdownMenuItem<UserModel>(
                    value: user,
                    child: Text(user.name.isNotEmpty ? user.name : 'Elderly Profile'),
                  );
                }).toList(),
              ),
            ),
          ),'''
content = content.replace(header_find, header_replace)

with open(caregiver_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("done")
