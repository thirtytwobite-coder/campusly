import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:college_event_manager/scooped_navbar.dart';
import 'package:flutter/rendering.dart';

import 'main.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'program_approval_screen.dart';
import 'program_status_screen.dart';
import 'certificate_approval_screen.dart';
import 'change_password.dart';
import 'analytics_screen.dart';
import 'vibrant_background.dart';

class FacultyHomeScreen extends StatefulWidget {
  const FacultyHomeScreen({super.key});

  @override
  State<FacultyHomeScreen> createState() => _FacultyHomeScreenState();
}

class _FacultyHomeScreenState extends State<FacultyHomeScreen> {
  int _selectedIndex = 0;
  String? facultyCollege;
  String? facultyName;
  bool _isLoadingInfo = true;
  String? _selectedClubId;

  @override
  void initState() {
    super.initState();
    _loadStoredName();
    _fetchFacultyInfo();
  }

  Future<void> _loadStoredName() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        facultyName = prefs.getString('name');
        facultyCollege = prefs.getString('college');
      });
    }
  }

  Future<void> _fetchFacultyInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('faculty')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            facultyCollege = doc.data()?['college'];
            facultyName = doc.data()?['name'];
          });
        }
      } catch (e) {
        debugPrint("Error fetching faculty info: $e");
      }
    }
    if (mounted) setState(() => _isLoadingInfo = false);
  }

  Future<bool> _onWillPop() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit'),
          content: const Text('Are you sure you want to Exit?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldLogout ?? false) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const UnifiedLoginScreen()),
          (route) => false,
        );
      }
      return false;
    }
    return false;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            facultyName?.toUpperCase() ?? "FACULTY HUB",
            style: TextStyle(
              fontWeight: FontWeight.w900, 
              letterSpacing: 2.0,
              fontSize: 20,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          centerTitle: false,
          backgroundColor: Colors.transparent,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                color: (isDark ? Colors.black : Colors.white).withOpacity(isDark ? 0.4 : 0.6),
              ),
            ),
          ),
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: isDark ? Colors.white : Colors.black,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => _onWillPop(),
            ),
          ],
        ),
        body: Stack(
          children: [
            const VibrantBackground(),
            _isLoadingInfo
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('club_mappings')
                          .where('facultyEmail', isEqualTo: user?.email)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data?.docs ?? [];

                        if (docs.isEmpty) {
                          return CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              const SliverToBoxAdapter(child: SizedBox(height: 100)),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      Text(
                                        "Welcome Back,",
                                        style: TextStyle(
                                          color: isDark ? Colors.white38 : Colors.black38,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
                                        ),
                                      ).animate().fadeIn(duration: 600.ms, delay: 100.ms),
                                      Text(
                                        (facultyName ?? "Faculty Member").toLowerCase(),
                                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -1.0,
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontSize: 32,
                                        ),
                                      ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                                    ],
                                  ),
                                ),
                              ),
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.layers_clear_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
                                      const SizedBox(height: 16),
                                      Text(
                                        "No Clubs Assigned",
                                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 18, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        // Ensure _selectedClubId is valid
                        bool isValidSelection = docs.any((d) => (d.data() as Map<String, dynamic>)['clubId'] == _selectedClubId);
                        if (!isValidSelection && docs.isNotEmpty) {
                          // Post-frame callback to avoid setting state during build, but we can just use a local var
                          // Actually, we can just let it be invalid for a moment, and fall back to the first doc below.
                        }
                        
                        final selectedDoc = isValidSelection 
                            ? docs.firstWhere((d) => (d.data() as Map<String, dynamic>)['clubId'] == _selectedClubId) 
                            : docs.first;
                            
                        final selectedData = selectedDoc.data() as Map<String, dynamic>;
                        final clubName = selectedData['clubName'] ?? "My Club";
                        final clubId = selectedData['clubId'];
                        
                        // Default to the first club if unset
                        if (_selectedClubId == null && docs.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _selectedClubId = clubId);
                          });
                        }

                        return CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            const SliverToBoxAdapter(child: SizedBox(height: 100)),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Text(
                                      "Welcome Back,",
                                      style: TextStyle(
                                        color: isDark ? Colors.white38 : Colors.black38,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ).animate().fadeIn(duration: 600.ms, delay: 100.ms),
                                    Text(
                                      (facultyName ?? "Faculty Member").toLowerCase(),
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1.0,
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontSize: 32,
                                      ),
                                    ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                                    const SizedBox(height: 32),
                                    
                                    // Club Selector
                                    if (docs.length > 1) ...[
                                      Text(
                                        "Select Club",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white54 : Colors.black54,
                                          letterSpacing: 1.0,
                                        ),
                                      ).animate().fadeIn(),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 48,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          physics: const BouncingScrollPhysics(),
                                          itemCount: docs.length,
                                          itemBuilder: (context, index) {
                                            final docData = docs[index].data() as Map<String, dynamic>;
                                            final id = docData['clubId'];
                                            final name = (docData['clubName'] ?? "Club").toString().toUpperCase();
                                            final isSelected = id == (isValidSelection ? _selectedClubId : clubId);

                                            return Padding(
                                              padding: const EdgeInsets.only(right: 12),
                                              child: ChoiceChip(
                                                label: Text(name),
                                                selected: isSelected,
                                                onSelected: (val) {
                                                  if (val && mounted) {
                                                    setState(() => _selectedClubId = id);
                                                  }
                                                },
                                                selectedColor: Theme.of(context).colorScheme.primary,
                                                labelStyle: TextStyle(
                                                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                                  fontSize: 12,
                                                  letterSpacing: 1.0,
                                                ),
                                                backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                                side: BorderSide(color: isSelected ? Colors.transparent : (isDark ? Colors.white12 : Colors.black12)),
                                              ),
                                            );
                                          },
                                        ),
                                      ).animate().fadeIn().slideX(begin: 0.1),
                                      const SizedBox(height: 24),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              sliver: SliverToBoxAdapter(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: Container(
                                    key: ValueKey(clubId),
                                    child: _buildClubOptionsCard(
                                      clubName: clubName,
                                      clubId: clubId,
                                      clubMappingDoc: selectedDoc,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 120)),
                          ],
                        );
                      },
                    ),
          ],
        ),
        bottomNavigationBar: ScoopedNavigationBar(
          currentIndex: _selectedIndex > 1 ? 0 : _selectedIndex,
          onTap: _onItemTapped,
          activeColor: Theme.of(context).primaryColor,
          items: const [
            ScoopedNavItem(icon: Icons.home_rounded, label: 'Home'),
            ScoopedNavItem(icon: Icons.person_rounded, label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildClubOptionsCard({
    required String clubName,
    required String clubId,
    required DocumentSnapshot clubMappingDoc,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                clubName.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.0,
          children: [
            _buildPremiumCard(
              title: "Analytics",
              subtitle: "Usage Trends",
              icon: Icons.analytics_rounded,
              colors: const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnalyticsScreen(
                      clubId: clubId,
                      clubName: clubName,
                      isFaculty: true,
                    ),
                  ),
                );
              },
            ),
            _buildPremiumCard(
              title: "Coordinators",
              subtitle: "Manage Staff",
              icon: Icons.manage_accounts_rounded,
              colors: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClubManagementScreen(
                      clubMappingDoc: clubMappingDoc,
                    ),
                  ),
                );
              },
            ),
            _buildApproveButton(clubId, clubName),
            _buildVerifyCertsButton(clubId, clubName),
            _buildPremiumCard(
              title: "Approved",
              subtitle: "Completed Events",
              icon: Icons.check_circle_rounded,
              colors: const [Color(0xFF10B981), Color(0xFF059669)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProgramStatusScreen(
                      clubId: clubId,
                      clubName: clubName,
                      status: 'approved',
                    ),
                  ),
                );
              },
            ),
            _buildPremiumCard(
              title: "Rejected",
              subtitle: "Declined Events",
              icon: Icons.cancel_rounded,
              colors: const [Color(0xFFF43F5E), Color(0xFFE11D48)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProgramStatusScreen(
                      clubId: clubId,
                      clubName: clubName,
                      status: 'rejected',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPremiumCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
    int index = 0,
    int badgeCount = 0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GlassCard(
          borderRadius: 32,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(32),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors[0].withOpacity(0.15), colors[1].withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colors[0].withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.black54,
                          letterSpacing: 0.1,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(delay: (100 * index).ms).slideY(begin: 0.1, duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
        if (badgeCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                badgeCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ).animate(onPlay: (c) => c.repeat()).shake(hz: 3, offset: const Offset(2, 2)),
          ),
      ],
    );
  }

  Widget _buildApproveButton(String clubId, String clubName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('programs')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        final int pendingCount = snapshot.data?.docs.length ?? 0;

        return _buildPremiumCard(
          title: "Approvals",
          subtitle: "Events Queue",
          icon: Icons.approval_rounded,
          colors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
          badgeCount: pendingCount,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProgramApprovalScreen(
                  clubId: clubId,
                  clubName: clubName,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVerifyCertsButton(String clubId, String clubName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('certificate_approvals')
          .where('clubId', isEqualTo: clubId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        final int pendingCount = snapshot.data?.docs.length ?? 0;

        return _buildPremiumCard(
          title: "Certificates",
          subtitle: "Verification",
          icon: Icons.verified_rounded,
          colors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
          badgeCount: pendingCount,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CertificateApprovalScreen(
                  clubId: clubId,
                  clubName: clubName,
                ),
              ),
            );
          },
        );
      },
    );
  }

}

