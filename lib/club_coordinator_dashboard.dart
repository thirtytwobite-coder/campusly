import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_screen.dart';
import 'change_password.dart';
import 'login_screen.dart';
import 'main.dart';
import 'manage_programs.dart';
import 'profile_screen.dart';
import 'student_home.dart';

class ClubCoordinatorDashboard extends StatefulWidget {
  final String? initialClubId;
  final String? initialClubName;

  const ClubCoordinatorDashboard({
    super.key,
    this.initialClubId,
    this.initialClubName,
  });

  @override
  State<ClubCoordinatorDashboard> createState() =>
      _ClubCoordinatorDashboardState();
}

class _ClubCoordinatorDashboardState extends State<ClubCoordinatorDashboard> {
  String? clubId;
  String? clubName;
  int _selectedIndex = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    clubId = widget.initialClubId;
    clubName = widget.initialClubName;

    if (clubId == null) {
      _fetchClubInfo();
    } else {
      _loading = false;
    }
  }

  // 🔹 Fetch coordinator club
  Future<void> _fetchClubInfo() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user?.email == null) {
      setState(() => _loading = false);
      return;
    }

    final query = await FirebaseFirestore.instance
        .collection('clubs')
        .where('coordinatorEmails', arrayContains: user!.email)
        .limit(1)
        .get();

    if (mounted && query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final data = doc.data();

      setState(() {
        clubId = doc.id;
        clubName = data['name'] ?? data['clubName'];
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  // 🔹 Bottom navigation
  void _onItemTapped(int index) async {
    if (index == _selectedIndex) return;

    if (index == 1 && clubId != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManageProgramsScreen(
            clubId: clubId!,
            clubName: clubName ?? 'Club',
          ),
        ),
      );
    } else if (index == 2) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }

    setState(() => _selectedIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final exit = await _showExitDialog() ?? false;
        if (exit && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(clubName ?? 'Coordinator Dashboard'),
          actions: [
            // 🔹 DIRECT student switch icon (from old file)
            IconButton(
              tooltip: "Switch to Student View",
              icon: const Icon(Icons.person_pin_circle),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StudentHomeScreen(),
                  ),
                );
              },
            ),

            IconButton(
              icon: const Icon(Icons.brightness_6),
              onPressed: _toggleTheme,
            ),
          ],
        ),
        body: _loading
            ? _buildLoadingState()
            : clubId == null
            ? const Center(child: Text("No club assigned"))
            : _buildDashboardBody(),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.add_circle), label: 'Programs'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Loading Club Dashboard..."),
        ],
      ),
    );
  }

  Widget _buildDashboardBody() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId!)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        final clubData =
        snapshot.data!.data() as Map<String, dynamic>;
        final description =
            clubData['description'] ?? 'No description set.';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome Back,",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.grey)),
              Text(
                clubName ?? "Coordinator",
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 25),

              _clubDescriptionCard(description),

              const SizedBox(height: 30),

              const Text("Management Actions",
                  style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 15),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                children: [
                  _buildQuickActionCard(
                    "Event List",
                    "Manage Programs",
                    Icons.event_note,
                    Colors.orange,
                        () => _onItemTapped(1),
                  ),
                  _buildQuickActionCard(
                    "Analytics",
                    "View Registrations",
                    Icons.bar_chart,
                    Colors.green,
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AnalyticsScreen(
                            clubId: clubId!,
                            clubName: clubName ?? 'Club',
                            coordinatorId:
                            FirebaseAuth.instance.currentUser?.uid,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _clubDescriptionCard(String description) {
    return Card(
      elevation: 2,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Club Description",
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.edit,
                      size: 20, color: Colors.blue),
                  onPressed: () =>
                      _showEditDescriptionDialog(description),
                ),
              ],
            ),
            const Divider(),
            Text(
              description,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildQuickActionCard(
      String title,
      String subtitle,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            Text(subtitle,
                style:
                const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTheme() async {
    themeNotifier.value =
    themeNotifier.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(
        'isDarkMode', themeNotifier.value == ThemeMode.dark);
  }

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Exit Dashboard?"),
        content: const Text("Do you want to exit the application?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Exit")),
        ],
      ),
    );
  }

  Future<void> _showEditDescriptionDialog(String current) async {
    final controller = TextEditingController(text: current);
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Club Description"),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration:
          const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (clubId != null &&
                  controller.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId!)
                    .update(
                    {'description': controller.text.trim()});
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
