import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'main.dart';
import 'event_details.dart';
import 'profile_screen.dart';
import 'club_coordinator_dashboard.dart';
import 'vibrant_background.dart';
import 'participation_history.dart';
import 'notification_service.dart';
import 'feedback_screen.dart';
import 'package:college_event_manager/scooped_navbar.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'student_directory_screen.dart';

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
  late ScrollController _scrollController;
  int _unreadNotifications = 0;
  bool _isInitialLoad = true;
  bool _isNavbarVisible = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _fetchDashboardData();
    _requestNotificationPermission();
    _listenForNotifications();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _isInitialLoad = false;
    });
  }

  Future<void> _requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  // 🔹 Fetch student data and managed clubs
  Future<void> _fetchDashboardData() async {
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
        }
      } catch (e) {
        debugPrint("Error fetching dashboard data: $e");
      }
    }
    if (mounted) setState(() => _isLoadingCollege = false);
  }

  Future<void> _handleRefresh() async {
    // Refresh dashboard data
    await _fetchDashboardData();
  }

  void _listenForNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Listen for new ongoing events (Global/College)
    FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'ongoing')
        .snapshots()
        .listen((snapshot) {
      if (!mounted || _isInitialLoad) return;
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>?;
          final eventCollege = (data?['college'] ?? '').toString();
          final visibility = (data?['visibility'] ?? 'public').toString().toLowerCase();

          bool shouldNotify = visibility == 'public' || 
                             (studentCollege != null && eventCollege.toLowerCase() == studentCollege!.toLowerCase());

          if (shouldNotify) {
            NotificationService.showNotification(
              id: change.doc.id.hashCode,
              title: 'New Event Live!',
              body: '${data?['title']} has just started. Register now!',
            );
          }
        }
      }
    });

    // 2. Listen for personal Team Invitations count
    FirebaseFirestore.instance
        .collection('student')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _unreadNotifications = snapshot.docs.length;
      });

      if (_isInitialLoad) return;

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data != null) {
            NotificationService.showNotification(
              id: change.doc.id.hashCode,
              title: data['title'] ?? 'New Request',
              body: data['message'] ?? 'You have a new team invitation.',
            );
          }
        }
      }
    });
  }

  Future<void> _confirmInvite(DocumentReference docRef, Map<String, dynamic> data) async {
    final String? eventId = data['eventId'];
    final bool isAlreadyRead = data['read'] ?? false;
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              data['type'] == 'team_invite' ? Icons.group_add : Icons.notifications,
              color: Colors.indigo,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                data['title'] ?? 'Notification',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(data['message'] ?? 'You have a new message.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(color: Colors.grey)),
          ),
          if (eventId != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final eventDoc = await FirebaseFirestore.instance.collection('events').doc(eventId).get();                if (eventDoc.exists && mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(event: eventDoc)));
                }
              },
              child: const Text("View Event", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
            ),
          if (!isAlreadyRead)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);

                // 1. Mark notification as read
                await docRef.update({'read': true});

                // 2. 🔹 Update the registration status to confirmed
                final String? regId = data['regId'];
                if (data['type'] == 'team_invite' && regId != null) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('registrations')
                        .doc(regId)
                        .update({'status': 'confirmed'});
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Team participation confirmed!')),
                      );
                    }
                  } catch (e) {
                    debugPrint("Error confirming registration: $e");
                  }
                }
              },
              child: const Text("Acknowledge"),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text("Acknowledged", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  void _showNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Notifications"),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('student')
                .doc(user.uid)
                .collection('notifications')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No new requests"));
              }
              final docs = snapshot.data!.docs;
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isRead = data['read'] ?? false;
                  return ListTile(
                    leading: Icon(
                      data['type'] == 'team_invite' ? Icons.group_add : Icons.notifications,
                      color: isRead ? Colors.grey : Colors.indigo,
                    ),
                    title: Text(
                      data['title'] ?? 'Team Request',
                      style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(data['message'] ?? '', style: const TextStyle(fontSize: 12)),
                    onTap: () => _confirmInvite(doc.reference, data),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

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
    final isDark = theme.brightness == Brightness.dark;
    final sectionTitle = _selectedIndex == 0
        ? "Public Events"
        : _selectedIndex == 1
        ? "Campus Events"
        : "My Registered Events";

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
                          child: GlassCard(
                            borderRadius: 24,
                            blur: 15,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      sectionTitle,
                                      style: theme.textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1.0,
                                        fontSize: 20,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2),
                                  ),
                                  if (_selectedIndex == 2)
                                    _headerIconButton(
                                      icon: Icons.emoji_events_rounded,
                                      tooltip: "My Awards",
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const ParticipationHistoryScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  _headerIconButton(
                                    icon: Icons.notifications_none_rounded,
                                    tooltip: "Notifications",
                                    onTap: _showNotifications,
                                    badgeCount: _unreadNotifications,
                                  ),
                                  _headerIconButton(
                                    icon: Icons.people_alt_rounded,
                                    tooltip: "Student Directory",
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const StudentDirectoryScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  if (managedClubs.isNotEmpty)
                                    _headerIconButton(
                                      icon: Icons.admin_panel_settings_outlined,
                                      tooltip: "Coordinator View",
                                      onTap: _handleCoordinatorSwitch,
                                    ),
                                  _headerIconButton(
                                    icon: Icons.brightness_6_rounded,
                                    tooltip: "Theme",
                                    onTap: _toggleTheme,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (_selectedIndex != 2) ...[
                        _buildTeamInvitesSection(),
                        _buildFuturisticSearchBar(),
                        _buildCategorySection(),
                        const SizedBox(height: 16),
                      ] else ...[
                        _buildFuturisticSearchBar(),
                        const SizedBox(height: 16),
                      ],

                      Expanded(
                        child: _selectedIndex == 2
                            ? _buildRegisteredEventsList()
                            : _buildClubsWithEvents(),
                      ),

                      const SizedBox(height: 100), // Extra space at bottom
                    ],
                  ),
        ],
      ),
      bottomNavigationBar: ScoopedNavigationBar(
        currentIndex: _selectedIndex > 3 ? 0 : _selectedIndex,
        onTap: (index) {
          if (index == 3) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            return;
          }
          setState(() => _selectedIndex = index);
        },
        activeColor: theme.colorScheme.primary,
        items: const [
          ScoopedNavItem(icon: Icons.language_rounded, label: 'Public'),
          ScoopedNavItem(icon: Icons.school_rounded, label: 'Campus'),
          ScoopedNavItem(icon: Icons.history_rounded, label: 'History'),
          ScoopedNavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(isDark ? 0.05 : 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                width: 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 20),
                if (badgeCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                      child: Text(
                        badgeCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamInvitesSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('student')
          .doc(user.uid)
          .collection('notifications')
          .where('type', isEqualTo: 'team_invite')
          .where('read', isEqualTo: false)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

        return GlassCard(
          borderRadius: 20,
          blur: 10,
          color: Colors.indigo.withOpacity(0.05),
          border: Border.all(color: Colors.indigo.withOpacity(0.1), width: 1.5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.group_add, color: Colors.indigo, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "Recent Team Invites",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    onTap: () => _confirmInvite(doc.reference, data),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_right, size: 16, color: Colors.indigo),
                        Expanded(
                          child: Text(
                            data['message'] ?? 'New Invitation',
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 14, color: Colors.indigo),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ).animate().fadeIn().slideX();
      },
    );
  }

  Widget _buildFuturisticSearchBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Stack(
        children: [
          // Background Glow Effect
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isDark 
                        ? Colors.purpleAccent.withOpacity(0.3)
                        : Colors.purpleAccent.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: -2,
                    offset: const Offset(-5, 0),
                  ),
                  BoxShadow(
                    color: isDark 
                        ? Colors.blueAccent.withOpacity(0.3)
                        : Colors.blueAccent.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: -2,
                    offset: const Offset(5, 0),
                  ),
                ],
              ),
            ),
          ),

          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A).withOpacity(0.85)
                      : Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Theme(
                        data: theme.copyWith(
                          textSelectionTheme: TextSelectionThemeData(
                            selectionColor: Colors.purpleAccent.withOpacity(0.3),
                            selectionHandleColor: Colors.purpleAccent,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                          ),
                          decoration: InputDecoration(
                            hintText: "Search by club or event name....",
                            hintStyle: TextStyle(
                              color: (isDark ? Colors.white38 : Colors.black38),
                              fontWeight: FontWeight.w300,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          cursorColor: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white70 : Colors.black45,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchQuery = "";
                            _searchController.clear();
                          });
                        },
                      ),

                    // Filter box
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.15),
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.tune_rounded,
                            color: _selectedDate != null 
                              ? Colors.purpleAccent 
                              : (isDark ? Colors.white70 : Colors.black54),
                            size: 20,
                          ),
                          onPressed: () => _selectDate(context),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Neon Border
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GradientPainter(
                  strokeWidth: 1.8,
                  radius: 20,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark 
                      ? [
                          Colors.purpleAccent.withOpacity(0.9),
                          Colors.purpleAccent.withOpacity(0.1),
                          Colors.blueAccent.withOpacity(0.1),
                          Colors.blueAccent.withOpacity(0.9),
                        ]
                      : [
                          Colors.purpleAccent.withOpacity(0.6),
                          Colors.purpleAccent.withOpacity(0.1),
                          Colors.blueAccent.withOpacity(0.1),
                          Colors.blueAccent.withOpacity(0.6),
                        ],
                    stops: const [0.0, 0.4, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    final categories = ["All", "Technical", "Cultural", "Sports", "Academic", "Social"];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Event Categories",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(categories[i]),
                  selected: selectedCategory == categories[i],
                  onSelected: (_) => setState(() => selectedCategory = categories[i]),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selectedCategory == categories[i]
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  selectedColor: themeNotifier.value == ThemeMode.light ? Theme.of(context).colorScheme.primary : Colors.indigoAccent,
                  backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Theme.of(context).colorScheme.surface.withOpacity(0.82),
                  side: BorderSide(
                    color: selectedCategory == categories[i]
                        ? Colors.transparent
                        : (isDark ? Colors.white.withOpacity(0.1) : Theme.of(context).colorScheme.outline.withOpacity(0.25)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubsWithEvents() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
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
          final visibility = (data['visibility'] ?? "public").toString().toLowerCase().trim();
          final status = (data['status'] ?? "approved").toString().toLowerCase().trim();

          if (status != 'ongoing' && status != 'approved') return false;

          final isFromMyCollege = studentCollege != null &&
              eventCollege.isNotEmpty &&
              eventCollege.toLowerCase() == studentCollege!.toLowerCase();

          if (_selectedIndex == 0) {
            if (visibility != 'public') return false;
          } else {
            if (!isFromMyCollege) return false;
          }

          if (selectedCategory != "All" && data['category'] != selectedCategory) return false;
          
          final bool titleMatches = (data['title'] ?? "").toString().toLowerCase().contains(_searchQuery);
          if (!titleMatches) return false;

          if (_selectedDate != null) {
            final selected = DateFormat('yyyy-MM-dd').format(_selectedDate!);
            if (data['date'] != selected) return false;
          }

          return true;
        }).toList();

        // Sort locally
        filteredDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        if (filteredDocs.isEmpty) {
          return LiquidPullToRefresh(
            onRefresh: _handleRefresh,
            showChildOpacityTransition: false,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
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
                  ),
                ),
              ],
            ),
          );
        }

        return LiquidPullToRefresh(
          onRefresh: _handleRefresh,
          showChildOpacityTransition: false,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filteredDocs.length,
            padding: const EdgeInsets.only(bottom: 20),
            itemBuilder: (context, index) => _buildEventCard(filteredDocs[index]),
          ),
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
          return LiquidPullToRefresh(
            onRefresh: _handleRefresh,
            showChildOpacityTransition: false,
            child: ListView(
              children: [
                SizedBox(
                  height: 200,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.assignment_late_outlined, size: 60, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text("No registered events found.", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final registeredEventIds = snapshot.data!.docs.map((doc) => doc['eventId'] as String).toSet();
        final regDocsMap = {for (var doc in snapshot.data!.docs) doc['eventId'] as String: doc};

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
          builder: (context, clubSnapshot) {
            if (clubSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox();
            }
            if (!clubSnapshot.hasData || clubSnapshot.data!.docs.isEmpty) {
              return const SizedBox();
            }

            final clubs = clubSnapshot.data!.docs;

            return LiquidPullToRefresh(
              onRefresh: _handleRefresh,
              showChildOpacityTransition: false,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: clubs.length,
                itemBuilder: (context, index) {
                  final clubData = clubs[index].data() as Map<String, dynamic>;
                  final clubId = clubs[index].id;
                  final clubName = clubData['clubName'] ?? clubData['name'] ?? 'Unnamed Club';

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('events')
                        .where('clubId', isEqualTo: clubId)
                        .snapshots(),
                    builder: (context, eventSnapshot) {
                      if (!eventSnapshot.hasData || eventSnapshot.data!.docs.isEmpty) {
                        return const SizedBox();
                      }

                      final clubRegisteredEvents = eventSnapshot.data!.docs
                          .where((doc) {
                            if (!registeredEventIds.contains(doc.id)) return false;
                            final data = doc.data() as Map<String, dynamic>;
                            
                            // Search query filter
                            final String title = (data['title'] ?? "").toString().toLowerCase();
                            final String clubNameLower = clubName.toLowerCase();
                            if (!title.contains(_searchQuery) && !clubNameLower.contains(_searchQuery)) return false;

                            // Date filter
                            if (_selectedDate != null) {
                              final selected = DateFormat('yyyy-MM-dd').format(_selectedDate!);
                              if (data['date'] != selected) return false;
                            }

                            return true;
                          })
                          .toList();

                      if (clubRegisteredEvents.isEmpty) return const SizedBox();

                      // Sort locally
                      clubRegisteredEvents.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final aTime = aData['createdAt'] as Timestamp?;
                        final bTime = bData['createdAt'] as Timestamp?;
                        if (aTime == null || bTime == null) return 0;
                        return bTime.compareTo(aTime);
                      });

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                            child: Text(
                              clubName,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          ...clubRegisteredEvents.map((eventDoc) {
                            final regDoc = regDocsMap[eventDoc.id]!;
                            final regData = regDoc.data() as Map<String, dynamic>;
                            final eventData = eventDoc.data() as Map<String, dynamic>;
                            final bool isCompleted = eventData['status'] == 'completed';
                            final bool participated = regData['participated'] == true;

                            return Column(
                              children: [
                                _buildEventCard(
                                  eventDoc,
                                  isHorizontal: false,
                                  index: 0,
                                  clubLogo: clubData['profilePic'],
                                ),
                                if (isCompleted || participated)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: regData['rating'] != null
                                          ? null
                                          : () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => FeedbackScreen(
                                                    registrationRef: regDoc.reference,
                                                    eventTitle: regData['eventTitle'] ?? 'Event',
                                                  ),
                                                ),
                                              );
                                            },
                                        icon: Icon(
                                          regData['rating'] != null ? Icons.check_circle_outline : Icons.feedback_outlined,
                                          size: 18,
                                        ),
                                        label: Text(regData['rating'] != null ? "Feedback Submitted" : "Share Feedback"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: regData['rating'] != null ? Colors.grey.shade400 : Colors.amber.shade700,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }).toList(),
                        ],
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
  Widget _buildEventCard(DocumentSnapshot doc, {bool isHorizontal = false, int index = 0, String? clubLogo}) {
    final data = doc.data() as Map<String, dynamic>;
    final prize = (data['prizeAmount'] ?? "").toString();
    final eventDate = data['date'] ?? "TBD";
    final posterLink = data['posterLink'] as String?;
    final bool isTeamEvent = (data['isTeamEvent'] ?? false) == true;
    final status = (data['status'] ?? 'approved').toString().toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    Color statusInfoColor = Colors.orange.shade100;
    Color statusInfoText = Colors.orange.shade900;
    String statusLabel = "ONGOING";

    if (status == 'completed') {
      statusInfoColor = Colors.grey.shade300;
      statusInfoText = Colors.grey.shade800;
      statusLabel = "COMPLETED";
    }

    final List<Color> gradientColors = isDark 
        ? [Colors.blueAccent, Colors.purpleAccent] 
        : [theme.primaryColor, theme.primaryColor.withOpacity(0.7)];

    return Container(
      width: isHorizontal ? MediaQuery.of(context).size.width * 0.85 : double.infinity,
      margin: EdgeInsets.symmetric(
        horizontal: isHorizontal ? 8 : 16,
        vertical: 8,
      ),
      child: GlassCard(
        borderRadius: 24,
        blur: 12,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EventDetailsScreen(event: doc)),
          ),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (posterLink != null && posterLink.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: posterLink.startsWith('data:image') ? Image.memory(
                    base64Decode(posterLink.split(',').last),
                    width: double.infinity,
                    height: isHorizontal ? 150 : 185,
                    fit: BoxFit.cover,
                  ) : Image.network(
                    posterLink,
                    width: double.infinity,
                    height: isHorizontal ? 150 : 185,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey.withOpacity(0.1),
                      child: const Icon(Icons.broken_image_rounded),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: (clubLogo != null && clubLogo.isNotEmpty)
                          ? (clubLogo.startsWith('data:image') 
                              ? Image.memory(
                                  base64Decode(clubLogo.split(',').last),
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  clubLogo,
                                  fit: BoxFit.cover,
                                ))
                          : _buildDefaultClubIcon(isDark, gradientColors, data['visibility']),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title'] ?? "Untitled Event",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "${data['college'] ?? "General"} • $eventDate",
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _eventTag(statusLabel, bgColor: statusInfoColor.withOpacity(0.12), fgColor: statusInfoText),
                    if (isTeamEvent)
                      _eventTag("Team", bgColor: Colors.purple.withOpacity(0.12), fgColor: Colors.purple.shade900),
                    if (prize.isNotEmpty && prize != "0")
                      _eventTag("₹$prize Prize", bgColor: Colors.green.withOpacity(0.12), fgColor: Colors.green.shade900),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate(delay: (index * 100).ms)
       .fadeIn(duration: 500.ms)
       .slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildDefaultClubIcon(bool isDark, List<Color> gradientColors, String? visibility) {
    return Icon(
      (visibility == 'college') ? Icons.school_rounded : Icons.public_rounded,
      color: isDark ? Colors.blueAccent : Colors.indigo,
      size: 20,
    );
  }

  Widget _eventTag(String text, {required Color bgColor, required Color fgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fgColor)),
    );
  }

  void _toggleTheme() async {
    themeNotifier.value = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', themeNotifier.value == ThemeMode.dark);
  }
}

class _EventCarousel extends StatefulWidget {
  final List<DocumentSnapshot> events;
  final String? clubLogo;
  final Widget Function(DocumentSnapshot, {bool isHorizontal, int index, String? clubLogo}) cardBuilder;

  const _EventCarousel({
    required this.events,
    this.clubLogo,
    required this.cardBuilder,
  });

  @override
  State<_EventCarousel> createState() => _EventCarouselState();
}

class _EventCarouselState extends State<_EventCarousel> {
  late PageController _pageController;
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _pageController.page ?? 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.events.length,
      padEnds: false,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        double delta = (index - _currentPage).abs();
        double scale = (1.0 - (delta * 0.1)).clamp(0.9, 1.0);
        return Transform.scale(
          scale: scale,
          alignment: Alignment.centerLeft,
          child: widget.cardBuilder(
            widget.events[index],
            isHorizontal: true,
            index: index,
            clubLogo: widget.clubLogo,
          ),
        );
      },
    );
  }
}

class _GradientPainter extends CustomPainter {
  final double strokeWidth;
  final double radius;
  final Gradient gradient;

  _GradientPainter({required this.strokeWidth, required this.radius, required this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
