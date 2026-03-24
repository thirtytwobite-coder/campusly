import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:college_event_manager/scooped_navbar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Ensure these imports match your actual file names
import 'analytics_dashboard_screen.dart';
import 'change_password.dart';
import 'login_screen.dart';
import 'main.dart';
import 'profile_screen.dart';
import 'student_directory_screen.dart';
import 'vibrant_background.dart';

class MainFacultyDashboard extends StatefulWidget {
  final String collegeName;
  const MainFacultyDashboard({super.key, required this.collegeName});

  @override
  State<MainFacultyDashboard> createState() => _MainFacultyDashboardState();
}

class _MainFacultyDashboardState extends State<MainFacultyDashboard> {
  // --- Navigation Logic ---
  int _selectedIndex = 0;
  String? facultyName;

  @override
  void initState() {
    super.initState();
    _loadStoredName();
    _fetchFacultyName();
  }

  Future<void> _loadStoredName() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        facultyName = prefs.getString('name');
      });
    }
  }

  Future<void> _fetchFacultyName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('faculty').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() => facultyName = doc.data()?['name']);
      }
    }
  }

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const UnifiedLoginScreen()),
      );
    }
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

  // --- MAPPING LOGIC: Assigning Faculty to Global/Local Clubs ---

  void _openMappingDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => Scaffold(
          appBar: AppBar(
            title: const Text('Club-Faculty Mapping'),
          ),
          body: Stack(
            children: [
              const VibrantBackground(),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final clubCollege = data['college'];
                    return clubCollege == null ||
                        clubCollege == '' ||
                        clubCollege == widget.collegeName;
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(
                        child: Text("No clubs available for mapping."));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final clubData = docs[index].data() as Map<String, dynamic>;
                      final clubId = docs[index].id;
                      final bool isGlobal =
                          clubData['college'] == null || clubData['college'] == '';

                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('club_mappings')
                            .doc("${widget.collegeName}_$clubId")
                            .snapshots(),
                        builder: (context, mapSnap) {
                          String assigned = "Not Assigned";
                          Color statusColor = Theme.of(context).colorScheme.error;
                          bool hasMapping = false;

                          if (mapSnap.hasData && mapSnap.data!.exists) {
                            final mappingData = mapSnap.data!.data() as Map<String, dynamic>;
                            assigned = mappingData['facultyName'] ??
                                mappingData['facultyEmail'] ??
                                "Not Assigned";
                            statusColor = Colors.green;
                            hasMapping = true;
                          }

                          return GlassCard(
                            borderRadius: 16,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: isGlobal
                                    ? Theme.of(context).colorScheme.secondary.withOpacity(0.1)
                                    : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                child: Icon(isGlobal ? Icons.public_outlined : Icons.school_outlined,
                                    color: isGlobal
                                        ? Theme.of(context).colorScheme.secondary
                                        : Theme.of(context).colorScheme.primary),
                              ),
                              title: Text(clubData['clubName']?.toUpperCase() ?? 'CLUB',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text("Faculty: $assigned",
                                    style: TextStyle(color: statusColor, fontSize: 13)),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasMapping)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      tooltip: 'Remove Mapping',
                                      onPressed: () => _confirmDeleteMapping(clubId, clubData['clubName']),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.rule_folder_outlined),
                                    tooltip: 'Assign Faculty',
                                    onPressed: () => _assignFacultyToClub(clubId, clubData['clubName']),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ).animate().fadeIn(duration: 500.ms).slideX();
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMapping(String clubId, String clubName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Mapping?'),
        content: Text('Are you sure you want to remove the faculty assigned to $clubName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('club_mappings')
          .doc("${widget.collegeName}_$clubId")
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mapping removed for $clubName')),
        );
      }
    }
  }

  Future<void> _assignFacultyToClub(String clubId, String clubName) async {
    String? selectedEmail;
    String? selectedName;

    final facultySnap = await FirebaseFirestore.instance
        .collection('faculty')
        .where('college', isEqualTo: widget.collegeName)
        .get(const GetOptions(source: Source.server));

    if (facultySnap.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("No faculty registered in your college.")));
      }
      return;
    }

    await showDialog(
      context: context,
      builder: (c) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text("Map Faculty to $clubName", style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Select a registered faculty member to manage this club's activities.",
                style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Select Faculty Member",
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.person_search_rounded),
                ),
                dropdownColor: Theme.of(context).cardColor,
                items: facultySnap.docs
                    .map((d) => DropdownMenuItem(
                          value: d['email'] as String,
                          child: Text(d['name'] ?? d['email']),
                        ))
                    .toList(),
                onChanged: (v) {
                  selectedEmail = v;
                  final selectedDoc = facultySnap.docs.firstWhere(
                    (doc) => doc['email'] == v,
                    orElse: () => throw Exception('Faculty not found'),
                  );
                  selectedName = selectedDoc['name'] as String?;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), 
                child: Text("Cancel", style: TextStyle(color: Theme.of(context).colorScheme.primary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                if (selectedEmail == null || selectedName == null) return;

                await FirebaseFirestore.instance
                    .collection('club_mappings')
                    .doc("${widget.collegeName}_$clubId")
                    .set({
                  'clubId': clubId,
                  'clubName': clubName,
                  'college': widget.collegeName,
                  'facultyEmail': selectedEmail,
                  'facultyName': selectedName,
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

                if (mounted) Navigator.pop(c);
              },
              child: const Text("Save Mapping"),
            )
          ],
        ),
      ),
    );
  }

  // --- Manage Local Clubs Logic ---

  void _openManageClubs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => Scaffold(
          appBar: AppBar(title: const Text('Manage Local Clubs')),
          body: Stack(
            children: [
              const VibrantBackground(),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('clubs')
                    .where('college', isEqualTo: widget.collegeName)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text("No local clubs added yet."));

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final clubId = docs[index].id;
                      return GlassCard(
                        borderRadius: 16,
                        child: ListTile(
                          title: Text(data['clubName']?.toUpperCase() ?? 'CLUB', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text("Local Club"),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteClub(clubId, data['clubName']),
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
      ),
    );
  }

  Future<void> _deleteClub(String clubId, String clubName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Club?'),
        content: Text('This will permanently delete "$clubName" and all its mappings. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. Delete the club document
        await FirebaseFirestore.instance.collection('clubs').doc(clubId).delete();
        // 2. Delete the mapping if it exists
        await FirebaseFirestore.instance.collection('club_mappings').doc("${widget.collegeName}_$clubId").delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Club "$clubName" deleted.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting club: $e')));
        }
      }
    }
  }

  // --- Add Club Logic (Local) ---

  Future<void> _addClubDialog() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (c) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('Add Local Club', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter the name of the new club for your college."),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Club Name',
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.business_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), 
                child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.primary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                await FirebaseFirestore.instance.collection('clubs').add({
                  'clubName': nameController.text.trim(),
                  'college': widget.collegeName,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(c);
              },
              child: const Text('Add Club')),
          ],
        ),
      ),
    );
  }

  // --- Main UI Build ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
        canPop: false,
        onPopInvoked: (bool didPop) async {
          if (didPop) return;
          final bool? shouldPop = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Exit'),
              content: const Text('Are you sure you want to exit?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('No')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Yes')),
              ],
            ),
          );
          if (shouldPop ?? false) {
            Navigator.pop(context);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              (facultyName ?? widget.collegeName).toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w900, 
                letterSpacing: 2.0,
                fontSize: 20,
              ),
            ),
            centerTitle: false,
            backgroundColor: Colors.transparent,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white).withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.6),
                ),
              ),
            ),
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: _handleLogout,
              ),
            ],
          ),
          body: Stack(
            children: [
              const VibrantBackground(),
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // Immersive Header
                    Padding(
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
                            (facultyName ?? widget.collegeName).toLowerCase(),
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
                    const SizedBox(height: 32),
                    // Functional Cards Grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.15,
                        children: [
                          _buildPremiumCard(
                            "Mapping", 
                            "Assign Faculty to Clubs",
                            Icons.rule_folder_rounded, 
                            const [Color(0xFF6366F1), Color(0xFF4F46E5)],
                            _openMappingDashboard,
                            0
                          ),
                          _buildPremiumCard(
                            "Clubs", 
                            "Manage Local Groups",
                            Icons.business_center_rounded, 
                            const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                            _openManageClubs,
                            1
                          ),
                          _buildPremiumCard(
                            "Add Club", 
                            "Create New Entries",
                            Icons.add_business_rounded, 
                            const [Color(0xFF10B981), Color(0xFF059669)],
                            _addClubDialog,
                            2
                          ),
                          _buildPremiumCard(
                            "Register", 
                            "Manual/Bulk Faculty Add",
                            Icons.person_add_rounded, 
                            const [Color(0xFFF59E0B), Color(0xFFD97706)],
                            () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (c) =>
                                          AddFacultyScreen(collegeName: widget.collegeName)));
                            },
                            3
                          ),
                          _buildPremiumCard(
                            "Analytics", 
                            "College Usage Trends",
                            Icons.analytics_rounded, 
                            const [Color(0xFFEC4899), Color(0xFFDB2777)],
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (c) => AnalyticsDashboardScreen(
                                    collegeName: widget.collegeName,
                                  ),
                                ),
                              );
                            },
                            4
                          ),
                          _buildPremiumCard(
                            "Directory", 
                            "View All Students",
                            Icons.folder_shared_rounded, 
                            const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (c) => const StudentDirectoryScreen(),
                                ),
                              );
                            },
                            5
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: ScoopedNavigationBar(
            currentIndex: _selectedIndex > 1 ? 0 : _selectedIndex,
            onTap: _onItemTapped,
            activeColor: Theme.of(context).colorScheme.primary,
            items: const [
              ScoopedNavItem(icon: Icons.home_rounded, label: 'Home'),
              ScoopedNavItem(icon: Icons.person_rounded, label: 'Profile'),
            ],
          ),
        ));
  }

  Widget _buildPremiumCard(String title, String subtitle, IconData icon, List<Color> colors, VoidCallback onTap, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GlassCard(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors[0].withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    ).animate().fadeIn(delay: (100 * index).ms).slideY(begin: 0.1, duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }
}

