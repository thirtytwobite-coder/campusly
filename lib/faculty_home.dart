import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:flutter/rendering.dart';

import 'main.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'program_approval_screen.dart';
import 'program_status_screen.dart';
import 'certificate_approval_screen.dart';
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
  bool _isLoadingInfo = true;
  bool _isNavbarVisible = true;

  @override
  void initState() {
    super.initState();
    _fetchFacultyInfo();
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
        appBar: AppBar(
          title: const Text("FACULTY DASHBOARD"),
          backgroundColor: isDark ? Colors.black : Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          actions: [
          ],
        ),
        body: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis != Axis.vertical) return false;
            if (notification.direction == ScrollDirection.reverse) {
              if (_isNavbarVisible) setState(() => _isNavbarVisible = false);
            } else if (notification.direction == ScrollDirection.forward) {
              if (!_isNavbarVisible) setState(() => _isNavbarVisible = true);
            }
            return true;
          },
          child: Stack(
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
  
                        return CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: GlassCard(
                                borderRadius: 15,
                                child: Container(
                                  margin: const EdgeInsets.all(16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: !isDark ? BoxDecoration(
                                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                                    ),
                                  ) : null,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.account_balance,
                                        color: Colors.blueAccent,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          facultyCollege ?? "Institution Unknown",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ).animate().fadeIn().slideY(begin: -0.1),
                            ),
  
                            if (docs.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(child: Text("No Clubs Assigned", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54))),
                              ),
  
                            if (docs.isNotEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    var doc = docs[index];
                                    var data = doc.data() as Map<String, dynamic>;
                                    String clubName = data['clubName'] ?? "My Club";
                                    String clubId = data['clubId'];
  
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: _buildClubOptionsCard(
                                        clubName: clubName,
                                        clubId: clubId,
                                        clubMappingDoc: doc,
                                      ),
                                    );
                                  }, childCount: docs.length),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ],
          ),
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
                  color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.8) : Theme.of(context).cardColor,
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
                      activeColor: Theme.of(context).primaryColor,
                      iconSize: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      duration: const Duration(milliseconds: 400),
                      tabBackgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      color: isDark ? Colors.white60 : Theme.of(context).iconTheme.color?.withOpacity(0.6) ?? Colors.grey,
                      tabs: [
                        GButton(icon: Icons.home, text: 'Home'),
                        GButton(icon: Icons.person, text: 'Profile'),
                      ],
                      selectedIndex: _selectedIndex,
                      onTabChange: (index) {
                        _onItemTapped(index);
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

  Widget _buildClubOptionsCard({
    required String clubName,
    required String clubId,
    required DocumentSnapshot clubMappingDoc,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      borderRadius: 16,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.group_work, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      clubName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.8,
                children: [
                  _buildOptionButton(
                    icon: Icons.bar_chart,
                    label: "Analytics",
                    color: Colors.green,
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
                  _buildOptionButton(
                    icon: Icons.people_outline,
                    label: "Coordinators",
                    color: Colors.blue,
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
                  _buildOptionButton(
                    icon: Icons.check_circle_outline,
                    label: "Approved",
                    color: Colors.green,
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
                  _buildOptionButton(
                    icon: Icons.cancel_outlined,
                    label: "Rejected",
                    color: Colors.red,
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
          ),
        ),
      ),
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
        final bool hasPending = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        final int pendingCount = snapshot.data?.docs.length ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: _buildOptionButton(
                icon: Icons.task_alt_outlined,
                label: "Approve Events",
                color: Colors.orange,
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
              ),
            ),
            if (hasPending)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    pendingCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ).animate(onPlay: (controller) => controller.repeat()).shake(
                  hz: 2,
                  offset: const Offset(1, 1),
                ),
              ),
          ],
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
        final bool hasPending = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        final int pendingCount = snapshot.data?.docs.length ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: _buildOptionButton(
                icon: Icons.verified_user_outlined,
                label: "Verify Certs",
                color: Colors.indigo,
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
              ),
            ),
            if (hasPending)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Text(
                    pendingCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ).animate(onPlay: (c) => c.repeat()).shake(hz: 2),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
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
      appBar: AppBar(title: Text('Manage "$clubName"')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Club Coordinators',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton(
                  onPressed: _showAddCoordinatorDialog,
                  icon: const Icon(Icons.person_add, color: Colors.blue),
                  tooltip: 'Add Coordinator',
                ),
              ],
            ),
            const Divider(),
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
                if (coordinators.isEmpty)
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('No coordinators assigned.')),
                  );
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: coordinators.length,
                  itemBuilder: (context, index) {
                    final coordinator = coordinators[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(coordinator['studentName'] ?? 'Unnamed'),
                        subtitle: Text(
                          coordinator['studentEmail'] ?? 'No email',
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () => _removeCoordinator(coordinator),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
