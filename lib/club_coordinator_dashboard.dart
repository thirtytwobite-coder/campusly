import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    this.initialClubName
  });

  @override
  State<ClubCoordinatorDashboard> createState() => _ClubCoordinatorDashboardState();
}

class _ClubCoordinatorDashboardState extends State<ClubCoordinatorDashboard> {
  String? clubId;
  String? clubName;
  String? coordinatorCollege;
  int _selectedIndex = 0;
  bool _isLoadingInfo = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardInfo();
  }

  // --- Fetching college and specific club this user manages ---
  Future<void> _fetchDashboardInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // 1. Fetch Coordinator's College from student profile
        final studentDoc = await FirebaseFirestore.instance.collection('student').doc(user.uid).get();
        if (studentDoc.exists) {
          coordinatorCollege = studentDoc.data()?['college'];
        }

        // 2. Load Club Info
        if (widget.initialClubId != null) {
          clubId = widget.initialClubId;
          clubName = widget.initialClubName;
        } else {
          // Fallback: Fetch the first club they manage if none was passed
          final clubsQuery = await FirebaseFirestore.instance
              .collection('clubs')
              .where('coordinatorEmails', arrayContains: user.email)
              .limit(1)
              .get();

          if (clubsQuery.docs.isNotEmpty) {
            final clubDoc = clubsQuery.docs.first;
            clubId = clubDoc.id;
            clubName = clubDoc.data()['clubName'] as String?;
          }
        }
      } catch (e) {
        debugPrint("Error loading dashboard info: $e");
      }
    }
    
    if (mounted) {
      setState(() => _isLoadingInfo = false);
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);

    if (index == 1) {
      if (clubId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ManageProgramsScreen(
              clubId: clubId!,
              clubName: clubName ?? 'Club',
            ),
          ),
        ).then((_) => setState(() => _selectedIndex = 0));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Club information not loaded yet.')),
        );
        setState(() => _selectedIndex = 0);
      }
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      ).then((_) => setState(() => _selectedIndex = 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        final bool shouldExit = await _showExitDialog() ?? false;
        if (shouldExit && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Coordinator Dashboard'),
          actions: [
            IconButton(
              tooltip: "Switch to Student View",
              icon: const Icon(Icons.person_pin_circle_sharp),
              onPressed: () => Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (_) => const StudentHomeScreen())
              ),
            ),
            IconButton(
              icon: const Icon(Icons.brightness_6),
              onPressed: () async {
                themeNotifier.value = themeNotifier.value == ThemeMode.light
                    ? ThemeMode.dark
                    : ThemeMode.light;
                SharedPreferences prefs = await SharedPreferences.getInstance();
                prefs.setBool('isDarkMode', themeNotifier.value == ThemeMode.dark);
              },
            ),

          ],
        ),
        body: _isLoadingInfo ? _buildLoadingState() : _buildDashboardBody(),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Programs'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- INSTITUTION & CLUB HEADER ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance, color: Colors.blueAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        coordinatorCollege ?? "Institution Unknown",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.stars, color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        clubName ?? "Unassigned Club",
                        style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.1),

          const SizedBox(height: 25),

          Text(
            "Welcome Back,",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 5),
          
          // --- CLUB DESCRIPTION CARD ---
          if (clubId != null)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('clubs').doc(clubId!).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();

                final clubData = snapshot.data!.data() as Map<String, dynamic>;
                final description = clubData['description'] ?? 'No description set.';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Club Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                  onPressed: () => _showEditDescriptionDialog(description),
                                ),
                              ],
                            ),
                            const Divider(),
                            Text(description, style: const TextStyle(height: 1.5)),
                          ],
                        ),
                      ),
                    ).animate().fadeIn().slideY(begin: 0.1),
                  ],
                );
              },
            ),

          const SizedBox(height: 30),

          // --- QUICK ACTIONS ---
          const Text("Management Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 15),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            children: [
              _buildQuickActionCard(
                context,
                "Event List",
                "Manage Programs",
                Icons.event_note,
                Colors.orange,
                    () => _onItemTapped(1),
              ),
              _buildQuickActionCard(
                context,
                "Analytics",
                "View Registrations",
                Icons.bar_chart,
                Colors.green,
                    () => _showComingSoonSnackBar("Analytics"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }



  void _showComingSoonSnackBar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$feature feature is coming soon!")));
  }

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Exit Dashboard?"),
        content: const Text("Do you want to exit the application?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Exit")),
        ],
      ),
    );
  }

  Future<void> _showEditDescriptionDialog(String current) async {
    final controller = TextEditingController(text: current);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Club Description"),
        content: TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (clubId != null) {
                await FirebaseFirestore.instance.collection('clubs').doc(clubId!).update({'description': controller.text});
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
