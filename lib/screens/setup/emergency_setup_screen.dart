import 'package:flutter/material.dart';
import '../../core/services/firebase_service.dart';
import '../emergency/emergency_dashboard.dart';

class EmergencySetupScreen extends StatefulWidget {
  const EmergencySetupScreen({super.key});

  @override
  State<EmergencySetupScreen> createState() => _EmergencySetupScreenState();
}

class _EmergencySetupScreenState extends State<EmergencySetupScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Organization Info
  final _orgCtrl = TextEditingController();
  final _staffCtrl = TextEditingController();
  bool get _step1Valid => _orgCtrl.text.trim().length >= 2 && _staffCtrl.text.trim().length >= 2;

  // Step 2: Availability
  String? _availability;
  bool get _step2Valid => _availability != null;

  // Step 3: Capabilities
  bool _hasAmbulance = false;
  String? _emergencyTypes;
  bool get _step3Valid => _emergencyTypes != null;

  @override
  void initState() {
    super.initState();
    _orgCtrl.addListener(() => setState(() {}));
    _staffCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _orgCtrl.dispose();
    _staffCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitStep() async {
    setState(() => _isLoading = true);
    final fs = FirebaseService.instance;

    try {
      if (_currentStep == 0) {
        await fs.saveSetupStep({
          'organizationName': _orgCtrl.text.trim(),
          'staffName': _staffCtrl.text.trim(), 
        });
      } else if (_currentStep == 1) {
        await fs.saveSetupStep({'availability': _availability});
      } else if (_currentStep == 2) {
        await fs.saveSetupStep({
          'ambulanceAvailable': _hasAmbulance,
          'emergencyTypes': _emergencyTypes,
        });
        
        // Finalize
        await fs.completeSetup();
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EmergencyDashboard()));
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep++;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isCurrentStepValid() {
    switch (_currentStep) {
      case 0: return _step1Valid;
      case 1: return _step2Valid;
      case 2: return _step3Valid;
      default: return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Setup Complete Profile', style: TextStyle(color: Color(0xFFF43F5E), fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFF43F5E)),
                onPressed: () => setState(() => _currentStep--),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            LinearProgressIndicator(
              value: (_currentStep + 1) / 3,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF43F5E)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Step ${_currentStep + 1} of 3', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF43F5E))),
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
    final titles = ['Organization', 'Availability', 'Capabilities'];
    return Text(titles[_currentStep], style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500));
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildStep1();
      case 1: return _buildStep2();
      case 2: return _buildStep3();
      default: return const SizedBox();
    }
  }

  // ── Step 1 ──────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Organization Info', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Details regarding your response team or hospital.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        
        const Text('Organization Name', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _orgCtrl,
          decoration: _inputDeco('Hospital or Clinic Name', Icons.local_hospital_outlined),
        ),
        const SizedBox(height: 24),
        const Text('Staff / Team Name', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _staffCtrl,
          decoration: _inputDeco('Lead or Division Name', Icons.badge_outlined),
        ),
      ],
    );
  }

  // ── Step 2 ──────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Availability', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('When are your services available?', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        
        const Text('Response Hours', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _availability,
          decoration: _inputDeco('Select Timing', Icons.schedule),
          items: ['24/7 Response', 'Business Hours (9AM - 5PM)', 'Night Shift', 'On-Call Custom']
              .map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
          onChanged: (v) => setState(() => _availability = v),
        ),
      ],
    );
  }

  // ── Step 3 ──────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Capabilities', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Services and dispatch options.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ambulance Dispatch Available', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Instantly dispatch medical transport.'),
          value: _hasAmbulance,
          activeThumbColor: const Color(0xFFF43F5E),
          onChanged: (v) => setState(() => _hasAmbulance = v),
        ),
        const SizedBox(height: 24),
        const Text('Emergency Types Supported', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _emergencyTypes,
          decoration: _inputDeco('Select Support Level', Icons.medical_services_outlined),
          items: ['All Life-Threatening', 'Falls & Trauma Only', 'Cardiac & Respiratory', 'Basic First-Aid Only']
              .map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (v) => setState(() => _emergencyTypes = v),
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
              backgroundColor: const Color(0xFFF43F5E),
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_currentStep == 2 ? 'Complete Setup' : 'Continue', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
