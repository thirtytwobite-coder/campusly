import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart'; // Import main.dart to access themeNotifier
// Ensure these imports match your actual file names
import 'change_password.dart';
import 'login_screen.dart';

class ClubCoordinatorDashboard extends StatefulWidget {
  final String collegeName;
  final String clubName;

  const ClubCoordinatorDashboard({super.key, required this.collegeName, required this.clubName});

  @override
  State<ClubCoordinatorDashboard> createState() => _ClubCoordinatorDashboardState();
}

class _ClubCoordinatorDashboardState extends State<ClubCoordinatorDashboard> {
  final Color primaryColor = const Color(0xFF1A237E);

  // --- Navigation Logic ---

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const UnifiedLoginScreen()),
      );
    }
  }

  // --- Add Event Logic ---

  Future<void> _addEventDialog() async {
    final nameController = TextEditingController();
    final dateController = TextEditingController();
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Event Name')),
            TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: 'Event Date')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || dateController.text.isEmpty) return;
                await FirebaseFirestore.instance.collection('events').add({
                  'eventName': nameController.text.trim(),
                  'eventDate': dateController.text.trim(),
                  'clubName': widget.clubName,
                  'collegeName': widget.collegeName,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(c);
              },
              child: const Text('Add')),
        ],
      ),
    );
  }

  // --- Main UI Build ---

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          final exit = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Exit'),
              content: const Text('Are you sure you want to exit?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('No')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Yes')),
              ],
            ),
          );
          return exit ?? false;
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.clubName),
            actions: [
              IconButton(
                icon: const Icon(Icons.brightness_6),
                onPressed: () async {
                  themeNotifier.value = themeNotifier.value == ThemeMode.light
                      ? ThemeMode.dark
                      : ThemeMode.light;
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  prefs.setBool('isDarkMode', themeNotifier.value == ThemeMode.dark);
                },
              ),
              IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout)
            ],
          ),
          body: Container(
            color: Colors.grey[50],
            child: GridView.count(
              padding: const EdgeInsets.all(20),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildCard(
                    "Add Event", Icons.add, _addEventDialog),
                _buildCard("Security", Icons.security_rounded, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (c) => const ChangePasswordScreen()));
                }),
              ],
            ),
          ),
        ));
  }

  Widget _buildCard(String title, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: primaryColor),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}