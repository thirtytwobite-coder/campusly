import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

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
  int _selectedIndex = 0; // 0: Public, 1: My College, 2: Registered
  String selectedCategory = "All";
  String _searchQuery = "";
  String? studentCollege;
  bool _isLoadingCollege = true;
  DateTime? _selectedDate;
  List<DocumentSnapshot> managedClubs = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // 🔹 Fetch student data and managed clubs
  Future<void> _fetchDashboardData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Fetch College
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

        // Fetch ALL clubs managed by this student
        final coordQuery = await FirebaseFirestore.instance
            .collection('clubs')
            .where('coordinatorEmails', arrayContains: user.email)
            .get();

        if (mounted) {
          final data = doc.data() as Map<String, dynamic>?;
          setState(() {
            studentCollege = data?['college']?.toString().trim();
            managedClubs = coordQuery.docs;
            _isLoadingCollege = false;
          });
          return;
        }
      } catch (e) {
        debugPrint("Error fetching dashboard data: $e");
      }
    }
    if (mounted) setState(() => _isLoadingCollege = false);
  }

  // 🔹 Switch to coordinator view
  void _handleCoordinatorSwitch() {
    if (managedClubs.isEmpty) return;

    if (managedClubs.length == 1) {
      final clubData = managedClubs.first.data() as Map<String, dynamic>;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ClubCoordinatorDashboard(
            initialClubId: managedClubs.first.id,
            initialClubName: clubData['clubName'] ?? clubData['name'],
          ),
        ),
      );
    } else {
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
                  title: Text(clubData['clubName'] ?? clubData['name'] ?? 'Unnamed Club'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClubCoordinatorDashboard(
                          initialClubId: clubDoc.id,
                          initialClubName: clubData['clubName'] ?? clubData['name'],
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

  // 🔹 Date picker
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
        Text(_selectedIndex == 0 ? "Campus Events" : _selectedIndex == 1 ? "My College Events" : "Registered Events"),
        actions: [
          if (managedClubs.isNotEmpty)
            IconButton(
              tooltip: "Switch to Coordinator View",
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: _handleCoordinatorSwitch,
            ),
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

          if (_selectedIndex != 2) ...[
            _buildSearchBar(),
            _buildCategoryChips(),
          ],

          Expanded(
            child: _selectedIndex == 2 ? _buildRegisteredEventsList() : _buildEventsList(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex == 3 ? 0 : _selectedIndex,
        onTap: (i) {
          if (i == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ProfileScreen()),
            );
          } else {
            setState(() => _selectedIndex = i);
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.language), label: 'Public'),
          BottomNavigationBarItem(
              icon: Icon(Icons.school), label: 'My College'),
          BottomNavigationBarItem(
              icon: Icon(Icons.assignment_turned_in), label: 'Registered'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    return StreamBuilder<QuerySnapshot>(
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

          // 🔹 Date filter
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
    );
  }

  Widget _buildRegisteredEventsList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Please login to see registered events"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('registrations')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_late_outlined, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text("No registered events found.", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final registrations = snapshot.data!.docs;
        
        return ListView.builder(
          itemCount: registrations.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final regData = registrations[index].data() as Map<String, dynamic>;
            final eventId = regData['eventId'];
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('events').doc(eventId).get(),
              builder: (context, eventSnap) {
                if (!eventSnap.hasData) return const SizedBox.shrink();
                if (!eventSnap.data!.exists) return const SizedBox.shrink();
                
                return _buildEventCard(eventSnap.data!);
              },
            );
          },
        );
      },
    );
  }

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
    final posterLink = data['posterLink'] as String?;

    return Card(
      margin:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias, // Ensure image stays within card corners
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => EventDetailsScreen(event: doc)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (posterLink != null && posterLink.isNotEmpty)
              Image.network(
                posterLink,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                ),
              ),
            ListTile(
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
                              ? "College-Only"
                              : "Public",
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
            ),
          ],
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
