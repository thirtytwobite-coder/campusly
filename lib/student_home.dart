import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'event_details.dart';
import 'profile_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _selectedIndex = 0; // 0: Global, 1: My College
  String selectedCategory = "All";
  String _searchQuery = "";
  String? studentCollege;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStudentCollege();
  }

  // Fetch the student's college from their user profile
  Future<void> _fetchStudentCollege() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted && doc.exists) {
        setState(() {
          studentCollege = doc.data()?['college'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? "Campus Events" : "My College Only"),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => _toggleTheme(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. SEARCH BAR
          _buildSearchBar(),

          // 2. CATEGORY CHIPS
          _buildCategoryChips(),

          // 3. EVENT LIST WITH STICKY PRIVACY LOGIC
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

                // --- THE "COLLEGE ONLY" FILTERING LOGIC ---
                var filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String eventCollege = data['college'] ?? "";
                  final bool isCollegeOnly = data['isCollegeOnly'] ?? false;

                  // Does the event belong to the current student's college?
                  bool isFromMyCollege = (studentCollege != null && eventCollege == studentCollege);

                  // Tab Filtering Logic:
                  bool matchesTab = false;
                  if (_selectedIndex == 0) {
                    // GLOBAL TAB: Show if it's Public OR if it's Amal's own college
                    // (Amal should not see Idukki's "College Only" events here)
                    matchesTab = !isCollegeOnly || isFromMyCollege;
                  } else {
                    // MY COLLEGE TAB: Amal ONLY sees events from Palakkad
                    matchesTab = isFromMyCollege;
                  }

                  // Category & Search Filters
                  bool matchesCategory = (selectedCategory == "All" || data['category'] == selectedCategory);
                  bool matchesSearch = data['title'].toString().toLowerCase().contains(_searchQuery);

                  return matchesTab && matchesCategory && matchesSearch;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(_selectedIndex == 1
                        ? "No events found for $studentCollege"
                        : "No events available"),
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
        currentIndex: _selectedIndex,
        onTap: (i) {
          if (i == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (c) => const ProfileScreen()));
          } else {
            setState(() => _selectedIndex = i);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.language), label: 'Global'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'My College'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  // --- SUB-WIDGETS ---

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
    final categories = ["All", "Technical", "Workshop", "Sports", "Arts"];
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
    final bool isCollegeOnly = data['isCollegeOnly'] ?? false;
    final String prize = data['prizePool'] ?? data['pricePool'] ?? "";

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        title: Text(data['title'] ?? "Untitled", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['college'] ?? "Unknown College", style: const TextStyle(fontSize: 12)),
            if (prize.isNotEmpty)
              Text("🏆 $prize", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
        trailing: isCollegeOnly
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.indigo[100], borderRadius: BorderRadius.circular(4)),
          child: const Text("COLLEGE ONLY", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.indigo)),
        )
            : const Icon(Icons.arrow_forward_ios, size: 12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => EventDetailsScreen(event: doc))),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  void _toggleTheme() async {
    themeNotifier.value = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', themeNotifier.value == ThemeMode.dark);
  }
}