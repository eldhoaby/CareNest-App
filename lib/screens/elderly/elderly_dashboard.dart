import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'elderly_home_tab.dart';
import 'elderly_profile_tab.dart';

class ElderlyDashboard extends StatefulWidget {
  const ElderlyDashboard({super.key});

  @override
  State<ElderlyDashboard> createState() => _ElderlyDashboardState();
}

class _ElderlyDashboardState extends State<ElderlyDashboard>
    with TickerProviderStateMixin {

  int _selectedIndex = 0;
  bool _isSOSPressed = false;
  String userName = "";
  bool isLoading = true;

  late AnimationController _sosController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadUserName();

    _sosController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _sosController, curve: Curves.easeInOut),
    );

    setState(() => isLoading = false);
  }

  Future<void> _loadUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        userName = doc.data()?['name'] ?? "";
      }
    } catch (e) {
      debugPrint("Error loading user name: $e");
    }
  }

  @override
  void dispose() {
    _sosController.dispose();
    super.dispose();
  }

  Future<void> _triggerSOS() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('alerts').add({
        'uid': user.uid,
        'type': 'SOS',
        'timestamp': Timestamp.now(),
        'status': 'active',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚨 Emergency Alert Sent!"),
          backgroundColor: Colors.red,
        ),
      );

    } catch (e) {
      debugPrint("SOS error: $e");
    }
  }

  List<Widget> get _pages => [
    ElderlyHomeTab(userName: userName),
    const ElderlyProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "SafeNest",
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (userName.isNotEmpty)
              Text(
                "Welcome, $userName",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_selectedIndex],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: (index) {
          HapticFeedback.selectionClick();
          setState(() => _selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),

      floatingActionButton: _buildSOSButton(),
      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildSOSButton() {
    return GestureDetector(
      onLongPressStart: (_) {
        setState(() => _isSOSPressed = true);
        _sosController.repeat(reverse: true);
        HapticFeedback.mediumImpact();
      },
      onLongPressEnd: (_) async {
        setState(() => _isSOSPressed = false);
        _sosController.stop();
        _sosController.reset();
        await _triggerSOS();
      },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isSOSPressed ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFFEF4444),
                    Color(0xFFDC2626),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: _isSOSPressed ? 45 : 25,
                    spreadRadius: _isSOSPressed ? 6 : 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.sos,
                size: 40,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }
}
