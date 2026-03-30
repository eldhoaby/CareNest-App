import 'package:flutter/material.dart';
import '../../core/services/firebase_service.dart';
import '../elderly/elderly_dashboard.dart';

class ElderlySetupScreen extends StatefulWidget {
  const ElderlySetupScreen({super.key});

  @override
  State<ElderlySetupScreen> createState() => _ElderlySetupScreenState();
}

class _ElderlySetupScreenState extends State<ElderlySetupScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Basic Info
  final _dobCtrl = TextEditingController();
  String? _gender;
  bool get _step1Valid => _dobCtrl.text.isNotEmpty && _gender != null;

  // Step 2: Health Info
  final _medicalCtrl = TextEditingController();
  String? _mobility;
  bool get _step2Valid => _medicalCtrl.text.isNotEmpty && _mobility != null;

  // Step 3: Linking
  final _linkCtrl = TextEditingController();
  bool _step3Valid = false;
  // Step 3 optional technically, but we enforce something string-wise
  void _validateStep3() {
    setState(() {
      _step3Valid = _linkCtrl.text.trim().isNotEmpty;
    });
  }

  // Step 4: Emergency Info
  final _emContactNameCtrl = TextEditingController();
  final _emContactPhoneCtrl = TextEditingController();
  String? _bloodGroup;
  bool get _step4Valid =>
      _emContactNameCtrl.text.trim().length >= 2 &&
      RegExp(r'^\d{10}$').hasMatch(_emContactPhoneCtrl.text.trim()) &&
      _bloodGroup != null;

  // Step 5: Permissions
  bool _locPerm = false;
  bool _notifPerm = false;
  // Step 5 valid without mandatory trues, but we encourage it
  bool get _step5Valid => true;

  @override
  void initState() {
    super.initState();
    _linkCtrl.addListener(_validateStep3);
    _emContactNameCtrl.addListener(() => setState(() {}));
    _emContactPhoneCtrl.addListener(() => setState(() {}));
    _medicalCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _dobCtrl.dispose();
    _medicalCtrl.dispose();
    _linkCtrl.dispose();
    _emContactNameCtrl.dispose();
    _emContactPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(1960),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF6366F1)),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _dobCtrl.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _submitStep() async {
    setState(() => _isLoading = true);
    final fs = FirebaseService.instance;

    try {
      if (_currentStep == 0) {
        await fs.saveSetupStep({'dateOfBirth': _dobCtrl.text, 'gender': _gender});
      } else if (_currentStep == 1) {
        await fs.saveSetupStep({'medicalConditions': _medicalCtrl.text, 'mobilityStatus': _mobility});
      } else if (_currentStep == 2) {
        // Handle linking (code or phone)
        final input = _linkCtrl.text.trim();
        await fs.saveSetupStep({'caregiverPhone': input}); // store reference

        if (RegExp(r'^\d{10}$').hasMatch(input)) {
          final cgUid = await fs.lookupCaregiverByPhone(input);
          if (cgUid != null && fs.currentUid != null) {
            await fs.sendLinkRequest(fromUid: fs.currentUid!, toUid: cgUid, fromRole: 'elderly');
          }
        }
      } else if (_currentStep == 3) {
        await fs.saveSetupStep({
          'emergencyContactName': _emContactNameCtrl.text,
          'emergencyContactPhone': _emContactPhoneCtrl.text,
          'bloodGroup': _bloodGroup,
        });
      } else if (_currentStep == 4) {
        await fs.saveSetupStep({
          'locationSharing': _locPerm,
          'notificationsEnabled': _notifPerm,
        });
        
        // Finalize
        await fs.completeSetup();
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ElderlyDashboard()));
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep++;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  bool _isCurrentStepValid() {
    switch (_currentStep) {
      case 0: return _step1Valid;
      case 1: return _step2Valid;
      case 2: return _step3Valid;
      case 3: return _step4Valid;
      case 4: return _step5Valid;
      default: return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Setup Complete Profile', style: TextStyle(color: Color(0xFF1E1B4B), fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E1B4B)),
                onPressed: () => setState(() => _currentStep--),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            LinearProgressIndicator(
              value: (_currentStep + 1) / 5,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Step ${_currentStep + 1} of 5', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                  _stepTitle(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildCurrentStep(),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _stepTitle() {
    final titles = ['Basic Info', 'Health Info', 'Link Caregiver', 'Emergency Info', 'Permissions'];
    return Text(titles[_currentStep], style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500));
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildStep1();
      case 1: return _buildStep2();
      case 2: return _buildStep3();
      case 3: return _buildStep4();
      case 4: return _buildStep5();
      default: return const SizedBox();
    }
  }

  // ── Step 1 ──────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Basic Information', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Let us know a bit more about you.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        
        // DOB
        const Text('Date of Birth', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: AbsorbPointer(
            child: TextFormField(
              controller: _dobCtrl,
              decoration: _inputDeco('Select Date', Icons.calendar_month),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Gender
        const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _gender,
          decoration: _inputDeco('Select Gender', Icons.person),
          items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (v) => setState(() => _gender = v),
        ),
      ],
    );
  }

  // ── Step 2 ──────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Health Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('This helps us tune monitoring sensitivity.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        
        const Text('Existing Medical Conditions', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _medicalCtrl,
          maxLines: 3,
          decoration: _inputDeco('E.g., Hypertension, Diabetes', Icons.local_hospital_outlined),
        ),
        if (_medicalCtrl.text.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Required', style: TextStyle(fontSize: 12, color: Colors.red)),
          ),
          
        const SizedBox(height: 24),
        
        const Text('Mobility Status', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _mobility,
          decoration: _inputDeco('Select Status', Icons.directions_walk),
          items: ['Independent', 'Uses cane/walker', 'Wheelchair', 'Bedbound']
              .map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => setState(() => _mobility = v),
        ),
      ],
    );
  }

  // ── Step 3 ──────────────────────────────────────────────────
  Widget _buildStep3() {
    final validPhone = RegExp(r'^\d{10}$').hasMatch(_linkCtrl.text.trim());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Link Caregiver', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Who should be notified in an emergency?', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        
        const Text('Caregiver Phone or Invite Code', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _linkCtrl,
          decoration: _inputDeco('10-digit phone or code', Icons.link_rounded)
              .copyWith(suffixIcon: validPhone ? const Icon(Icons.check_circle, color: Colors.green) : null),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
          child: const Row(
            children: [
              Icon(Icons.info, color: Color(0xFF6366F1), size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('We will send a linking request securely to this caregiver.', style: TextStyle(fontSize: 13))),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 4 ──────────────────────────────────────────────────
  Widget _buildStep4() {
    final phoneValid = RegExp(r'^\d{10}$').hasMatch(_emContactPhoneCtrl.text.trim());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Emergency Info', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Crucial data for emergency responders.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        
        const Text('Emergency Contact Name', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emContactNameCtrl,
          decoration: _inputDeco('Full Name', Icons.person_outline),
        ),
        
        const SizedBox(height: 24),
        
        const Text('Emergency Contact Number', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emContactPhoneCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: _inputDeco('10 digit number', Icons.phone)
              .copyWith(suffixIcon: phoneValid ? const Icon(Icons.check_circle, color: Colors.green) : null),
        ),
        
        const SizedBox(height: 16),
        
        const Text('Blood Group', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _bloodGroup,
          decoration: _inputDeco('Select Blood Group', Icons.bloodtype),
          items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
              .map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
          onChanged: (v) => setState(() => _bloodGroup = v),
        ),
      ],
    );
  }

  // ── Step 5 ──────────────────────────────────────────────────
  Widget _buildStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Permissions', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Required for AAL background features.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        
        SwitchListTile(
          title: const Text('Location Access', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Needed for geo-fencing and SOS features.'),
          value: _locPerm,
          activeThumbColor: const Color(0xFF6366F1),
          onChanged: (v) => setState(() => _locPerm = v),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Enable Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Allow critical alerts to wake device.'),
          value: _notifPerm,
          activeThumbColor: const Color(0xFF6366F1),
          onChanged: (v) => setState(() => _notifPerm = v),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isCurrentStepValid() && !_isLoading ? _submitStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_currentStep == 4 ? 'Complete Setup' : 'Continue', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
    );
  }
}