class ClubManagementScreen extends StatefulWidget {
  final DocumentSnapshot clubMappingDoc;
  const ClubManagementScreen({super.key, required this.clubMappingDoc});
  @override
  State<ClubManagementScreen> createState() => _ClubManagementScreenState();
}

class _ClubManagementScreenState extends State<ClubManagementScreen> {
  Future<void> _showAddCoordinatorDialog() async {
    final collegeName = widget.clubMappingDoc['college'];
    List<DocumentSnapshot> students = [];
    String searchQuery = "";

    final studentSnap = await FirebaseFirestore.instance
        .collection('student')
        .where('role', isEqualTo: 'Student')
        .where('college', isEqualTo: collegeName)
        .get();
    students = studentSnap.docs;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredStudents = students.where((student) {
              final name = (student['name'] as String? ?? '').toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return AlertDialog(
              title: const Text('Assign Club Coordinator'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        onChanged: (value) =>
                            setDialogState(() => searchQuery = value),
                        decoration: const InputDecoration(
                          labelText: 'Search by name',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          return ListTile(
                            title: Text(student['name'] ?? 'Unnamed Student'),
                            onTap: () async {
                              final clubId = widget.clubMappingDoc['clubId'];
                              final studentEmail = student['email'];
                              if (studentEmail != null) {
                                await FirebaseFirestore.instance
                                    .collection('clubs')
                                    .doc(clubId)
                                    .update({
                                      'coordinators': FieldValue.arrayUnion([
                                        {
                                          'studentId': student.id,
                                          'studentName': student['name'],
                                          'studentEmail': studentEmail,
                                        },
                                      ]),
                                      'coordinatorEmails':
                                          FieldValue.arrayUnion([studentEmail]),
                                    });
                              }
                              if (mounted) Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _removeCoordinator(Map<String, dynamic> coordinator) async {
    final clubId = widget.clubMappingDoc['clubId'];
    final studentEmail = coordinator['studentEmail'];
    final updateData = {
      'coordinators': FieldValue.arrayRemove([coordinator]),
    };
    if (studentEmail != null)
      updateData['coordinatorEmails'] = FieldValue.arrayRemove([studentEmail]);
    await FirebaseFirestore.instance
        .collection('clubs')
        .doc(clubId)
        .update(updateData);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${coordinator['studentName']} removed.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final clubId = widget.clubMappingDoc['clubId'];
    final clubName = widget.clubMappingDoc['clubName'];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Manage "$clubName"', style: const TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white).withOpacity(0.2),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const VibrantBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 120, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CLUB COORDINATORS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ).animate().fadeIn().slideX(begin: -0.2),
                    IconButton(
                      onPressed: _showAddCoordinatorDialog,
                      icon: const Icon(Icons.person_add_rounded, color: Colors.blueAccent),
                      tooltip: 'Add Coordinator',
                    ).animate().fadeIn().scale(),
                  ],
                ),
                const SizedBox(height: 16),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(clubId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final clubData = snapshot.data!.data() as Map<String, dynamic>?;
                    final coordinators =
                        (clubData?['coordinators'] as List<dynamic>?)
                            ?.map((e) => e as Map<String, dynamic>)
                            .toList() ??
                        [];
                    
                    if (coordinators.isEmpty) {
                      return GlassCard(
                        borderRadius: 24,
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.people_outline_rounded, size: 48, color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12),
                                const SizedBox(height: 16),
                                Text(
                                  'No coordinators assigned.',
                                  style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn();
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: coordinators.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final coordinator = coordinators[index];
                        return GlassCard(
                          borderRadius: 20,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              child: Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.primary),
                            ),
                            title: Text(
                              coordinator['studentName'] ?? 'Unnamed',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              coordinator['studentEmail'] ?? 'No email',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent),
                              onPressed: () => _removeCoordinator(coordinator),
                            ),
                          ),
                        ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
