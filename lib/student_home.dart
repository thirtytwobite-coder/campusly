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
  int _selectedIndex = 0; // 0: Public, 1: My College
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

  // 🔹 Fetch student / faculty college
  Future<void> _fetchStudentCollege() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('student')
            .doc(user.uid)
            .get();

        if (!doc.exists) {
          doc = await FirebaseFirestore.instance
              .collection('faculty')
              .doc(user.uid)
              .get();
        }

        if (mounted && doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          setState(() {
            studentCollege = data?['college']?.toString().trim();
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

  // 🔹 Date picker (from file 2)
  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        Text(_selectedIndex == 0 ? "Campus Events" : "My College Events"),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: _toggleTheme,
          ),
        ],
      ),
      body: _isLoadingCollege
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // 🔹 College banner (from file 1)
          if (_selectedIndex == 1 && studentCollege != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: 8, horizontal: 16),
              color: Colors.indigo.withAlpha(30),
              child: Row(
                children: [
                  const Icon(Icons.school,
                      size: 16, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Showing events for: $studentCollege",
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo),
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
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text("No events found."));
                }

                final filteredDocs =
                snapshot.data!.docs.where((doc) {
                  final data =
                  doc.data() as Map<String, dynamic>;

                  final eventCollege =
                  (data['college'] ?? "")
                      .toString()
                      .trim();
                  final visibility =
                  (data['visibility'] ?? "public")
                      .toString()
                      .toLowerCase()
                      .trim();

                  final isFromMyCollege =
                      studentCollege != null &&
                          eventCollege.isNotEmpty &&
                          eventCollege.toLowerCase() ==
                              studentCollege!
                                  .toLowerCase();

                  // 🔹 Tab filtering
                  if (_selectedIndex == 0) {
                    if (visibility != 'public') return false;
                  } else {
                    if (!isFromMyCollege) return false;
                  }

                  // 🔹 Category
                  if (selectedCategory != "All" &&
                      data['category'] !=
                          selectedCategory) {
                    return false;
                  }

                  // 🔹 Search
                  if (!(data['title'] ?? "")
                      .toString()
                      .toLowerCase()
                      .contains(_searchQuery)) {
                    return false;
                  }

                  // 🔹 Date filter (from file 2)
                  if (_selectedDate != null) {
                    final selected =
                    DateFormat('yyyy-MM-dd')
                        .format(_selectedDate!);
                    if (data['date'] != selected) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding:
                      const EdgeInsets.all(20),
                      child: Text(
                        _selectedIndex == 1
                            ? "No events found for $studentCollege.\nEnsure your events have the correct 'college' field."
                            : "No public events available.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  padding:
                  const EdgeInsets.only(bottom: 20),
                  itemBuilder: (context, index) =>
                      _buildEventCard(
                          filteredDocs[index]),
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
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ProfileScreen()),
            );
          } else {
            setState(() => _selectedIndex = i);
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.language), label: 'Public'),
          BottomNavigationBarItem(
              icon: Icon(Icons.school), label: 'My College'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  // 🔹 Search bar + calendar (merged)
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (v) =>
            setState(() => _searchQuery = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: "Search events...",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedDate != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () =>
                      setState(() => _selectedDate = null),
                ),
              IconButton(
                icon: Icon(Icons.calendar_month,
                    color: _selectedDate != null
                        ? Colors.blue
                        : null),
                onPressed: () => _selectDate(context),
              ),
            ],
          ),
          filled: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = [
      "All",
      "Technical",
      "Cultural",
      "Sports",
      "Academic",
      "Social"
    ];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text(categories[i]),
            selected: selectedCategory == categories[i],
            onSelected: (_) =>
                setState(() => selectedCategory = categories[i]),
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final visibility =
    (data['visibility'] ?? "public").toString().toLowerCase();
    final isCollegeOnly = visibility == 'college';
    final prize = (data['prizeAmount'] ?? "").toString();
    final eventDate = data['date'] ?? "TBD";

    return Card(
      margin:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor:
          isCollegeOnly ? Colors.indigo[50] : Colors.green[50],
          child: Icon(
            isCollegeOnly ? Icons.school : Icons.public,
            color:
            isCollegeOnly ? Colors.indigo : Colors.green,
            size: 20,
          ),
        ),
        title: Text(
          data['title'] ?? "Untitled Event",
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "${data['college'] ?? "General Event"} • $eventDate",
              style:
              TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCollegeOnly
                        ? Colors.indigo[100]
                        : Colors.green[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCollegeOnly
                        ? "College-Only Event"
                        : "Public Event",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isCollegeOnly
                          ? Colors.indigo[900]
                          : Colors.green[900],
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
                        fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios,
            size: 14, color: Colors.grey),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => EventDetailsScreen(event: doc)),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  void _toggleTheme() async {
    themeNotifier.value =
    themeNotifier.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(
        'isDarkMode', themeNotifier.value == ThemeMode.dark);
  }
}