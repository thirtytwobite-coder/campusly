/// This is the main dashboard screen for club coordinators.
/// It provides navigation between different sections like analytics, certificates, programs, and profile.
/// The dashboard displays club information, handles notifications, and allows coordinators
/// to manage their club's events, programs, and member interactions through various sub-screens.
/// It includes a bottom navigation bar for easy access to different functionalities.

import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/rendering.dart';
import 'analytics_dashboard_screen.dart';
import 'analytics_screen.dart';
import 'certificates_screen.dart';
import 'club_feedback_screen.dart';
import 'main.dart';
import 'manage_programs.dart';
import 'profile_screen.dart';
import 'student_home.dart';
import 'vibrant_background.dart';
import 'event_registrations_list.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';
import 'push_notification_sender.dart';

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
  String? userName;
  int _selectedIndex = 0;
  bool _loading = true;
  String searchQuery = '';
  bool _isNavbarVisible = true;

  @override
  void initState() {
    super.initState();
    clubId = widget.initialClubId;
    clubName = widget.initialClubName;
    _fetchUserInfo();
    if (clubId == null) {
      _fetchClubInfo();
    } else {
      _loading = false;
    }
  }

  Future<void> _fetchUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final studentDoc = await FirebaseFirestore.instance
          .collection('student')
          .doc(user.uid)
          .get();
      if (studentDoc.exists) {
        setState(() {
          userName = studentDoc.data()?['name'];
        });
      }
    }
  }

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

  void _onItemTapped(int index) async {
    if (index == _selectedIndex) return;

    if (index == 1 && clubId != null) {
      _showAddProgramProcedure(context);
    } else if (index == 2) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final exit = await _showExitDialog() ?? false;
        if (exit && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          title: Text(
            clubName ?? 'Coordinator Dashboard',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.0),
          ),
          backgroundColor: Colors.transparent,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                color: (isDark ? Colors.black : Colors.white).withOpacity(isDark ? 0.4 : 0.6),
              ),
            ),
          ),
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
              tooltip: "Switch to Student View",
              icon: const Icon(Icons.person_pin_circle_outlined),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
                );
              },
            ),
            IconButton(
              tooltip: "Notifications",
              icon: const Icon(Icons.notifications_outlined),
              onPressed: _showNotifications,
            ),

            IconButton(
              icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              onPressed: _toggleTheme,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            const VibrantBackground(),
            _loading
                ? _buildLoadingState()
                : clubId == null
                    ? const Center(child: Text("No club assigned"))
                    : _buildDashboardBody(),
          ],
        ),
        bottomNavigationBar: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isNavbarVisible ? (kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom) : 0,
          child: _isNavbarVisible ? SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 12,
              unselectedFontSize: 10,
              currentIndex: _selectedIndex > 2 ? 0 : _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: Colors.blueAccent,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline_rounded), label: 'Create'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
              ],
            ),
          ) : const SizedBox.shrink(),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId!)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        final clubData = snapshot.data!.data() as Map<String, dynamic>;
        final description = clubData['description'] ?? 'No description set.';
        
        final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
        final bool hasCertificate = (clubData['sentCoordinatorCerts'] as List<dynamic>?)?.contains(currentUserEmail) ?? false;

        return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome Back,",
                style: TextStyle(
                  color: isDark ? Colors.greenAccent : Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.4),
              Text(
                userName ?? "Coordinator",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 200.ms)
                  .slideX(begin: -0.2),

              if (hasCertificate) ...[
                const SizedBox(height: 20),
                _buildCoordinatorCertificateBanner(),
              ],
              
              const SizedBox(height: 25),

              _clubDescriptionCard(description),

              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      "Analytics",
                      "View Stats",
                      Icons.analytics_rounded,
                      Colors.blueAccent,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AnalyticsDashboardScreen(
                              clubId: clubId!,
                              clubName: clubName ?? 'Club',
                              coordinatorId:
                              FirebaseAuth.instance.currentUser?.uid,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildQuickActionCard(
                      "Certificates",
                      "Issue & Winners",
                      Icons.card_membership_rounded,
                      Colors.orangeAccent,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CertificatesScreen(
                              clubId: clubId!,
                              clubName: clubName ?? 'Club',
                              coordinatorId:
                              FirebaseAuth.instance.currentUser?.uid,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildFullWidthActionCard(
                "Feedback",
                "Student Reviews",
                Icons.rate_review_rounded,
                const Color(0xFF10B981),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClubFeedbackScreen(
                        clubId: clubId!,
                        clubName: clubName ?? 'Club',
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              Text(
                "Events",
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 18,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 15),

              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: TextField(
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search events...',
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400]),
                      prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white38 : Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: isDark ? BorderSide(color: Colors.white.withOpacity(0.1)) : BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: isDark ? BorderSide(color: Colors.white.withOpacity(0.1)) : BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: isDark ? Colors.blueAccent.withOpacity(0.5) : Colors.blueAccent),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
              ),
              const SizedBox(height: 15),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId!)
                    .collection('programs')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return Text('Error: ${snapshot.error}');
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.event_note,
                              size: 60,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No events created yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _showAddProgramProcedure(context),
                              child: const Text("Create your first event"),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  var docs = snapshot.data!.docs;

                  if (searchQuery.isNotEmpty) {
                    docs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? data['title'] ?? '').toString().toLowerCase();
                      return name.contains(searchQuery);
                    }).toList();
                  }

                  if (docs.isEmpty && snapshot.data!.docs.isNotEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 60,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No events found matching your search',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final programDoc = docs[index];
                      final programData =
                      programDoc.data() as Map<String, dynamic>;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: ProgramCard(
                          programId: programDoc.id,
                          clubId: clubId!,
                          programData: programData,
                          onEdit: () => _showEditProgramDialog(
                            context,
                            programDoc.id,
                            programData,
                          ),
                          onDelete: () => _confirmDelete(context, programDoc.id),
                          onStatusChange: (newStatus) =>
                              _requestStatusChange(programDoc.id, newStatus),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _clubDescriptionCard(String description) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.35),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Club Description",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, size: 24, color: Colors.blueAccent),
                      onPressed: () => _showEditDescriptionDialog(description),
                    ),
                  ],
                ),
                Divider(color: (isDark ? Colors.white : Colors.black).withOpacity(0.06)),
                const SizedBox(height: 8),
                Text(
                  description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.6,
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildCoordinatorCertificateBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAB308), Color(0xFFCA8A04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEAB308).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Certificate Issued!",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: -0.5),
                ),
                SizedBox(height: 4),
                Text(
                  "Your leadership certificate is ready to download.",
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CertificatesScreen(
                    clubId: clubId!,
                    clubName: clubName ?? '',
                    isFaculty: false,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFCA8A04),
              elevation: 4,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text("View", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.2);
  }

  Widget _buildQuickActionCard(
      String title,
      String subtitle,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? color.withOpacity(0.05) : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withOpacity(isDark ? 0.2 : 0.4),
                  width: 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(isDark ? 0.15 : 0.1),
                    color.withOpacity(isDark ? 0.05 : 0.02),
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 28, color: color),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildFullWidthActionCard(
      String title,
      String subtitle,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: isDark ? color.withOpacity(0.05) : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withOpacity(isDark ? 0.2 : 0.4),
                  width: 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(isDark ? 0.15 : 0.1),
                    color.withOpacity(isDark ? 0.05 : 0.02),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 28, color: color),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white54 : Colors.black38),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2).scale(begin: const Offset(0.9, 0.9));
  }



  void _showAddProgramProcedure(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Program Proposal Procedure",
              style: TextStyle(
                fontSize: 22, 
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Follow these steps to submit a new event for approval.",
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildStep(
              icon: Icons.edit_note,
              title: "1. Basic Info",
              description: "Provide event name, category, and a clear description.",
              isDark: isDark,
            ),
            _buildStep(
              icon: Icons.calendar_month,
              title: "2. Schedule",
              description: "Pick a date and time that doesn't conflict with other events.",
              isDark: isDark,
            ),
            _buildStep(
              icon: Icons.location_on_outlined,
              title: "3. Venue",
              description: "Specify the exact location/venue for the event.",
              isDark: isDark,
            ),
            _buildStep(
              icon: Icons.visibility_outlined,
              title: "4. Scope",
              description: "Choose if the event is 'College Only' or open to the 'Public'.",
              isDark: isDark,
            ),
            _buildStep(
              icon: Icons.send_rounded,
              title: "5. Faculty Review",
              description: "Once proposed, faculty will review and notify you of the status.",
              isDark: isDark,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(context);
                      _showAddProgramDialog(context);
                    },
                    child: const Center(
                      child: Text(
                        "PROCEED TO PROPOSAL FORM",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required IconData icon,
    required String title,
    required String description,
    bool isDark = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.withOpacity(0.12) : Colors.blue[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (isDark) BoxShadow(
                        color: Colors.blue.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: isDark ? Colors.blueAccent : Colors.blue[700], size: 22),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProgramDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final dateController = TextEditingController();
    final locationController = TextEditingController();
    final timeController = TextEditingController();
    final prizeAmountController = TextEditingController();
    final posterLinkController = TextEditingController();
    final totalSeatsController = TextEditingController();
    bool hasPrizePool = false;
    String visibility = 'college';
    String? category;
    String? eventMode;
    bool requiresVolunteers = false;
    final volunteerCountController = TextEditingController();
    final volunteerRoleController = TextEditingController();
    bool isTeamEvent = false;
    final teamSizeController = TextEditingController();
    final deadlineDateController = TextEditingController();
    final deadlineTimeController = TextEditingController();

    bool isUploadingPoster = false;
    String? errorMessage = '';



    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.6 : 0.2),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Material(
                color: isDark ? Colors.black.withOpacity(0.85) : Colors.white.withOpacity(0.92),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500, maxHeight: 750),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Propose Program",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 24,
                                    letterSpacing: -1.2,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                Text(
                                  "Fill in the details for faculty approval",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded),
                            style: IconButton.styleFrom(
                              backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: StatefulBuilder(
                            builder: (context, setDialogState) => Column(
                              children: [
                                // Poster Upload
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          gradient: LinearGradient(
                                            colors: isUploadingPoster
                                              ? [Colors.grey, Colors.grey]
                                              : [Colors.blueAccent, Colors.blue.shade700],
                                          ),
                                          boxShadow: [
                                            if (!isUploadingPoster)
                                              BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                                          ],
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: isUploadingPoster ? null : () async {
                                            final picker = ImagePicker();
                                            final pickedFile = await picker.pickImage(
                                              source: ImageSource.gallery,
                                              imageQuality: 50,
                                              maxWidth: 800,
                                            );
                                            if (pickedFile == null) return;

                                            setDialogState(() {
                                              isUploadingPoster = true;
                                            });

                                            try {
                                              final bytes = await pickedFile.readAsBytes();
                                              if (bytes.isNotEmpty) {
                                                final base64String = base64Encode(bytes);
                                                posterLinkController.text = 'data:image/jpeg;base64,$base64String';
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Poster successfully attached!'), backgroundColor: Colors.green),
                                                  );
                                                }
                                              }
                                            } catch(e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Failed to read poster: $e'), backgroundColor: Colors.red),
                                                );
                                              }
                                            } finally {
                                              setDialogState(() {
                                                isUploadingPoster = false;
                                              });
                                            }
                                          },
                                          icon: isUploadingPoster
                                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                              : const Icon(Icons.image, color: Colors.white),
                                          label: Text(
                                              isUploadingPoster
                                                  ? 'Processing...'
                                                  : (posterLinkController.text.isNotEmpty ? 'Poster Attached ✅' : 'Attach Poster Image *'),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            padding: const EdgeInsets.symmetric(vertical: 18),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildProposalField(nameController, 'Program Name *', isDark),
                                _buildProposalField(descriptionController, 'Description *', isDark, maxLines: 4),
                                Row(
                                  children: [
                                    Expanded(child: _buildProposalField(totalSeatsController, 'Total Seats (Capacity) *', isDark, keyboardType: TextInputType.number)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: DropdownButtonFormField<String>(
                                          dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                          value: category,
                                          hint: Text('Category *', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey[600], fontWeight: FontWeight.w800)),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          ),
                                          items: ['Technical', 'Cultural', 'Sports', 'Academic', 'Social', 'Other']
                                              .map((l) => DropdownMenuItem(value: l, child: Text(l, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600))))
                                              .toList(),
                                          onChanged: (v) => setDialogState(() => category = v),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: DropdownButtonFormField<String>(
                                          dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                          value: eventMode,
                                          hint: Text('Mode *', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey[600], fontWeight: FontWeight.w800)),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          ),
                                          items: ['Online', 'Offline']
                                              .map((m) => DropdownMenuItem(value: m, child: Text(m, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600))))
                                              .toList(),
                                          onChanged: (v) => setDialogState(() => eventMode = v),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildProposalField(locationController, 'Venue *', isDark)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(child: _buildProposalField(dateController, 'Date *', isDark, readOnly: true, onTap: () async {
                                        final now = DateTime.now();
                                        final firstDate = DateUtils.dateOnly(now);
                                        final d = await showDatePicker(
                                          context: context, 
                                          initialDate: firstDate, 
                                          firstDate: firstDate, 
                                          lastDate: DateTime(2100)
                                        );
                                        if (d != null) {
                                          setDialogState(() {
                                            dateController.text = DateFormat('yyyy-MM-dd').format(d);
                                            // If new event date is before current deadline, clear deadline
                                            if (deadlineDateController.text.isNotEmpty) {
                                              try {
                                                final deadline = DateFormat('yyyy-MM-dd').parse(deadlineDateController.text);
                                                if (deadline.isAfter(d)) {
                                                  deadlineDateController.clear();
                                                }
                                              } catch (_) {}
                                            }
                                          });
                                        }
                                    })),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildProposalField(timeController, 'Time *', isDark, readOnly: true, onTap: () async {
                                        final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                        if (t != null) timeController.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                                    })),
                                  ],
                                ),

                                const SizedBox(height: 12),
                                Divider(color: (isDark ? Colors.white : Colors.black).withOpacity(0.06)),

                                SwitchListTile(
                                  value: hasPrizePool,
                                  title: const Text('Include Prize Pool', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                                  contentPadding: EdgeInsets.zero,
                                  activeColor: Colors.blueAccent,
                                  onChanged: (v) => setDialogState(() {
                                    hasPrizePool = v;
                                    if (!hasPrizePool) prizeAmountController.clear();
                                  }),
                                ),
                                if (hasPrizePool)
                                  _buildProposalField(prizeAmountController, 'Prize Amount', isDark, prefixText: '₹ ', keyboardType: TextInputType.number),



                                SwitchListTile(
                                  value: requiresVolunteers,
                                  title: const Text('Require Volunteers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                                  contentPadding: EdgeInsets.zero,
                                  activeColor: Colors.blueAccent,
                                  onChanged: (v) => setDialogState(() => requiresVolunteers = v),
                                ),
                                if (requiresVolunteers) ...[
                                  _buildProposalField(volunteerCountController, 'Number of Volunteers', isDark, keyboardType: TextInputType.number),
                                  _buildProposalField(volunteerRoleController, 'Volunteer Role / Instructions', isDark, maxLines: 2),
                                ],

                                SwitchListTile(
                                  value: isTeamEvent,
                                  title: const Text('Team Event', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                                  subtitle: Text('Students must register as a team', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey)),
                                  contentPadding: EdgeInsets.zero,
                                  activeColor: Colors.blueAccent,
                                  onChanged: (v) => setDialogState(() => isTeamEvent = v),
                                ),
                                if (isTeamEvent) ...[
                                  _buildProposalField(teamSizeController, 'Team Size', isDark, keyboardType: TextInputType.number),
                                ],

                                const SizedBox(height: 12),
                                Divider(color: (isDark ? Colors.white : Colors.black).withOpacity(0.06)),
                                const SizedBox(height: 12),

                                Text('VISIBILITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 1.5)),
                                Row(
                                  children: [
                                    Expanded(
                                      child: RadioListTile<String>(
                                        value: 'college',
                                        groupValue: visibility,
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('College Only', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                        onChanged: (v) => setDialogState(() => visibility = v!),
                                      ),
                                    ),
                                    Expanded(
                                      child: RadioListTile<String>(
                                        value: 'public',
                                        groupValue: visibility,
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('Public', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                        onChanged: (v) => setDialogState(() => visibility = v!),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),
                                Text('REGISTRATION DEADLINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 1.5)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _buildProposalField(deadlineDateController, 'Deadline Date *', isDark, readOnly: true, onTap: () async {
                                        final now = DateTime.now();
                                        final firstDate = DateUtils.dateOnly(now);
                                        DateTime lastDate = DateTime(2100);
                                        if (dateController.text.isNotEmpty) {
                                          try {
                                            lastDate = DateFormat('yyyy-MM-dd').parse(dateController.text);
                                          } catch (_) {}
                                        }
                                        
                                        final d = await showDatePicker(
                                          context: context, 
                                          initialDate: firstDate.isAfter(lastDate) ? lastDate : firstDate, 
                                          firstDate: firstDate, 
                                          lastDate: lastDate
                                        );
                                        if (d != null) deadlineDateController.text = DateFormat('yyyy-MM-dd').format(d);
                                    })),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildProposalField(deadlineTimeController, 'Deadline Time *', isDark, readOnly: true, onTap: () async {
                                        final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                        if (t != null) deadlineTimeController.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                                    })),
                                  ],
                                ),

                                const SizedBox(height: 24),
                                // Error Message Display
                                if (errorMessage != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.withOpacity(0.3))),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                  ),
                                // Actions
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 56,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF1565C0)]),
                                          boxShadow: [
                                            BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(20),
                                            onTap: () {
                                              final valError = _validateProgramForm(
                                                nameController.text,
                                                descriptionController.text,
                                                dateController.text,
                                                timeController.text,
                                                locationController.text,
                                                category,
                                                eventMode,
                                                posterLinkController.text,
                                              );
                                              if (valError != null) {
                                                setDialogState(() => errorMessage = valError);
                                                return;
                                              }

                                              setDialogState(() => errorMessage = null);
                                              _handlePropose(
                                                ctx,
                                                nameController.text,
                                                descriptionController.text,
                                                dateController.text,
                                                timeController.text,
                                                locationController.text,
                                                hasPrizePool,
                                                prizeAmountController.text,
                                                posterLinkController.text,
                                                visibility,
                                                category,
                                                eventMode,
                                                requiresVolunteers,
                                                volunteerCountController.text,
                                                volunteerRoleController.text,
                                                isTeamEvent,
                                                teamSizeController.text,
                                                totalSeatsController.text,
                                                deadlineDateController.text,
                                                deadlineTimeController.text,

                                              );
                                            },
                                            child: const Center(
                                              child: Text(
                                                "SUBMIT PROPOSAL",
                                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: anim1.drive(CurveTween(curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
    );
  }

  Widget _buildProposalField(TextEditingController controller, String label, bool isDark, {int maxLines = 1, bool readOnly = false, VoidCallback? onTap, TextInputType? keyboardType, String? prefixText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey[600], fontWeight: FontWeight.w800),
          prefixText: prefixText,
          prefixStyle: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.blueAccent.withOpacity(0.5), width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  void _handlePropose(
      BuildContext ctx,
      String name,
      String desc,
      String date,
      String time,
      String loc,
      bool hasPrize,
      String prize,
      String poster,
      String vis,
      String? cat,
      String? mode,
      bool requiresVolunteers,
      String volunteerCount,
      String volunteerRole,
      bool isTeamEvent,
      String teamSize,
      String totalSeats,
      String deadlineDate,
      String deadlineTime,

      ) async {
    if (name.trim().isEmpty ||
        desc.trim().isEmpty ||
        date.trim().isEmpty ||
        time.trim().isEmpty ||
        loc.trim().isEmpty ||
        totalSeats.trim().isEmpty ||
        deadlineDate.isEmpty ||
        deadlineTime.isEmpty ||
        poster.trim().isEmpty ||
        cat == null ||
        mode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill all required fields (Name, Description, Total Seats, Date, Time, Venue, Category, Event Mode, Deadline, and Poster Image)',
          ),
        ),
      );
      return;
    }
    final int parsedTotalSeats = int.tryParse(totalSeats.trim()) ?? 0;
    if (parsedTotalSeats < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Total Seats must be a valid number greater than 0.'),
        ),
      );
      return;
    }
    if (isTeamEvent) {
      final parsedTeamSize = int.tryParse(teamSize.trim()) ?? 0;
      if (parsedTeamSize < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team size must be at least 2 for team events.'),
          ),
        );
        return;
      }
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      DocumentSnapshot uDoc = await FirebaseFirestore.instance
          .collection('student')
          .doc(user?.uid)
          .get();
      if (!uDoc.exists)
        uDoc = await FirebaseFirestore.instance
            .collection('faculty')
            .doc(user?.uid)
            .get();
      final nameStr =
          (uDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Unknown';
      final coll =
          (uDoc.data() as Map<String, dynamic>?)?['college'] ?? 'Unknown';

      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId!)
          .collection('programs')
          .add({
        'name': name.trim(),
        'description': desc.trim(),
        'date': date,
        'time': time,
        'location': loc.trim(),
        'posterLink': _convertGoogleDriveLink(poster.trim()),
        'hasPrizePool': hasPrize,
        'prizeAmount': prize,
        'visibility': vis,
        'college': coll,
        'category': cat,
        'eventMode': mode,
        'status': 'pending',
        'clubId': clubId,
        'clubName': clubName,
        'coordinatorId': user?.uid,
        'coordinatorName': nameStr,
        'coordinatorEmail': user?.email,
        'requiresVolunteers': requiresVolunteers,
        'volunteerCount': volunteerCount.isNotEmpty
            ? int.tryParse(volunteerCount) ?? 0
            : null,
        'volunteerRole': volunteerRole.isNotEmpty
            ? volunteerRole.trim()
            : null,
        'totalSeats': int.tryParse(totalSeats.trim()) ?? 0,
        'filledSeats': 0,
        'isTeamEvent': isTeamEvent,
        'teamSize': isTeamEvent ? int.tryParse(teamSize.trim()) ?? 0 : null,
        'registrationDeadlineDate': deadlineDate,
        'registrationDeadlineTime': deadlineTime,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isPaid': false,
        'entryFee': 0.0,
      });

      if (mounted) Navigator.pop(ctx);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Program proposed successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _convertGoogleDriveLink(String link) {
    if (link.isEmpty) return '';

    if (link.contains('.jpg') ||
        link.contains('.jpeg') ||
        link.contains('.png') ||
        link.contains('.gif') ||
        link.contains('.webp')) {
      return link;
    }

    if (link.contains('drive.google.com/uc?export=view')) {
      return link;
    }

    final regex = RegExp(r'(?:drive\.google\.com/file/d/|id=)([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(link);

    if (match != null) {
      final fileId = match.group(1);
      return 'https://drive.google.com/uc?export=view&id=$fileId';
    }

    return link;
  }


  void _showNotifications() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text("Notifications", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('clubs')
                .doc(clubId)
                .collection('notifications')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return Center(child: Text("No notifications", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)));
              final docs = snapshot.data!.docs;
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => Divider(color: isDark ? Colors.white12 : Colors.grey[300]),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(
                      data['title'] ?? 'Notification',
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                    ),
                    subtitle: Text(data['message'] ?? '', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, size: 20, color: isDark ? Colors.white54 : Colors.grey),
                      onPressed: () => docs[index].reference.delete(),
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
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _requestStatusChange(String pId, String s) async {
    debugPrint("Requesting status change for $pId to $s");
    try {
      if (['ongoing', 'completed', 'cancelled'].contains(s)) {
        debugPrint("Updating project status locally...");
        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId!)
            .collection('programs')
            .doc(pId)
            .update({
          'status': s,
          'updatedAt': FieldValue.serverTimestamp(),
          'requestedStatus': FieldValue.delete(),
        });

        debugPrint("Updating project status globally in 'events'...");
        final eventQuery = await FirebaseFirestore.instance
            .collection('events')
            .where('programId', isEqualTo: pId)
            .get();

        for (var doc in eventQuery.docs) {
          await doc.reference.update({
            'status': s,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        debugPrint("Status update successful.");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Event marked as $s')));
      } else {
        debugPrint("Requesting approval for status: $s");
        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId!)
            .collection('programs')
            .doc(pId)
            .update({
          'status': 'pending',
          'requestedStatus': s,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status change to $s requested.')),
        );
      }
    } catch (e) {
      debugPrint("Status change error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
    }
  }

  void _confirmDelete(BuildContext context, String pId) async {
    final progRegs = await FirebaseFirestore.instance
        .collection('registrations')
        .where('eventId', isEqualTo: pId)
        .limit(1)
        .get();

    final globalEventQuery = await FirebaseFirestore.instance
        .collection('events')
        .where('programId', isEqualTo: pId)
        .limit(1)
        .get();

    bool hasGlobalRegs = false;
    if (globalEventQuery.docs.isNotEmpty) {
      final eventId = globalEventQuery.docs.first.id;
      final eventRegs = await FirebaseFirestore.instance
          .collection('registrations')
          .where('eventId', isEqualTo: eventId)
          .limit(1)
          .get();
      hasGlobalRegs = eventRegs.docs.isNotEmpty;
    }

    if (!mounted) return;

    if (progRegs.docs.isNotEmpty || hasGlobalRegs) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Delete Program'),
          content: const Text(
            'This program has registered participants and cannot be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Program?'),
        content: const Text(
          'This action cannot be undone and will remove the event from the student dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId!)
                    .collection('programs')
                    .doc(pId)
                    .delete();

                final globalEvents = await FirebaseFirestore.instance
                    .collection('events')
                    .where('programId', isEqualTo: pId)
                    .get();

                for (var doc in globalEvents.docs) {
                  await doc.reference.delete();
                }

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Program and Event deleted successfully'),
                    ),
                  );
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditProgramDialog(
      BuildContext context,
      String pId,
      Map<String, dynamic> data,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: data['name']);
    final descriptionController = TextEditingController(text: data['description']);
    final dateController = TextEditingController(text: data['date']);
    final locationController = TextEditingController(text: data['location']);
    final timeController = TextEditingController(text: data['time']);
    final posterLinkController = TextEditingController(text: data['posterLink'] ?? '');
    final prizeAmountController = TextEditingController(text: data['prizeAmount'] ?? '');
    String visibility = data['visibility'] ?? 'college';
    bool hasPrizePool = data['hasPrizePool'] ?? false;
    String? category = data['category'];
    String? eventMode = data['eventMode'];
    bool requiresVolunteers = data['requiresVolunteers'] ?? false;
    final volunteerCountController = TextEditingController(text: (data['volunteerCount'] ?? '').toString());
    final volunteerRoleController = TextEditingController(text: data['volunteerRole'] ?? '');
    bool isTeamEvent = data['isTeamEvent'] ?? false;
    final teamSizeController = TextEditingController(text: (data['teamSize'] ?? '').toString());
    final deadlineDateController = TextEditingController(text: data['registrationDeadlineDate'] ?? '');
    final deadlineTimeController = TextEditingController(text: data['registrationDeadlineTime'] ?? '');

    bool isUploadingPoster = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text('Edit Program', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isUploadingPoster ? null : () async {
                          final picker = ImagePicker();
                          final pickedFile = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 50,
                            maxWidth: 800,
                          );
                          if (pickedFile == null) return;

                          setDialogState(() {
                            isUploadingPoster = true;
                          });

                          try {
                            final bytes = await pickedFile.readAsBytes();
                            if (bytes.isNotEmpty) {
                              final base64String = base64Encode(bytes);
                              posterLinkController.text = 'data:image/jpeg;base64,$base64String';
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Poster successfully attached!'), backgroundColor: Colors.green),
                                );
                              }
                            }
                          } catch(e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to read poster: $e'), backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            setDialogState(() {
                              isUploadingPoster = false;
                            });
                          }
                        },
                        icon: isUploadingPoster
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.image),
                        label: Text(
                            isUploadingPoster
                                ? 'Processing...'
                                : (posterLinkController.text.isNotEmpty ? 'Poster Attached ✅ (Tap to change)' : 'Attach Poster Image')
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildProposalField(nameController, 'Program Name *', isDark),
                const SizedBox(height: 12),
                _buildProposalField(descriptionController, 'Description *', isDark, maxLines: 3),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  value: category,
                  hint: Text('Select Category', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                  decoration: InputDecoration(
                    labelText: 'Category *',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    border: const OutlineInputBorder(),
                  ),
                  items: ['Technical', 'Cultural', 'Sports', 'Academic', 'Social', 'Other']
                      .map((label) => DropdownMenuItem(value: label, child: Text(label, style: TextStyle(color: isDark ? Colors.white : Colors.black))))
                      .toList(),
                  onChanged: (value) => setDialogState(() => category = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  value: eventMode,
                  hint: Text('Select Event Mode', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                  decoration: InputDecoration(
                    labelText: 'Event Mode *',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    border: const OutlineInputBorder(),
                  ),
                  items: ['Online', 'Offline']
                      .map((label) => DropdownMenuItem(value: label, child: Text(label, style: TextStyle(color: isDark ? Colors.white : Colors.black))))
                      .toList(),
                  onChanged: (value) => setDialogState(() => eventMode = value),
                ),
                const SizedBox(height: 12),
                _buildProposalField(dateController, 'Date (YYYY-MM-DD) *', isDark, readOnly: true, onTap: () async {
                    final now = DateTime.now();
                    final firstDate = DateUtils.dateOnly(now);
                    DateTime initialDate = firstDate;
                    if (dateController.text.isNotEmpty) {
                      try {
                        final parsed = DateFormat('yyyy-MM-dd').parse(dateController.text);
                        if (parsed.isAfter(firstDate)) initialDate = parsed;
                      } catch (_) {}
                    }
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: firstDate,
                      lastDate: DateTime(2100),
                    );
                    if (pickedDate != null) {
                      setDialogState(() {
                        dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                        // If new event date is before current deadline, clear deadline
                        if (deadlineDateController.text.isNotEmpty) {
                          try {
                            final deadline = DateFormat('yyyy-MM-dd').parse(deadlineDateController.text);
                            if (deadline.isAfter(pickedDate)) {
                              deadlineDateController.clear();
                            }
                          } catch (_) {}
                        }
                      });
                    }
                }),
                const SizedBox(height: 12),
                _buildProposalField(timeController, 'Time (HH:MM) *', isDark, readOnly: true, onTap: () async {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (pickedTime != null)
                      timeController.text = '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                }),
                const SizedBox(height: 12),
                _buildProposalField(locationController, 'Venue *', isDark),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: hasPrizePool,
                  title: Text('Prize Pool Available', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                  subtitle: Text('Does this program have prize rewards?', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setDialogState(() {
                      hasPrizePool = value ?? false;
                      if (!hasPrizePool) prizeAmountController.clear();
                    });
                  },
                ),
                if (hasPrizePool) ...[
                  const SizedBox(height: 12),
                  _buildProposalField(prizeAmountController, 'Prize Amount', isDark, prefixText: '₹ ', keyboardType: TextInputType.number),
                ],
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: requiresVolunteers,
                  title: Text('Require Volunteers', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => requiresVolunteers = v ?? false),
                ),
                if (requiresVolunteers) ...[
                  const SizedBox(height: 8),
                  _buildProposalField(volunteerCountController, 'Number of Volunteers', isDark, keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  _buildProposalField(volunteerRoleController, 'Volunteer Role / Instructions', isDark, maxLines: 2),
                ],
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: isTeamEvent,
                  title: Text('Team Event', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                  subtitle: Text('Students must register as a team', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => isTeamEvent = v ?? false),
                ),
                if (isTeamEvent) ...[
                  const SizedBox(height: 8),
                  _buildProposalField(teamSizeController, 'Team Size', isDark, keyboardType: TextInputType.number),
                ],
                const SizedBox(height: 16),
                const Divider(),
                Text('Registration Deadline', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 12),
                _buildProposalField(deadlineDateController, 'Deadline Date (YYYY-MM-DD) *', isDark, readOnly: true, onTap: () async {
                    final now = DateTime.now();
                    final firstDate = DateUtils.dateOnly(now);
                    DateTime initialDate = firstDate;
                    if (deadlineDateController.text.isNotEmpty) {
                      try {
                        final parsed = DateFormat('yyyy-MM-dd').parse(deadlineDateController.text);
                        if (parsed.isAfter(firstDate)) initialDate = parsed;
                      } catch (_) {}
                    }
                    DateTime lastDate = DateTime(2100);
                    if (dateController.text.isNotEmpty) {
                      try {
                        lastDate = DateFormat('yyyy-MM-dd').parse(dateController.text);
                      } catch (_) {}
                    }
                    
                    final d = await showDatePicker(
                      context: context, 
                      initialDate: initialDate.isAfter(lastDate) ? lastDate : initialDate, 
                      firstDate: firstDate, 
                      lastDate: lastDate
                    );
                    if (d != null) deadlineDateController.text = DateFormat('yyyy-MM-dd').format(d);
                }),
                const SizedBox(height: 12),
                _buildProposalField(deadlineTimeController, 'Deadline Time (HH:MM) *', isDark, readOnly: true, onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (t != null) deadlineTimeController.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                }),
                const SizedBox(height: 16),

                const Divider(),
                const SizedBox(height: 8),
                Text('Event Visibility', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 12),
                Column(
                  children: [
                    RadioListTile<String>(
                      value: 'college',
                      groupValue: visibility,
                      onChanged: (value) => setDialogState(() => visibility = value!),
                      title: Text('College Only', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                      subtitle: Text('Only students from this college can participate', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      value: 'public',
                      groupValue: visibility,
                      onChanged: (value) => setDialogState(() => visibility = value!),
                      title: Text('Public', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                      subtitle: Text('Students from other colleges can also participate', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.3))),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final validationError = _validateProgramForm(
                  nameController.text,
                  descriptionController.text,
                  dateController.text,
                  timeController.text,
                  locationController.text,
                  category,
                  eventMode,
                  posterLinkController.text,
                );

                if (validationError != null) {
                  setDialogState(() => errorMessage = validationError);
                  return;
                }
                setDialogState(() => errorMessage = null);

                _updateProgram(
                  ctx,
                  pId,
                  nameController.text,
                  descriptionController.text,
                  dateController.text,
                  timeController.text,
                  locationController.text,
                  _convertGoogleDriveLink(posterLinkController.text),
                  visibility,
                  hasPrizePool,
                  prizeAmountController.text,
                  category!,
                  eventMode!,
                  requiresVolunteers,
                  volunteerCountController.text,
                  volunteerRoleController.text,
                  isTeamEvent,
                  teamSizeController.text,
                  deadlineTimeController.text,
                );
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateProgramForm(
      String name,
      String desc,
      String date,
      String time,
      String loc,
      String? category,
      String? mode,
      String poster,
      ) {
    if (name.trim().isEmpty) return 'Program name cannot be empty';
    if (desc.trim().isEmpty) return 'Description cannot be empty';
    if (poster.trim().isEmpty) return 'Please attach an event poster image';
    if (date.trim().isEmpty) return 'Date cannot be empty';
    if (time.trim().isEmpty) return 'Time cannot be empty';
    if (loc.trim().isEmpty) return 'Venue cannot be empty';
    if (category == null) return 'Please select a category';
    if (mode == null) return 'Please select an event mode';
    try {
      DateFormat('yyyy-MM-dd').parseStrict(date);
    } catch (e) {
      return 'Invalid date format. Use YYYY-MM-DD';
    }
    return null;
  }

  Future<void> _updateProgram(
      BuildContext context,
      String programId,
      String name,
      String description,
      String date,
      String time,
      String location,
      String posterLink,
      String visibility,
      bool hasPrizePool,
      String prizeAmount,
      String category,
      String eventMode,
      bool requiresVolunteers,
      String volunteerCount,
      String volunteerRole,
      bool isTeamEvent,
      String teamSize,
      String deadlineTime,
      ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (isTeamEvent && (int.tryParse(teamSize.trim()) ?? 0) < 2) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Team size must be at least 2 for team events.'),
          ),
        );
        return;
      }
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId!)
          .collection('programs')
          .doc(programId)
          .update({
        'name': name.trim(),
        'description': description.trim(),
        'date': date,
        'time': time,
        'location': location.trim(),
        'posterLink': posterLink.isNotEmpty ? posterLink.trim() : null,
        'visibility': visibility,
        'hasPrizePool': hasPrizePool,
        'prizeAmount': hasPrizePool && prizeAmount.isNotEmpty
            ? prizeAmount.trim()
            : null,
        'category': category,
        'eventMode': eventMode,
        'requiresVolunteers': requiresVolunteers,
        'volunteerCount': volunteerCount.isNotEmpty
            ? int.tryParse(volunteerCount) ?? 0
            : null,
        'volunteerRole': volunteerRole.isNotEmpty
            ? volunteerRole.trim()
            : null,
        'isTeamEvent': isTeamEvent,
        'teamSize': isTeamEvent ? int.tryParse(teamSize.trim()) ?? 0 : null,
        'registrationDeadlineTime': deadlineTime,
        'status': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final eventQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('programId', isEqualTo: programId)
          .limit(1)
          .get();
      if (eventQuery.docs.isNotEmpty) {
        await eventQuery.docs.first.reference.update({
          'title': name.trim(),
          'status': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Program updated and sent for re-approval!'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _toggleTheme() async {
    themeNotifier.value = themeNotifier.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    (await SharedPreferences.getInstance()).setBool(
      'isDarkMode',
      themeNotifier.value == ThemeMode.dark,
    );
  }

  Future<void> _showEditDescriptionDialog(String current) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: current);
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text("Edit Club Description", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
            hintText: "Describe your club activities...",
            hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (clubId != null && controller.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId!)
                    .update({'description': controller.text.trim()});
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showExitDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text("Exit Dashboard?", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Text("Do you want to exit the application?", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Exit"),
          ),
        ],
      ),
    );
  }
}

class ProgramCard extends StatelessWidget {
  final String programId;
  final String clubId;
  final Map<String, dynamic> programData;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(String) onStatusChange;

  const ProgramCard({
    required this.programId,
    required this.clubId,
    required this.programData,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = (programData['status'] ?? 'pending').toString().toLowerCase();
    final bool isCompleted = status == 'completed';
    final bool isApproved = status == 'approved' || status == 'ongoing' || status == 'completed';

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = isDark ? const Color(0xFF00E676) : Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'ongoing':
        statusColor = const Color(0xFFFF9100);
        statusIcon = Icons.sensors_rounded;
        break;
      case 'completed':
        statusColor = isDark ? const Color(0xFF00B0FF) : Colors.blue;
        statusIcon = Icons.verified_rounded;
        break;
      case 'rejected':
        statusColor = const Color(0xFFFF5252);
        statusIcon = Icons.error_outline_rounded;
        break;
      default:
        statusColor = isDark ? Colors.white38 : Colors.grey;
        statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.white.withOpacity(0.35),
                width: 1.5,
              ),
            ),
              child: InkWell(
                onTap: () => _showProgramDetails(context),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: Status Indicator
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: statusColor.withOpacity(0.1), blurRadius: 10),
                                ],
                              ),
                              child: Icon(statusIcon, size: 24, color: statusColor),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        // Vertical Divider
                        Container(
                          width: 1,
                          height: 60,
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                        ),
                        const SizedBox(width: 16),
                        // Center: Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                programData['name'] ?? 'Untitled Event',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: -0.5,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        programData['category']?.toString().toUpperCase() ?? 'GENERAL',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.blueAccent,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.calendar_today_rounded, size: 10, color: isDark ? Colors.white38 : Colors.black38),
                                  const SizedBox(width: 4),
                                  Text(
                                    programData['date'] ?? 'TBD',
                                    style: TextStyle(
                                      color: isDark ? Colors.white38 : Colors.black38,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.location_on_rounded, size: 10, color: isDark ? Colors.white38 : Colors.black38),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      programData['location'] ?? 'TBD',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark ? Colors.white38 : Colors.black38,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Right: Actions
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (status == 'pending' || status == 'rejected')
                              _buildCardAction(
                                icon: Icons.edit_note_rounded,
                                color: Colors.blueAccent,
                                onTap: onEdit,
                              ),
                            const SizedBox(height: 8),
                            _buildCardAction(
                              icon: Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                              onTap: onDelete,
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isApproved && !isCompleted) ...[
                      const SizedBox(height: 16),
                      Divider(color: (isDark ? Colors.white : Colors.black).withOpacity(0.06), height: 1),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _statusActionButton(
                              context,
                              label: "START",
                              icon: Icons.play_arrow_rounded,
                              active: status == 'approved',
                              onTap: () => onStatusChange('ongoing'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statusActionButton(
                              context,
                              label: "FINISH",
                              icon: Icons.stop_rounded,
                              active: status == 'ongoing',
                              onTap: () => onStatusChange('completed'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (isCompleted) ...[
                      const SizedBox(height: 16),
                      Divider(color: (isDark ? Colors.white : Colors.black).withOpacity(0.06), height: 1),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EventRegistrationsListScreen(
                                    eventId: programId,
                                    eventName: programData['name'] ?? 'Event',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.workspace_premium_rounded, size: 22),
                            label: const Text("WINNERS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.withOpacity(0.15),
                              foregroundColor: Colors.orange,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Colors.orange, width: 2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardAction({required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _statusActionButton(
      BuildContext context, {
        required String label,
        required IconData icon,
        required bool active,
        required VoidCallback onTap,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = label == "START" ? Colors.greenAccent : Colors.blueAccent;
    final primaryColor = active
      ? accentColor
      : (isDark ? Colors.white10 : Colors.grey[200]!);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: active ? [
          BoxShadow(
            color: accentColor.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: active ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: active ? primaryColor.withOpacity(0.12) : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active ? primaryColor.withOpacity(0.4) : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active ? primaryColor : (isDark ? Colors.white24 : Colors.black26),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: active ? primaryColor : (isDark ? Colors.white24 : Colors.black26),
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

  void _showProgramDetails(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Colors.blueAccent;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Material(
                color: isDark ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.9),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                programData['name'] ?? 'Event Details',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  letterSpacing: -1,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded),
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (programData['posterLink'] != null && programData['posterLink'].toString().isNotEmpty) ...[
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: (programData['posterLink'].toString().startsWith('data:image'))
                                ? Image.memory(
                                    base64Decode(programData['posterLink'].toString().split(',').last),
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    programData['posterLink'],
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 200,
                                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200],
                                      child: const Icon(Icons.image_not_supported_rounded, size: 50, color: Colors.grey),
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        Text(
                          "ABOUT THE EVENT",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          programData['description'] ?? 'No description available',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Divider(color: isDark ? Colors.white12 : Colors.black12),
                        const SizedBox(height: 20),
                        _buildDetailGrid(ctx, isDark),
                        const SizedBox(height: 24),
                        if (programData['hasPrizePool'] == true) ...[
                          _buildPremiumMetaSection(isDark),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 0,
                            ),
                            child: const Text("CLOSE DETAILS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: anim1.drive(CurveTween(curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
    );
  }

  Widget _buildDetailGrid(BuildContext context, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildDetailRow(Icons.calendar_today_rounded, "Date", programData['date'] ?? 'TBD', isDark)),
            Expanded(child: _buildDetailRow(Icons.access_time_rounded, "Time", programData['time'] ?? 'TBD', isDark)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildDetailRow(Icons.location_on_rounded, "Venue", programData['location'] ?? 'TBD', isDark)),
            Expanded(child: _buildDetailRow(Icons.category_rounded, "Category", programData['category'] ?? 'General', isDark)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildDetailRow(Icons.groups_rounded, "Total Seats", (programData['totalSeats'] ?? 'Unlimited').toString(), isDark)),
            Expanded(child: _buildDetailRow(Icons.visibility_rounded, "Visibility", programData['visibility']?.toString().toUpperCase() ?? 'COLLEGE', isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildPremiumMetaSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.blue.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          if (programData['hasPrizePool'] == true) ...[
            _buildDetailRow(Icons.emoji_events_rounded, "Prize Pool", "₹${programData['prizeAmount'] ?? 'TBD'}", isDark, isHighlight: true),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark, {bool isHighlight = false}) {
    final color = isHighlight ? Colors.blueAccent : (isDark ? Colors.white70 : Colors.black87);

    return Row(
      children: [
        Icon(icon, size: 16, color: isHighlight ? color : (isDark ? Colors.white38 : Colors.grey)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
