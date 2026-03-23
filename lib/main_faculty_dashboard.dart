import 'dart:ui';
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
      builder: (c) => AlertDialog(
        title: Text("Map Faculty to $clubName"),
        content: DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: "Select Faculty Member"),
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
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
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
      builder: (c) => AlertDialog(
        title: const Text('Add Local Club'),
        content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Club Name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                await FirebaseFirestore.instance.collection('clubs').add({
                  'clubName': nameController.text.trim(),
                  'college': widget.collegeName,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(c);
              },
              child: const Text('Add')),
        ],
      ),
    );
  }

  // --- Main UI Build ---

  @override
  Widget build(BuildContext context) {
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
              widget.collegeName,
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.0),
            ),
            backgroundColor: Colors.transparent,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white).withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.6),
                ),
              ),
            ),
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: Stack(
            children: [
              const VibrantBackground(),
              GridView.count(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildCard("Mapping Dashboard", Icons.rule_folder_outlined, _openMappingDashboard),
                  _buildCard("Manage Clubs", Icons.business_center_outlined, _openManageClubs),
                  _buildCard("Add Local Club", Icons.add_business_outlined, _addClubDialog),
                  _buildCard("Register Faculty", Icons.person_add_alt_1_outlined, () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (c) =>
                                AddFacultyScreen(collegeName: widget.collegeName)));
                  }),
                  _buildCard("College Analytics", Icons.analytics_outlined, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => AnalyticsDashboardScreen(
                          collegeName: widget.collegeName,
                        ),
                      ),
                    );
                  }),
                ],
              ).animate().fadeIn(duration: 300.ms).slideY(),
            ],
          ),
          bottomNavigationBar: ScoopedNavigationBar(
            currentIndex: _selectedIndex > 1 ? 0 : _selectedIndex,
            onTap: _onItemTapped,
            activeColor: Theme.of(context).colorScheme.primary,
            items: const [
              ScoopedNavItem(icon: Icons.home_rounded, label: 'Home'),
              ScoopedNavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
            ],
          ),
        ));
  }

  Widget _buildCard(String title, IconData icon, VoidCallback onTap) {
    return GlassCard(
      borderRadius: 20,
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      appBar: AppBar(title: const Text("Register Faculty")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: "Full Name")),
            const SizedBox(height: 16),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email")),
            const SizedBox(height: 16),
            TextField(controller: _pass, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
            const SizedBox(height: 16),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number")),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _handleManualRegister, child: const Text("Create Faculty Account")),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            OutlinedButton.icon(onPressed: _uploadCsv, icon: const Icon(Icons.upload_file_outlined), label: const Text("Upload CSV File")),
            const SizedBox(height: 10),
            TextButton(onPressed: _openTemplate, child: const Text("Open CSV Template")),
          ],
        ),
      ),
    );
  }
}
