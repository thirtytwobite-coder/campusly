import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:ui';
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
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';

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
    await _fetchDashboardData();
  }

  void _listenForNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
                final eventDoc = await FirebaseFirestore.instance.collection('events').doc(eventId).get();
                if (eventDoc.exists && mounted) {
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
                await docRef.update({'read': true});
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
        ? "My College Events"
        : "My Registrations";

    return PopScope(
      canPop: _searchQuery.isEmpty && _selectedDate == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _searchQuery = "";
          _searchController.clear();
          _selectedDate = null;
        });
      },
      child: Scaffold(
        body: Stack(
          children: [
            const VibrantBackground(),
      
            _isLoadingCollege
                ? const Center(child: CircularProgressIndicator())
                : LiquidPullToRefresh(
                    onRefresh: _handleRefresh,
                    color: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surface,
                    showChildOpacityTransition: false,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ),
                                  if (_selectedIndex == 2)
                                    _headerIconButton(
                                      icon: Icons.emoji_events,
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
                                  if (managedClubs.isNotEmpty)
                                    _headerIconButton(
                                      icon: Icons.admin_panel_settings_outlined,
                                      tooltip: "Switch to Coordinator View",
                                      onTap: _handleCoordinatorSwitch,
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
      
                          if (_selectedIndex != 2) ...[
                            _buildTeamInvitesSection(),
                            _buildFuturisticSearchBar(),
                            _buildCategorySection(),
                            const SizedBox(height: 16),
                          ] else ...[
                            _buildFuturisticSearchBar(),
                            const SizedBox(height: 16),
                          ],
      
                          _selectedIndex == 2
                              ? _buildRegisteredEventsList()
                              : _buildClubsWithEvents(),
      
                          const SizedBox(height: 100), // Extra space at bottom
                        ],
                      ),
                    ),
                  ),
          ],
        ),
        bottomNavigationBar: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 80,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: Wrap(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.8) : theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 20,
                      color: Colors.black.withOpacity(.1),
                    )
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
                    child: GNav(
                      rippleColor: isDark ? Colors.white10 : Colors.grey[300]!,
                      hoverColor: isDark ? Colors.white24 : Colors.grey[100]!,
                      gap: 8,
                      activeColor: theme.colorScheme.primary,
                      iconSize: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      duration: const Duration(milliseconds: 400),
                      tabBackgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      color: isDark ? Colors.white60 : theme.colorScheme.onSurface.withOpacity(0.6),
                      tabs: const [
                        GButton(icon: Icons.language, text: 'Public'),
                        GButton(icon: Icons.school, text: 'My College'),
                        GButton(icon: Icons.history, text: 'History'),
                        GButton(icon: Icons.person, text: 'Profile'),
                      ],
                      selectedIndex: _selectedIndex > 3 ? 0 : _selectedIndex,
                      onTabChange: (index) {
                        if (index == 3) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                          return;
                        }
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
          child: GlassCard(
            borderRadius: 12,
            child: Container(
              width: 38,
              height: 38,
              decoration: !isDark ? BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ) : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black),
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
      ),
    );
  }

  Widget _buildTeamInvitesSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.indigo.withOpacity(0.1) : Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.indigo.withOpacity(0.3) : Colors.indigo.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.group_add, color: Colors.indigoAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Recent Team Invites",
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.indigoAccent : Colors.indigo),
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
                        const Icon(Icons.arrow_right, size: 16, color: Colors.indigoAccent),
                        Expanded(
                          child: Text(
                            data['message'] ?? 'New Invitation',
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 14, color: Colors.indigoAccent),
                      ],
                    ),
                  ),
                );
              }),
            ],
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
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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
                      color: isDark ? Colors.white70 : Colors.black45,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Theme(
                        data: theme.copyWith(
                          textSelectionTheme: TextSelectionThemeData(
                            selectionColor: isDark 
                                ? Colors.purpleAccent.withOpacity(0.3)
                                : Colors.blueAccent.withOpacity(0.2),
                            selectionHandleColor: isDark ? Colors.purpleAccent : Colors.blueAccent,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: InputDecoration(
                            hintText: "Search by club or event name....",
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black26,
                              fontWeight: FontWeight.w300,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          cursorColor: isDark ? Colors.white : Colors.blueAccent,
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
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.white.withOpacity(0.05)
                              : Colors.blueAccent.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark 
                                ? Colors.white.withOpacity(0.15)
                                : Colors.blueAccent.withOpacity(0.1),
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.tune_rounded,
                            color: _selectedDate != null 
                              ? (isDark ? Colors.purpleAccent : Colors.blueAccent)
                              : (isDark ? Colors.white70 : Colors.black45),
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
      stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
      builder: (context, clubSnapshot) {
        if (clubSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (clubSnapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text("Error loading clubs: ${clubSnapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
          ));
        }
        if (!clubSnapshot.hasData || clubSnapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No clubs found."));
        }

        final clubs = clubSnapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
                  return const SizedBox.shrink();
                }

                final filteredEvents = eventSnapshot.data!.docs.where((doc) {
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
                  final bool clubMatches = clubName.toLowerCase().contains(_searchQuery);
                  if (!titleMatches && !clubMatches) return false;

                  if (_selectedDate != null) {
                    final selected = DateFormat('yyyy-MM-dd').format(_selectedDate!);
                    if (data['date'] != selected) return false;
                  }

                  return true;
                }).toList();

                // Sort locally
                filteredEvents.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });

                if (filteredEvents.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Text(
                        clubName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 270, // Increased height slightly to accommodate scaling
                      child: _EventCarousel(
                        events: filteredEvents,
                        clubLogo: clubData['profilePic'],
                        cardBuilder: _buildEventCard,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRegisteredEventsList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox(height: 200, child: Center(child: Text("Please login to see registered events")));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('registrations')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, regSnapshot) {
        if (regSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
        }
        if (regSnapshot.hasError) {
          return SizedBox(
            height: 200,
            child: Center(child: Text("Connection Error: ${regSnapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          );
        }

        if (!regSnapshot.hasData || regSnapshot.data!.docs.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_late_outlined, size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                const Text("No registered events found.", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final registeredEventIds = regSnapshot.data!.docs.map((doc) => doc['eventId'] as String).toSet();
        final regDocsMap = {for (var doc in regSnapshot.data!.docs) doc['eventId'] as String: doc};

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

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: clubRegisteredEvents.length,
                          itemBuilder: (context, idx) {
                            final eventDoc = clubRegisteredEvents[idx];
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
                                  index: idx,
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
                          },
                        ),
                      ],
                    );
                  },
                );
              },
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

    // Pick colors based on theme
    final List<List<Color>> gradients = isDark 
      ? [
          [Colors.orangeAccent, Colors.deepOrangeAccent],
          [Colors.blueAccent, Colors.cyanAccent],
          [Colors.purpleAccent, Colors.deepPurpleAccent],
        ]
      : [
          [Colors.lightBlue.shade300, Colors.blue.shade100],
          [Colors.purple.shade300, Colors.deepPurple.shade50],
          [Colors.teal.shade300, Colors.green.shade50],
        ];
    
    final gradientColors = gradients[index % gradients.length];

    Color statusInfoColor = Colors.green.shade100;
    Color statusInfoText = Colors.green.shade900;
    String statusLabel = "UPCOMING";

    if (status == 'ongoing') {
      statusInfoColor = Colors.orange.shade100;
      statusInfoText = Colors.orange.shade900;
      statusLabel = "ONGOING";
    } else if (status == 'completed') {
      statusInfoColor = Colors.grey.shade300;
      statusInfoText = Colors.grey.shade800;
      statusLabel = "COMPLETED";
    }

    // Deadline Check
    bool isRegistrationClosed = false;
    final deadlineDateStr = data['registrationDeadlineDate'];
    final deadlineTimeStr = data['registrationDeadlineTime'];
    if (deadlineDateStr != null && deadlineDateStr.isNotEmpty && deadlineTimeStr != null && deadlineTimeStr.isNotEmpty) {
      try {
        final deadline = DateTime.parse('$deadlineDateStr $deadlineTimeStr:00');
        if (DateTime.now().isAfter(deadline)) {
          isRegistrationClosed = true;
        }
      } catch (e) {
        debugPrint("Error parsing deadline: $e");
      }
    }

    // Capacity Logic
    final int filledSeats = data['filledSeats'] is int ? data['filledSeats'] : int.tryParse(data['filledSeats']?.toString() ?? '') ?? 0;
    final dynamic tsData = data['totalSeats'] ?? data['capacity'] ?? data['maxSeats'];
    final String totalSeatsStr = tsData?.toString() ?? '';
    final int totalSeats = int.tryParse(totalSeatsStr) ?? 0;
    final bool isUnlimited = totalSeatsStr.isEmpty || totalSeatsStr.toLowerCase() == 'unlimited' || totalSeats <= 0;
    final int remainingSeats = isUnlimited ? -1 : (totalSeats - filledSeats > 0 ? totalSeats - filledSeats : 0);
    final bool isEventFull = !isUnlimited && filledSeats >= totalSeats;

    return Container(
      width: isHorizontal ? null : double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isHorizontal ? 8 : 16,
        vertical: 8,
      ),
      child: Stack(
        children: [
          // Soft Shadow / Glow Effect
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isDark 
                        ? gradientColors[0].withOpacity(0.15)
                        : gradientColors[0].withOpacity(0.1),
                    blurRadius: 25,
                    spreadRadius: isDark ? 2 : 0,
                    offset: isDark ? Offset.zero : const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          
          GlassCard(
            borderRadius: 20,
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A).withOpacity(0.7)
                    : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white.withOpacity(0.8),
                  width: 1,
                ),
              ),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EventDetailsScreen(event: doc)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (posterLink != null && posterLink.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: posterLink.startsWith('data:image') ? Image.memory(
                          base64Decode(posterLink.split(',').last),
                          width: double.infinity,
                          height: isHorizontal ? 130 : 150, // Reduced poster height
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: isHorizontal ? 130 : 150,
                            width: double.infinity,
                            color: isDark ? Colors.grey[900] : Colors.grey[100],
                            child: Icon(Icons.image_not_supported, size: 30, color: isDark ? Colors.grey : Colors.grey[400]),
                          ),
                        ) : Image.network(
                          posterLink,
                          width: double.infinity,
                          height: isHorizontal ? 130 : 150, // Reduced poster height
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: isHorizontal ? 130 : 150,
                            width: double.infinity,
                            color: isDark ? Colors.grey[900] : Colors.grey[100],
                            child: Icon(Icons.image_not_supported, size: 30, color: isDark ? Colors.grey : Colors.grey[400]),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8), // Reduced padding
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 32, // Reduced logo size further
                            height: 32,
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? Colors.white.withOpacity(0.1)
                                  : gradientColors[0].withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: (clubLogo != null && clubLogo.isNotEmpty)
                                ? (clubLogo.startsWith('data:image') 
                                    ? Image.memory(
                                        base64Decode(clubLogo.split(',').last),
                                        fit: BoxFit.cover,
                                        width: 32,
                                        height: 32,
                                        errorBuilder: (context, error, stackTrace) => _buildDefaultClubIcon(isDark, gradientColors, data['visibility']),
                                      )
                                    : Image.network(
                                        clubLogo,
                                        fit: BoxFit.cover,
                                        width: 32,
                                        height: 32,
                                        errorBuilder: (context, error, stackTrace) => _buildDefaultClubIcon(isDark, gradientColors, data['visibility']),
                                      ))
                                : _buildDefaultClubIcon(isDark, gradientColors, data['visibility']),
                            ),
                          ),
                          const SizedBox(width: 10), // Reduced spacing
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['title'] ?? "Untitled Event",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13, // Reduced text size further
                                    color: isDark ? Colors.white : Colors.black87,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                Text(
                                  "${data['college'] ?? "General"} - $eventDate",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10, // Reduced text size further
                                    color: isDark ? Colors.white70 : Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: [
                                    _eventTag(statusLabel, bgColor: statusInfoColor, fgColor: statusInfoText),
                                    if (isRegistrationClosed)
                                      _eventTag("Closed", bgColor: Colors.red.withOpacity(0.1), fgColor: Colors.red.shade700)
                                    else if (isEventFull)
                                      _eventTag("FULL", bgColor: Colors.red.withOpacity(0.1), fgColor: Colors.red.shade700)
                                    else if (!isUnlimited)
                                      _eventTag("$remainingSeats / $totalSeats SEATS", bgColor: Colors.blue.withOpacity(0.1), fgColor: Colors.blue.shade700)
                                    else
                                      _eventTag("OPEN", bgColor: Colors.blue.withOpacity(0.1), fgColor: Colors.blue.shade700),
                                    
                                    if (isTeamEvent)
                                      _eventTag("Team", bgColor: Colors.purple.withOpacity(0.1), fgColor: Colors.purple.shade700),
                                    if (prize.isNotEmpty && prize != "0")
                                      _eventTag("Rs.$prize", bgColor: Colors.amber.withOpacity(0.1), fgColor: Colors.amber.shade900),
                                    if (!isRegistrationClosed && deadlineDateStr != null && deadlineDateStr.isNotEmpty)
                                      _eventTag("Deadline: $deadlineDateStr", bgColor: Colors.teal.withOpacity(0.1), fgColor: Colors.teal.shade700),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Thin Gradient Border (Neon for dark, Subtle for light)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GradientPainter(
                  strokeWidth: isDark ? 2 : 1.2,
                  radius: 20,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark 
                      ? [
                          gradientColors[0],
                          gradientColors[1].withOpacity(0.2),
                          gradientColors[0].withOpacity(0.5),
                        ]
                      : [
                          gradientColors[0].withOpacity(0.5),
                          gradientColors[0].withOpacity(0.1),
                          gradientColors[0].withOpacity(0.3),
                        ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: (index * 100).ms)
      .fadeIn(duration: 500.ms, curve: Curves.easeOut)
      .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.easeOutBack)
      .moveY(begin: 30, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }

  Widget _buildDefaultClubIcon(bool isDark, List<Color> gradientColors, String? visibility) {
    return Icon(
      (visibility == 'college') ? Icons.school : Icons.public,
      color: isDark ? gradientColors[0] : gradientColors[0].withOpacity(0.8),
      size: 16, // Reduced size further
    );
  }

  Widget _eventTag(String text, {required Color bgColor, required Color fgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Reduced padding
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: fgColor)), // Reduced font size further
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
        double scale = (1.0 - (delta * 0.12)).clamp(0.88, 1.0);
        double opacity = (1.0 - (delta * 0.25)).clamp(0.75, 1.0);

        return Transform.scale(
          scale: scale,
          alignment: Alignment.centerLeft,
          child: Opacity(
            opacity: opacity,
            child: widget.cardBuilder(
              widget.events[index],
              isHorizontal: true,
              index: index,
              clubLogo: widget.clubLogo,
            ),
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