class AddFacultyScreen extends StatefulWidget {
  final String collegeName;
  const AddFacultyScreen({super.key, required this.collegeName});

  @override
  State<AddFacultyScreen> createState() => _AddFacultyScreenState();
}

class _AddFacultyScreenState extends State<AddFacultyScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _phone = TextEditingController();

  Future<void> _register(String name, String email, String password) async {
    UserCredential cred =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    await FirebaseFirestore.instance.collection('faculty').doc(cred.user!.uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'college': widget.collegeName,
      'role': 'Faculty',
      'phone': '',
    });
  }

  Future<void> _handleManualRegister() async {
    if (_name.text.trim().isEmpty) { _showError("Full Name is required"); return; }
    if (_email.text.trim().isEmpty) { _showError("Email is required"); return; }
    if (!_isValidEmail(_email.text.trim())) { _showError("Please enter a valid email"); return; }
    if (_pass.text.length < 6) { _showError("Password must be at least 6 chars"); return; }

    try {
      await _register(_name.text, _email.text, _pass.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully registered ${_name.text}')));
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to register: ${e.toString()}');
    }
  }

  bool _isValidEmail(String email) => RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _uploadCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      final lines = await file.readAsLines(encoding: utf8);
      int successCount = 0;
      int failCount = 0;

      for (var i = 1; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().isEmpty) continue;
        final parts = line.split(',');
        if (parts.length >= 4) {
          final name = parts[1].trim();
          final email = parts[2].trim();
          final password = parts[3].trim();
          if (name.isNotEmpty && email.isNotEmpty && password.isNotEmpty) {
            try {
              await _register(name, email, password);
              successCount++;
            } catch (e) { failCount++; }
          } else { failCount++; }
        } else { failCount++; }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Finished. Success: $successCount, Failed: $failCount')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _openTemplate() async {
    try {
      final String templateString = await rootBundle.loadString('assets/faculty_template.csv');
      final Directory directory = await getApplicationDocumentsDirectory();
      final File file = File('${directory.path}/faculty_template.csv');
      await file.writeAsString(templateString);
      await OpenFile.open(file.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Register Faculty", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const VibrantBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 120, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassCard(
                  borderRadius: 32,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.person_add_rounded, size: 48, color: Colors.blue),
                        const SizedBox(height: 16),
                        const Text(
                          "Manual Entry",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(_name, "Full Name", Icons.person_outline_rounded),
                        const SizedBox(height: 16),
                        _buildTextField(_email, "Email Address", Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 16),
                        _buildTextField(_pass, "Password", Icons.lock_outline_rounded, obscureText: true),
                        const SizedBox(height: 16),
                        _buildTextField(_phone, "Phone Number", Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _handleManualRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text("Create Faculty Account", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ).animate().scale(delay: 200.ms),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                GlassCard(
                  borderRadius: 32,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.upload_file_rounded, size: 48, color: Colors.green),
                        const SizedBox(height: 16),
                        const Text(
                          "Bulk Upload",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Upload a CSV file to register multiple faculty members at once.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _uploadCsv,
                            icon: const Icon(Icons.publish_rounded),
                            label: const Text("Select & Upload CSV"),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: const BorderSide(color: Colors.green),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _openTemplate,
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text("Download CSV Template"),
                          style: TextButton.styleFrom(foregroundColor: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, 
      {bool obscureText = false, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}
