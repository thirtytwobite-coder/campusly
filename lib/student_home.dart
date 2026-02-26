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
import 'vibrant_background.dart';
import 'participation_history.dart';

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
                  title: Text(
                    clubData['clubName'] ?? clubData['name'] ?? 'Unnamed Club',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClubCoordinatorDashboard(
                          initialClubId: clubDoc.id,
                          initialClubName:
                              clubData['clubName'] ?? clubData['name'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
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
    final theme = Theme.of(context);
    final sectionTitle = _selectedIndex == 0
        ? "Campus Events"
        : _selectedIndex == 1
        ? "My College Events"
        : "Participation History";

    return Scaffold(
      body: Stack(
        children: [
          const VibrantBackground(),
          _isLoadingCollege
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                sectionTitle,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (managedClubs.isNotEmpty)
                              _headerIconButton(
                                icon: Icons.admin_panel_settings_outlined,
                                tooltip: "Switch to Coordinator View",
                                onTap: _handleCoordinatorSwitch,
                              ),
                            if (_selectedIndex == 2)
                              _headerIconButton(
                                icon: Icons.history,
                                tooltip: "Participation History",
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ParticipationHistoryScreen(),
                                    ),
                                  );
                                },
                              ),
                            _headerIconButton(
                              icon: Icons.brightness_6,
                              tooltip: "Toggle Theme",
                              onTap: _toggleTheme,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedIndex == 1 && studentCollege != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.school_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Showing events for: $studentCollege",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_selectedIndex != 2) ...[
                      _buildSearchBar(),
                      _buildCategoryChips(),
                      const SizedBox(height: 8),
                    ],

                    Expanded(
                      child: _selectedIndex == 2
                          ? _buildRegisteredEventsList()
                          : _buildEventsList(),
                    ),
                  ],
                ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex > 2 ? 0 : _selectedIndex,
        height: 72,
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.95),
        indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.16),
        onDestinationSelected: (i) {
          if (i == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
            return;
          }
          setState(() => _selectedIndex = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.language), label: 'Public'),
          NavigationDestination(icon: Icon(Icons.school), label: 'My College'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(icon, size: 20),
          ),
        ),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No events found."));
        }

        final filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          final eventCollege = (data['college'] ?? "").toString().trim();
          final visibility = (data['visibility'] ?? "public")
              .toString()
              .toLowerCase()
              .trim();
          final status = (data['status'] ?? "approved").toString().toLowerCase().trim();

          // 🔹 Filter: Only show events that have "Started" (ongoing)
          if (status != 'ongoing') return false;

          final isFromMyCollege =
              studentCollege != null &&
              eventCollege.isNotEmpty &&
              eventCollege.toLowerCase() == studentCollege!.toLowerCase();

          // 🔹 Tab filtering
          if (_selectedIndex == 0) {
            if (visibility != 'public') return false;
          } else {
            if (!isFromMyCollege) return false;
          }

          // 🔹 Category
          if (selectedCategory != "All" &&
              data['category'] != selectedCategory) {
            return false;
          }

          // 🔹 Search
          if (!(data['title'] ?? "").toString().toLowerCase().contains(
            _searchQuery,
          )) {
            return false;
          }

          // 🔹 Date filter
          if (_selectedDate != null) {
            final selected = DateFormat('yyyy-MM-dd').format(_selectedDate!);
            if (data['date'] != selected) {
              return false;
            }
          }

          return true;
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _selectedIndex == 1
                    ? "No live events found for $studentCollege.\nEvents appear once they are started by the coordinator."
                    : "No live public events available.",
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
    );
  }

  Widget _buildRegisteredEventsList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please login to see registered events"));
    }

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
                Icon(
                  Icons.assignment_late_outlined,
                  size: 60,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  "No registered events found.",
                  style: TextStyle(color: Colors.grey),
                ),
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
              future: FirebaseFirestore.instance
                  .collection('events')
                  .doc(eventId)
                  .get(),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: "Search live events...",
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
                  color: _selectedDate != null
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                onPressed: () => _selectDate(context),
              ),
            ],
          ),
          filled: true,
          fillColor: Theme.of(
            context,
          ).colorScheme.surface.withValues(alpha: 0.92),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
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
      "Social",
    ];

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text(categories[i]),
            selected: selectedCategory == categories[i],
            onSelected: (_) => setState(() => selectedCategory = categories[i]),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: selectedCategory == categories[i]
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            selectedColor: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.82),
            side: BorderSide(
              color: selectedCategory == categories[i]
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.25),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final visibility = (data['visibility'] ?? "public")
        .toString()
        .toLowerCase();
    final isCollegeOnly = visibility == 'college';
    final prize = (data['prizeAmount'] ?? "").toString();
    final eventDate = data['date'] ?? "TBD";
    final posterLink = data['posterLink'] as String?;
    final bool isTeamEvent = (data['isTeamEvent'] ?? false) == true;

    final status = (data['status'] ?? 'approved').toString().toLowerCase();

    Color statusInfoColor;
    Color statusInfoText;
    String statusLabel;

    switch (status) {
      case 'ongoing':
        statusInfoColor = Colors.orange.shade100;
        statusInfoText = Colors.orange.shade900;
        statusLabel = "ONGOING";
        break;
      case 'completed':
        statusInfoColor = Colors.grey.shade300;
        statusInfoText = Colors.grey.shade800;
        statusLabel = "COMPLETED";
        break;
      case 'cancelled':
        statusInfoColor = Colors.red.shade100;
        statusInfoText = Colors.red.shade900;
        statusLabel = "CANCELLED";
        break;
      default:
        statusInfoColor = Colors.blue.shade50;
        statusInfoText = Colors.blue.shade900;
        statusLabel = "UPCOMING";
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailsScreen(event: doc)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (posterLink != null && posterLink.isNotEmpty)
              Image.network(
                posterLink,
                width: double.infinity,
                height: 170,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 170,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.image_not_supported,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isCollegeOnly
                          ? Colors.indigo.withValues(alpha: 0.12)
                          : Colors.green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCollegeOnly
                          ? Icons.school_rounded
                          : Icons.public_rounded,
                      color: isCollegeOnly ? Colors.indigo : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title'] ?? "Untitled Event",
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${data['college'] ?? "General Event"} - $eventDate",
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _eventTag(
                              isCollegeOnly ? "College-Only" : "Public",
                              bgColor: isCollegeOnly
                                  ? Colors.indigo.withValues(alpha: 0.15)
                                  : Colors.green.withValues(alpha: 0.15),
                              fgColor: isCollegeOnly
                                  ? Colors.indigo
                                  : Colors.green.shade800,
                            ),
                            _eventTag(
                              statusLabel,
                              bgColor: statusInfoColor,
                              fgColor: statusInfoText,
                            ),
                            if (isTeamEvent)
                              _eventTag(
                                "Team • ${data['teamSize'] ?? 'N/A'}",
                                bgColor: Colors.purple.withValues(alpha: 0.14),
                                fgColor: Colors.purple.shade900,
                              ),
                            if (prize.isNotEmpty && prize != "0")
                              _eventTag(
                                "Prize Rs.$prize",
                                bgColor: Colors.orange.withValues(alpha: 0.14),
                                fgColor: Colors.orange.shade900,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _eventTag(
    String text, {
    required Color bgColor,
    required Color fgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fgColor,
        ),
      ),
    );
  }

  void _toggleTheme() async {
    themeNotifier.value = themeNotifier.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', themeNotifier.value == ThemeMode.dark);
  }
}
