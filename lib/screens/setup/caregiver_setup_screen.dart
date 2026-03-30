import 'package:flutter/material.dart';
import '../../core/services/firebase_service.dart';
import '../caregiver/caregiver_dashboard.dart';

class CaregiverSetupScreen extends StatefulWidget {
  const CaregiverSetupScreen({super.key});

  @override
  State<CaregiverSetupScreen> createState() => _CaregiverSetupScreenState();
}

class _CaregiverSetupScreenState extends State<CaregiverSetupScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Link Elderly
  final _linkCtrl = TextEditingController();
  bool _step1Valid = false;
  void _validateStep1() {
    setState(() {
      _step1Valid = _linkCtrl.text.trim().isNotEmpty;
    });
  }

  // Step 2: Relationship
  String? _relation;
  bool get _step2Valid => _relation != null;

  // Step 3: Notifications (enabled by default as requested)
  bool _notifPerm = true;
  bool get _step3Valid => true;

  @override
  void initState() {
    super.initState();
    _linkCtrl.addListener(_validateStep1);
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitStep() async {
    setState(() => _isLoading = true);
    final fs = FirebaseService.instance;

    try {
      if (_currentStep == 0) {
        final input = _linkCtrl.text.trim();
        
        // Is it a 6 character code?
        if (input.length == 6 && !RegExp(r'^\d+$').hasMatch(input)) {
          final success = await fs.tryAutoLinkWithCode(input.toUpperCase(), 'caregiver');
          if (!success) {
            _showError('Invalid or expired invite code');
            setState(() => _isLoading = false);
            return;
          }
        } 
        // Or is it a 10 digit phone number?
        else if (RegExp(r'^\d{10}$').hasMatch(input)) {
           final elderlyUid = await fs.lookupElderlyByPhone(input);
           if (elderlyUid != null && fs.currentUid != null) {
              await fs.sendLinkRequest(fromUid: fs.currentUid!, toUid: elderlyUid, fromRole: 'caregiver');
           } else {
              _showError('No elderly user found with this phone number');
              setState(() => _isLoading = false);
              return;
           }
        } else {
           _showError('Please enter a valid phone number or code');
           setState(() => _isLoading = false);
           return;
        }
      } else if (_currentStep == 1) {
        await fs.saveSetupStep({'relationship': _relation});
      } else if (_currentStep == 2) {
        await fs.saveSetupStep({'notificationsEnabled': _notifPerm});
        
        // Finalize
        await fs.completeSetup();
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CaregiverDashboard()));
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
      _showError('An error occurred. Please try again.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
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
        title: const Text('Setup Complete Profile', style: TextStyle(color: Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF10B981)),
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
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Step ${_currentStep + 1} of 3', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
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
    final titles = ['Link Elderly', 'Relationship', 'Notifications'];
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
        const Text('Link to Elderly', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Connect with the person you are caring for.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        
        const Text('Elderly Phone or Invite Code', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _linkCtrl,
          decoration: InputDecoration(
            hintText: 'Code from Elderly profile',
            prefixIcon: const Icon(Icons.link, color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: const Row(
            children: [
              Icon(Icons.info, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Enter their 10-digit phone number to send a request, or their 6-character invite code to link instantly.', style: TextStyle(fontSize: 13, color: Color(0xFF064E3B)))),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 2 ──────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Relationship', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('What is your relation to the elderly user?', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        
        const Text('Relation', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
        initialValue: _relation,
          decoration: InputDecoration(
            hintText: 'Select Relationship',
            prefixIcon: const Icon(Icons.family_restroom, color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
          ),
          items: ['Son', 'Daughter', 'Spouse', 'Professional Nurse', 'Other']
              .map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (v) => setState(() => _relation = v),
        ),
      ],
    );
  }

  // ── Step 3 ──────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Notifications', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Critical alerts will always bypass silent mode where possible.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        
        SwitchListTile(
          title: const Text('Receive All Alerts', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Includes falls, inactivity warnings, and SOS triggers.'),
          value: _notifPerm,
          activeThumbColor: const Color(0xFF10B981),
          onChanged: (v) => setState(() => _notifPerm = v), // Could be rigid to true
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
              backgroundColor: const Color(0xFF10B981),
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
}
