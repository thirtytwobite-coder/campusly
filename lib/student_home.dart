import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'main.dart';
import 'event_details.dart';
import 'profile_screen.dart';

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
  DateTime? _selectedDate;
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
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('student').doc(user.uid).get();
        if (!doc.exists) {
          doc = await FirebaseFirestore.instance.collection('faculty').doc(user.uid).get();
        }
        if (mounted && doc.exists) {
          setState(() {
            studentCollege = (doc.data() as Map<String, dynamic>?)?['college'];
            _isLoadingCollege = false;
          });
          return;
        }
      } catch (e) {
        debugPrint("Error fetching college: $e");
      }
    }
    if (mounted) setState(() => _isLoadingCollege = false);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? "Campus Events" : "My College Events"),
        actions: [
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
                // 1. SEARCH BAR
                _buildSearchBar(),

                // 2. CATEGORY CHIPS
                _buildCategoryChips(),

                // 3. EVENT LIST WITH VISIBILITY LOGIC
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

                      // --- AUTOMATIC FILTERING LOGIC ---
                      var filteredDocs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final String eventCollege = data['college'] ?? "";
                        
                        // Requirement: Default visibility to Public if the field is missing
                        final String visibility = (data['visibility'] ?? "public").toString().toLowerCase();

                        // Identify whether the event belongs to the current student's college
                        bool isFromMyCollege = (studentCollege != null && eventCollege == studentCollege);

                        // Tab Filtering:
                        if (_selectedIndex == 0) {
                          // PUBLIC TAB: Only show events marked as "public"
                          if (visibility != 'public') return false;
                        } else {
                          // MY COLLEGE TAB: Show all events from the student's college (Public or College-Only)
                          if (!isFromMyCollege) return false;
                        }

                        // Category & Search & Date Filters
                        bool matchesCategory = (selectedCategory == "All" || data['category'] == selectedCategory);
                        bool matchesSearch = (data['title'] ?? "").toString().toLowerCase().contains(_searchQuery);
                        
                        bool matchesDate = true;
                        if (_selectedDate != null) {
                          String formattedSelectedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
                          matchesDate = data['date'] == formattedSelectedDate;
                        }

                        return matchesCategory && matchesSearch && matchesDate;
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              _selectedIndex == 1
                                  ? "No events found for ${studentCollege ?? 'your college'}"
                                  : "No events available.",
                              textAlign: TextAlign.center,
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
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedDate != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _selectedDate = null),
                ),
              IconButton(
                icon: Icon(
                  Icons.calendar_month,
                  color: _selectedDate != null ? Colors.blue : null,
                ),
                onPressed: () => _selectDate(context),
              ),
            ],
          ),
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
    
    // 1. Read the event’s visibility field, defaulting to "public" if missing
    final String visibility = (data['visibility'] ?? "public").toString().toLowerCase();
    
    // 2. Identify whether the event is college-only
    final bool isCollegeOnly = visibility == 'college';
    final String prize = (data['prizeAmount'] ?? "").toString();
    final String eventDate = data['date'] ?? "TBD";

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
              "${data['college'] ?? "General Event"} • $eventDate",
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // 3. Display appropriate labels such as “Public Event” or “College-Only Event”
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
