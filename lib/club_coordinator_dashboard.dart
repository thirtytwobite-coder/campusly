import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
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
          title: Text(clubName ?? 'Coordinator Dashboard'),
          backgroundColor: isDark ? Colors.black : Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: "Switch to Student View",
              icon: const Icon(Icons.person_pin_circle),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
                );
              },
            ),
            IconButton(
              tooltip: "Notifications",
              icon: const Icon(Icons.notifications),
              onPressed: _showNotifications,
            ),
            IconButton(
              icon: Icon(isDark ? Icons.brightness_7 : Icons.brightness_6),
              onPressed: _toggleTheme,
            ),
          ],
        ),
        body: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            return false;
          },
          child: Stack(
            children: [
              const VibrantBackground(),
              _loading
                  ? _buildLoadingState()
                  : clubId == null
                  ? const Center(child: Text("No club assigned"))
                  : _buildDashboardBody(),
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
                      color: Colors.black.withOpacity(isDark ? 0.3 : .1),
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
                      activeColor: Colors.blue,
                      iconSize: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      duration: const Duration(milliseconds: 400),
                      tabBackgroundColor: Colors.blue.withOpacity(0.1),
                      color: isDark ? Colors.white60 : Theme.of(context).iconTheme.color?.withOpacity(0.6) ?? Colors.grey,
                      tabs: [
                        GButton(icon: Icons.dashboard, text: 'Home'),
                        GButton(icon: Icons.add_circle, text: 'Add Program'),
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

        return SingleChildScrollView(
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
              const SizedBox(height: 25),

              _clubDescriptionCard(description),

              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      "Analytics",
                      "View Stats",
                      Icons.bar_chart,
                      Colors.blue,
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildQuickActionCard(
                      "Certificates",
                      "Issue & Winners",
                      Icons.workspace_premium,
                      Colors.orange,
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      "Feedback",
                      "Student Reviews",
                      Icons.feedback_outlined,
                      Colors.green,
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
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildQuickActionCard(
                      "Club Branding",
                      "Logo & Signatures",
                      Icons.brush_outlined,
                      Colors.purple,
                          () => _showBrandingDialog(clubData),
                    ),
                  ),
                ],
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

              GlassCard(
                borderRadius: 15,
                child: TextField(
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Search events...',
                    hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                ),
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

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final programDoc = docs[index];
                      final programData =
                      programDoc.data() as Map<String, dynamic>;

                      return ProgramCard(
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
    
    return GlassCard(
      borderRadius: 15,
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Club Description",
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                    onPressed: () => _showEditDescriptionDialog(description),
                  ),
                ],
              ),
              Divider(color: isDark ? Colors.white12 : Colors.grey[300]),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildQuickActionCard(
      String title,
      String subtitle,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GlassCard(
      borderRadius: 15,
      color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10, 
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBrandingDialog(Map<String, dynamic> clubData) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String logoBase64 = clubData['profilePic'] ?? '';
    final signatureController = TextEditingController(text: clubData['signatureUrl'] ?? '');
    final facultySignatureController = TextEditingController(text: clubData['facultySignatureUrl'] ?? '');

    bool isProcessingLogo = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text("Club Branding Settings", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Update your club logo and official signatures for certificates.",
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
                ),
                const SizedBox(height: 20),
                
                // 🔹 Logo Upload Section
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey[100],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
                      ),
                      child: ClipOval(
                        child: logoBase64.isNotEmpty
                            ? (logoBase64.startsWith('data:image') 
                                ? Image.memory(base64Decode(logoBase64.split(',').last), fit: BoxFit.cover)
                                : Image.network(logoBase64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.business, size: 40)))
                            : const Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.blue),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue,
                        child: IconButton(
                          icon: isProcessingLogo 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          onPressed: isProcessingLogo ? null : () async {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                            if (pickedFile == null) return;

                            setDialogState(() => isProcessingLogo = true);
                            try {
                              final bytes = await pickedFile.readAsBytes();
                              final base64String = base64Encode(bytes);
                              setDialogState(() {
                                logoBase64 = 'data:image/jpeg;base64,$base64String';
                                isProcessingLogo = false;
                              });
                            } catch (e) {
                              setDialogState(() => isProcessingLogo = false);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text("Club Logo", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                
                const SizedBox(height: 24),
                _buildBrandingField(signatureController, "Coordinator Signature URL", isDark),
                const SizedBox(height: 12),
                _buildBrandingField(facultySignatureController, "Faculty Signature URL", isDark),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId)
                    .update({
                  'profilePic': logoBase64.trim(),
                  'signatureUrl': signatureController.text.trim(),
                  'facultySignatureUrl': facultySignatureController.text.trim(),
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Branding updated successfully!")),
                  );
                }
              },
              child: const Text("Save Settings"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingField(TextEditingController controller, String label, bool isDark) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        hintText: "Paste image link",
        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
      ),
    );
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
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _showAddProgramDialog(context);
                },
                child: const Text(
                  "PROCEED TO PROPOSAL FORM",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13, 
                    color: isDark ? Colors.white60 : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
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

    bool isUploadingPoster = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text('New Program Proposal', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
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
                _buildProposalField(totalSeatsController, 'Total Seats (Capacity) *', isDark, keyboardType: TextInputType.number),
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
                      .map((l) => DropdownMenuItem(value: l, child: Text(l, style: TextStyle(color: isDark ? Colors.white : Colors.black))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v),
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
                      .map((m) => DropdownMenuItem(value: m, child: Text(m, style: TextStyle(color: isDark ? Colors.white : Colors.black))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => eventMode = v),
                ),
                const SizedBox(height: 12),
                _buildProposalField(dateController, 'Date (YYYY-MM-DD) *', isDark, readOnly: true, onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) dateController.text = DateFormat('yyyy-MM-dd').format(d);
                }),
                const SizedBox(height: 12),
                _buildProposalField(timeController, 'Time (HH:MM) *', isDark, readOnly: true, onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (t != null)
                      timeController.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                }),
                const SizedBox(height: 12),
                _buildProposalField(locationController, 'Venue *', isDark),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: hasPrizePool,
                  title: Text('Prize Pool', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() {
                    hasPrizePool = v ?? false;
                    if (!hasPrizePool) prizeAmountController.clear();
                  }),
                ),
                if (hasPrizePool)
                  _buildProposalField(prizeAmountController, 'Prize Amount', isDark, prefixText: '₹ ', keyboardType: TextInputType.number),
                const SizedBox(height: 12),
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
                Divider(color: isDark ? Colors.white12 : Colors.grey[300]),
                Text('Visibility', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                RadioListTile<String>(
                  value: 'college',
                  groupValue: visibility,
                  onChanged: (v) => setDialogState(() => visibility = v!),
                  title: Text('College Only', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                ),
                RadioListTile<String>(
                  value: 'public',
                  groupValue: visibility,
                  onChanged: (v) => setDialogState(() => visibility = v!),
                  title: Text('Public', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
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
              onPressed: () => _handlePropose(
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
              ),
              child: const Text('Submit Proposal'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProposalField(TextEditingController controller, String label, bool isDark, {int maxLines = 1, bool readOnly = false, VoidCallback? onTap, TextInputType? keyboardType, String? prefixText}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        prefixText: prefixText,
        prefixStyle: TextStyle(color: isDark ? Colors.white : Colors.black),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
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
      ) async {
    if (name.trim().isEmpty ||
        desc.trim().isEmpty ||
        date.trim().isEmpty ||
        time.trim().isEmpty ||
        loc.trim().isEmpty ||
        totalSeats.trim().isEmpty ||
        cat == null ||
        mode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill required fields (Name, Description, Total Seats, Date, Time, Venue, Category, Event Mode)',
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
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
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
    try {
      if (['ongoing', 'completed', 'cancelled'].contains(s)) {
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

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Event marked as $s')));
      } else {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

    bool isUploadingPoster = false;

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
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (pickedDate != null) dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
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
                );

                if (validationError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validationError)));
                  return;
                }

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
      ) {
    if (name.trim().isEmpty) return 'Program name cannot be empty';
    if (desc.trim().isEmpty) return 'Description cannot be empty';
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
        statusColor = isDark ? Colors.greenAccent : Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'ongoing':
        statusColor = Colors.orange;
        statusIcon = Icons.play_circle_filled;
        break;
      case 'completed':
        statusColor = isDark ? Colors.lightBlueAccent : Colors.blue;
        statusIcon = Icons.task_alt;
        break;
      case 'rejected':
        statusColor = isDark ? Colors.redAccent : Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = isDark ? Colors.white54 : Colors.grey;
        statusIcon = Icons.hourglass_empty;
    }

    return GlassCard(
      borderRadius: 15,
      color: statusColor.withOpacity(0.1),
      child: InkWell(
        onTap: () => _showProgramDetails(context),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.white54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, size: 16, color: statusColor),
                  ),
                  Row(
                    children: [
                      if (status == 'pending' || status == 'rejected')
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                          onPressed: onEdit,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 16, color: isDark ? Colors.redAccent : Colors.red),
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                programData['name'] ?? 'Untitled Event',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                programData['category'] ?? 'General',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Text(
                programData['date'] ?? 'TBD',
                style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10),
              ),
              const Spacer(),
              if (isApproved && !isCompleted) ...[
                Divider(color: isDark ? Colors.white12 : Colors.black12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statusActionButton(
                      context,
                      label: "Start",
                      icon: Icons.play_arrow,
                      active: status == 'approved',
                      onTap: () => onStatusChange('ongoing'),
                    ),
                    _statusActionButton(
                      context,
                      label: "Finish",
                      icon: Icons.done_all,
                      active: status == 'ongoing',
                      onTap: () => onStatusChange('completed'),
                    ),
                  ],
                ),
              ],
              if (isCompleted) ...[
                Divider(color: isDark ? Colors.white12 : Colors.black12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
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
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: isDark ? Colors.orangeAccent : Colors.orange.shade800,
                      side: BorderSide(color: isDark ? Colors.orangeAccent : Colors.orange.shade800),
                      textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    child: const Text("MANAGE WINNERS"),
                  ),
                ),
              ],
            ],
          ),
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
    final primaryColor = isDark ? Colors.blueAccent : Colors.blue.shade700;
    
    return InkWell(
      onTap: active ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: active ? primaryColor : (isDark ? Colors.white24 : Colors.black12),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: active ? primaryColor : (isDark ? Colors.white24 : Colors.black12),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showProgramDetails(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(programData['name'] ?? 'Event Details',
            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (programData['posterLink'] != null && programData['posterLink'].toString().isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (programData['posterLink'] != null && programData['posterLink'].toString().startsWith('data:image'))
                      ? Image.memory(
                    base64Decode(programData['posterLink'].toString().split(',').last),
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  )
                      : Image.network(
                    programData['posterLink'],
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                programData['description'] ?? 'No description available', 
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)
              ),
              const SizedBox(height: 16),
              _buildDetailRow(ctx, Icons.calendar_today, "Date", programData['date'] ?? 'TBD', isDark),
              _buildDetailRow(ctx, Icons.access_time, "Time", programData['time'] ?? 'TBD', isDark),
              _buildDetailRow(ctx, Icons.location_on, "Venue", programData['location'] ?? 'TBD', isDark),
              _buildDetailRow(ctx, Icons.category, "Category", programData['category'] ?? 'General', isDark),
              _buildDetailRow(ctx, Icons.visibility, "Visibility", programData['visibility']?.toString().toUpperCase() ?? 'COLLEGE', isDark),
              if (programData['eventMode'] != null)
                _buildDetailRow(ctx, Icons.laptop, "Mode", programData['eventMode'], isDark),
              if (programData['totalSeats'] != null)
                _buildDetailRow(ctx, Icons.event_seat, "Capacity", programData['totalSeats'].toString(), isDark),
              if (programData['hasPrizePool'] == true)
                _buildDetailRow(ctx, Icons.emoji_events, "Prize", "₹${programData['prizeAmount'] ?? ''}", isDark),
              if (programData['requiresVolunteers'] == true) ...[
                Divider(color: isDark ? Colors.white12 : Colors.grey[300]),
                Text("Volunteer Details", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 8),
                _buildDetailRow(ctx, Icons.people, "Needed", programData['volunteerCount']?.toString() ?? 'N/A', isDark),
                _buildDetailRow(ctx, Icons.assignment, "Role", programData['volunteerRole'] ?? 'N/A', isDark),
              ],
              if (programData['isTeamEvent'] == true) ...[
                Divider(color: isDark ? Colors.white12 : Colors.grey[300]),
                Text("Team Event", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 8),
                _buildDetailRow(ctx, Icons.group, "Team Size", programData['teamSize']?.toString() ?? 'N/A', isDark),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.blueAccent : Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
                children: [
                  TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
