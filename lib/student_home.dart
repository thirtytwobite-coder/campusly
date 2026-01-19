import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'event_details.dart';
import 'profile_screen.dart';
import 'club_coordinator_dashboard.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _selectedIndex = 0; // 0: Public Events, 1: My College
  String selectedCategory = "All";
  String _searchQuery = "";
  String? studentCollege;
  bool _isLoadingCollege = true;
  List<DocumentSnapshot> managedClubs = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // 1. Fetch College
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('student').doc(user.uid).get();
        if (!doc.exists) {
          doc = await FirebaseFirestore.instance.collection('faculty').doc(user.uid).get();
        }
        
        String? college;
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          college = data?['college']?.toString().trim();
        }

        // 2. Fetch ALL clubs managed by this student
        final coordQuery = await FirebaseFirestore.instance
            .collection('clubs')
            .where('coordinatorEmails', arrayContains: user.email)
            .get();

        if (mounted) {
          setState(() {
            studentCollege = college;
            managedClubs = coordQuery.docs;
            _isLoadingCollege = false;
          });
        }
      } catch (e) {
        debugPrint("Error fetching dashboard data: $e");
        if (mounted) setState(() => _isLoadingCollege = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingCollege = false);
    }
  }

  void _handleCoordinatorSwitch() {
    if (managedClubs.isEmpty) return;

    if (managedClubs.length == 1) {
      // Single club: Go directly
      final clubData = managedClubs.first.data() as Map<String, dynamic>;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ClubCoordinatorDashboard(
            initialClubId: managedClubs.first.id,
            initialClubName: clubData['clubName'],
          ),
        ),
      );
    } else {
      // Multiple clubs: Show selection dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Select Club to Manage"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: managedClubs.length,
              itemBuilder: (context, index) {
                final clubDoc = managedClubs[index];
                final clubData = clubDoc.data() as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(Icons.stars, color: Colors.orange),
                  title: Text(clubData['clubName'] ?? 'Unnamed Club'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClubCoordinatorDashboard(
                          initialClubId: clubDoc.id,
                          initialClubName: clubData['clubName'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? "Campus Events" : "My College Events"),
        actions: [
          if (managedClubs.isNotEmpty)
            IconButton(
              tooltip: "Switch to Coordinator View",
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: _handleCoordinatorSwitch,
            ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => _toggleTheme(),
          ),
        ],
      ),
      body: _isLoadingCollege 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_selectedIndex == 1 && studentCollege != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Colors.indigo.withAlpha(30),
                    child: Row(
                      children: [
                        const Icon(Icons.school, size: 16, color: Colors.indigo),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Showing events for: $studentCollege",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildSearchBar(),
                _buildCategoryChips(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('events')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("No events found."));
                      }

                      var filteredDocs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final String eventCollege = (data['college'] ?? "").toString().trim();
                        final String visibility = (data['visibility'] ?? "public").toString().toLowerCase().trim();

                        bool isFromMyCollege = (studentCollege != null && 
                                               eventCollege.isNotEmpty &&
                                               eventCollege.toLowerCase() == studentCollege!.toLowerCase());

                        if (_selectedIndex == 0) {
                          // PUBLIC TAB: Only show events marked as "public"
                          if (visibility != 'public') return false;
                        } else {
                          // MY COLLEGE TAB: Show ALL events from my college
                          if (!isFromMyCollege) return false;
                        }

                        bool matchesCategory = (selectedCategory == "All" || data['category'] == selectedCategory);
                        bool matchesSearch = (data['title'] ?? "").toString().toLowerCase().contains(_searchQuery);

                        return matchesCategory && matchesSearch;
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              _selectedIndex == 1
                                  ? "No events found for $studentCollege.\nEnsure your events have the correct 'college' field."
                                  : "No public events available.",
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: filteredDocs.length,
                        padding: const EdgeInsets.only(bottom: 20),
                        itemBuilder: (context, index) => _buildEventCard(filteredDocs[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex == 2 ? 0 : _selectedIndex,
        onTap: (i) {
          if (i == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (c) => const ProfileScreen()));
          } else {
            setState(() => _selectedIndex = i);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.language), label: 'Public'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'My College'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: "Search events...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = ["All", "Technical", "Cultural", "Sports", "Academic", "Social"];
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemBuilder: (context, i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(categories[i]),
              selected: selectedCategory == categories[i],
              onSelected: (val) => setState(() => selectedCategory = categories[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String visibility = (data['visibility'] ?? "public").toString().toLowerCase();
    final bool isCollegeOnly = visibility == 'college';
    final String prize = (data['prizeAmount'] ?? "").toString();
    
    // Improved logic to show both College and Club Name
    final String college = (data['college'] ?? "").toString().trim();
    final String club = (data['clubName'] ?? "").toString().trim();
    
    String organizingBody = "General Event";
    if (college.isNotEmpty && club.isNotEmpty) {
      organizingBody = "$college • $club";
    } else if (college.isNotEmpty) {
      organizingBody = college;
    } else if (club.isNotEmpty) {
      organizingBody = club;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: isCollegeOnly ? Colors.indigo[50] : Colors.green[50],
          child: Icon(
            isCollegeOnly ? Icons.school : Icons.public,
            color: isCollegeOnly ? Colors.indigo : Colors.green,
            size: 20,
          ),
        ),
        title: Text(
          data['title'] ?? "Untitled Event",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              organizingBody,
              style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCollegeOnly ? Colors.indigo[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCollegeOnly ? "College-Only Event" : "Public Event",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isCollegeOnly ? Colors.indigo[900] : Colors.green[900],
                    ),
                  ),
                ),
                if (prize.isNotEmpty && prize != "0") ...[
                  const SizedBox(width: 8),
                  Text(
                    "🏆 ₹$prize",
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => EventDetailsScreen(event: doc)),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  void _toggleTheme() async {
    themeNotifier.value = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', themeNotifier.value == ThemeMode.dark);
  }
}
