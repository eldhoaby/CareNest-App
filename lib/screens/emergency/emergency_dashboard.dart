import 'package:flutter/material.dart';

class EmergencyDashboard extends StatelessWidget {
  const EmergencyDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emergency Dashboard")),
      body: const Center(
        child: Text(
          "Emergency Services 🚑",
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
