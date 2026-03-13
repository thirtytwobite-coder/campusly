import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_screen.dart';
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

  // 🔹 Fetch coordinator club
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

  // 🔹 Bottom navigation
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final exit = await _showExitDialog() ?? false;
        if (exit && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(clubName ?? 'Coordinator Dashboard'),
          actions: [
            // 🔹 DIRECT student switch icon (from old file)
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
              icon: const Icon(Icons.brightness_6),
              onPressed: _toggleTheme,
            ),
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
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex == 1 ? 0 : _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle, color: Colors.blue, size: 30),
              label: 'Add Program',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.green),
              ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.4),
              Text(
                    userName ?? "Coordinator",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
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
                      Colors.green,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AnalyticsScreen(
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

              const Text(
                "Events",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 15),

              TextField(
                decoration: InputDecoration(
                  hintText: 'Search events...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.1),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Club Description",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                  onPressed: () => _showEditDescriptionDialog(description),
                ),
              ],
            ),
            const Divider(),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showBrandingDialog(Map<String, dynamic> clubData) {
    final logoController = TextEditingController(
      text: clubData['profilePic'] ?? '',
    );
    final signatureController = TextEditingController(
      text: clubData['signatureUrl'] ?? '',
    );
    final facultySignatureController = TextEditingController(
      text: clubData['facultySignatureUrl'] ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Club Branding Settings"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "These settings will be applied to all your club certificates.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: logoController,
                decoration: const InputDecoration(
                  labelText: "Club Logo URL",
                  hintText: "Paste image or Drive link",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: signatureController,
                decoration: const InputDecoration(
                  labelText: "Coordinator Signature URL",
                  hintText: "Paste signature image link",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: facultySignatureController,
                decoration: const InputDecoration(
                  labelText: "Faculty Signature URL",
                  hintText: "Paste faculty signature link",
                  border: OutlineInputBorder(),
                ),
              ),
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
                    'profilePic': logoController.text.trim(),
                    'signatureUrl': signatureController.text.trim(),
                    'facultySignatureUrl': facultySignatureController.text
                        .trim(),
                  });
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Branding updated successfully!"),
                  ),
                );
              }
            },
            child: const Text("Save Settings"),
          ),
        ],
      ),
    );
  }

  void _showAddProgramProcedure(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Program Proposal Procedure",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Follow these steps to submit a new event for approval.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildStep(
              icon: Icons.edit_note,
              title: "1. Basic Info",
              description:
                  "Provide event name, category, and a clear description.",
            ),
            _buildStep(
              icon: Icons.calendar_month,
              title: "2. Schedule",
              description:
                  "Pick a date and time that doesn't conflict with other events.",
            ),
            _buildStep(
              icon: Icons.location_on_outlined,
              title: "3. Venue",
              description: "Specify the exact location/venue for the event.",
            ),
            _buildStep(
              icon: Icons.visibility_outlined,
              title: "4. Scope",
              description:
                  "Choose if the event is 'College Only' or open to the 'Public'.",
            ),
            _buildStep(
              icon: Icons.send_rounded,
              title: "5. Faculty Review",
              description:
                  "Once proposed, faculty will review and notify you of the status.",
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProgramDialog(BuildContext context) {
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
    // volunteer fields
    bool requiresVolunteers = false;
    final volunteerCountController = TextEditingController();
    final volunteerRoleController = TextEditingController();
    // team event fields
    bool isTeamEvent = false;
    final teamSizeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Program Proposal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: posterLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Poster Link',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Program Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: totalSeatsController,
                  decoration: const InputDecoration(
                    labelText: 'Total Seats (Capacity) *',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 100',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  hint: const Text('Select Category'),
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                            'Technical',
                            'Cultural',
                            'Sports',
                            'Academic',
                            'Social',
                            'Other',
                          ]
                          .map(
                            (l) => DropdownMenuItem(value: l, child: Text(l)),
                          )
                          .toList(),
                  onChanged: (v) => setDialogState(() => category = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: eventMode,
                  hint: const Text('Select Event Mode'),
                  decoration: const InputDecoration(
                    labelText: 'Event Mode *',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Online', 'Offline']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => eventMode = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date (YYYY-MM-DD) *',
                    border: OutlineInputBorder(),
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null)
                      dateController.text = DateFormat('yyyy-MM-dd').format(d);
                  },
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(
                    labelText: 'Time (HH:MM) *',
                    border: OutlineInputBorder(),
                  ),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (t != null)
                      timeController.text =
                          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                  },
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Venue *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: hasPrizePool,
                  title: const Text('Prize Pool'),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() {
                    hasPrizePool = v ?? false;
                    if (!hasPrizePool) prizeAmountController.clear();
                  }),
                ),
                if (hasPrizePool)
                  TextField(
                    controller: prizeAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Prize Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                const SizedBox(height: 12),
                // Volunteer option for programs
                StatefulBuilder(
                  builder: (context, setDialogStateInner) => Column(
                    children: [
                      CheckboxListTile(
                        value: requiresVolunteers,
                        title: const Text('Require Volunteers'),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setDialogStateInner(
                          () => requiresVolunteers = v ?? false,
                        ),
                      ),
                      if (requiresVolunteers) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: volunteerCountController,
                          decoration: const InputDecoration(
                            labelText: 'Number of Volunteers',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: volunteerRoleController,
                          decoration: const InputDecoration(
                            labelText: 'Volunteer Role / Instructions',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (context, setDialogStateInner) => Column(
                    children: [
                      CheckboxListTile(
                        value: isTeamEvent,
                        title: const Text('Team Event'),
                        subtitle: const Text(
                          'Students must register as a team',
                        ),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) =>
                            setDialogStateInner(() => isTeamEvent = v ?? false),
                      ),
                      if (isTeamEvent) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: teamSizeController,
                          decoration: const InputDecoration(
                            labelText: 'Team Size',
                            hintText: 'e.g. 3, 4, 5',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const Text(
                  'Visibility',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                RadioListTile<String>(
                  value: 'college',
                  groupValue: visibility,
                  onChanged: (v) => setDialogState(() => visibility = v!),
                  title: const Text('College Only'),
                ),
                RadioListTile<String>(
                  value: 'public',
                  groupValue: visibility,
                  onChanged: (v) => setDialogState(() => visibility = v!),
                  title: const Text('Public'),
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

      // show loading state if needed, though Navigator.pop happens immediately after Firestore call
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
            // volunteer details
            'requiresVolunteers': requiresVolunteers,
            'volunteerCount': volunteerCount.isNotEmpty
                ? int.tryParse(volunteerCount) ?? 0
                : null,
            'volunteerRole': volunteerRole.isNotEmpty
                ? volunteerRole.trim()
                : null,
            // seat details
            'totalSeats': int.tryParse(totalSeats.trim()) ?? 0,
            'filledSeats': 0, // Need to track filled seats from the beginning
            // team event details
            'isTeamEvent': isTeamEvent,
            'teamSize': isTeamEvent ? int.tryParse(teamSize.trim()) ?? 0 : null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      // Close proposal dialog
      if (mounted) Navigator.pop(ctx);
      
      // Navigate to Home or Stay on Home (Coordinator Dashboard)
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Notifications"),
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
                return const Center(child: Text("No notifications"));
              final docs = snapshot.data!.docs;
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(
                      data['title'] ?? 'Notification',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(data['message'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, size: 20),
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
        // 1. Update local Club Program directly
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

        // 2. Update Global Event
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
        // Fallback for other statuses (request approval)
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
    // 🔹 1. Check registrations for the PROGRAM ID (local club programs)
    final progRegs = await FirebaseFirestore.instance
        .collection('registrations')
        .where('eventId', isEqualTo: pId)
        .limit(1)
        .get();

    // 🔹 2. Check registrations for the GLOBAL EVENT ID (linked via programId)
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
                // 1. Delete local program
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId!)
                    .collection('programs')
                    .doc(pId)
                    .delete();

                // 2. Delete global event(s)
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
    final nameController = TextEditingController(text: data['name']);
    final descriptionController = TextEditingController(
      text: data['description'],
    );
    final dateController = TextEditingController(text: data['date']);
    final locationController = TextEditingController(text: data['location']);
    final timeController = TextEditingController(text: data['time']);
    final posterLinkController = TextEditingController(
      text: data['posterLink'] ?? '',
    );
    final prizeAmountController = TextEditingController(
      text: data['prizeAmount'] ?? '',
    );
    String visibility = data['visibility'] ?? 'college';
    bool hasPrizePool = data['hasPrizePool'] ?? false;
    String? category = data['category'];
    String? eventMode = data['eventMode'];
    // volunteer fields (pre-fill from program data)
    bool requiresVolunteers = data['requiresVolunteers'] ?? false;
    final volunteerCountController = TextEditingController(
      text: (data['volunteerCount'] ?? '').toString(),
    );
    final volunteerRoleController = TextEditingController(
      text: data['volunteerRole'] ?? '',
    );
    // team fields
    bool isTeamEvent = data['isTeamEvent'] ?? false;
    final teamSizeController = TextEditingController(
      text: (data['teamSize'] ?? '').toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Program'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: posterLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Poster Link (Google Drive)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Program Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  hint: const Text('Select Category'),
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                            'Technical',
                            'Cultural',
                            'Sports',
                            'Academic',
                            'Social',
                            'Other',
                          ]
                          .map(
                            (label) => DropdownMenuItem(
                              value: label,
                              child: Text(label),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      category = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: eventMode,
                  hint: const Text('Select Event Mode'),
                  decoration: const InputDecoration(
                    labelText: 'Event Mode *',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Online', 'Offline']
                      .map(
                        (label) =>
                            DropdownMenuItem(value: label, child: Text(label)),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      eventMode = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date (YYYY-MM-DD) *',
                    border: OutlineInputBorder(),
                  ),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (pickedDate != null) {
                      dateController.text = DateFormat(
                        'yyyy-MM-dd',
                      ).format(pickedDate);
                    }
                  },
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(
                    labelText: 'Time (HH:MM) *',
                    border: OutlineInputBorder(),
                  ),
                  onTap: () async {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (pickedTime != null) {
                      timeController.text =
                          '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                    }
                  },
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Venue *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: hasPrizePool,
                  onChanged: (value) {
                    setDialogState(() {
                      hasPrizePool = value ?? false;
                      if (!hasPrizePool) {
                        prizeAmountController.clear();
                      }
                    });
                  },
                  title: const Text('Prize Pool Available'),
                  subtitle: const Text('Does this program have prize rewards?'),
                  contentPadding: EdgeInsets.zero,
                ),
                if (hasPrizePool) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: prizeAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Prize Amount',
                      hintText: 'e.g., 5000, 10000',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 16),
                // Volunteer settings (editable)
                StatefulBuilder(
                  builder: (context, setInner) => Column(
                    children: [
                      CheckboxListTile(
                        value: requiresVolunteers,
                        title: const Text('Require Volunteers'),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) =>
                            setInner(() => requiresVolunteers = v ?? false),
                      ),
                      if (requiresVolunteers) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: volunteerCountController,
                          decoration: const InputDecoration(
                            labelText: 'Number of Volunteers',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: volunteerRoleController,
                          decoration: const InputDecoration(
                            labelText: 'Volunteer Role / Instructions',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (context, setInner) => Column(
                    children: [
                      CheckboxListTile(
                        value: isTeamEvent,
                        title: const Text('Team Event'),
                        subtitle: const Text(
                          'Students must register as a team',
                        ),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) =>
                            setInner(() => isTeamEvent = v ?? false),
                      ),
                      if (isTeamEvent) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: teamSizeController,
                          decoration: const InputDecoration(
                            labelText: 'Team Size',
                            hintText: 'e.g. 3, 4, 5',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Event Visibility',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Column(
                  children: [
                    RadioListTile<String>(
                      value: 'college',
                      groupValue: visibility,
                      onChanged: (value) {
                        setDialogState(() {
                          visibility = value!;
                        });
                      },
                      title: const Text('College Only'),
                      subtitle: const Text(
                        'Only students from this college can participate',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      value: 'public',
                      groupValue: visibility,
                      onChanged: (value) {
                        setDialogState(() {
                          visibility = value!;
                        });
                      },
                      title: const Text('Public'),
                      subtitle: const Text(
                        'Students from other colleges can also participate',
                      ),
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(validationError)));
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
            // volunteer fields
            'requiresVolunteers': requiresVolunteers,
            'volunteerCount': volunteerCount.isNotEmpty
                ? int.tryParse(volunteerCount) ?? 0
                : null,
            'volunteerRole': volunteerRole.isNotEmpty
                ? volunteerRole.trim()
                : null,
            // team event fields
            'isTeamEvent': isTeamEvent,
            'teamSize': isTeamEvent ? int.tryParse(teamSize.trim()) ?? 0 : null,
            'status': 'pending', // Reset status on edit
            'updatedAt': FieldValue.serverTimestamp(),
          });
      // keep the corresponding global event document in sync as well
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
    final controller = TextEditingController(text: current);
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Club Description"),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Describe your club activities...",
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
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Exit Dashboard?"),
        content: const Text("Do you want to exit the application?"),
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
    final status = (programData['status'] ?? 'pending').toString().toLowerCase();
    final bool isCompleted = status == 'completed';
    final bool isApproved = status == 'approved' || status == 'ongoing' || status == 'completed';

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'ongoing':
        statusColor = Colors.orange;
        statusIcon = Icons.play_circle_filled;
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusIcon = Icons.task_alt;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.hourglass_empty;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (status == 'pending' || status == 'rejected')
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              programData['name'] ?? 'Untitled Event',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              "${programData['category'] ?? 'General'} • ${programData['date'] ?? 'TBD'}",
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            if (isApproved) ...[
              const Divider(height: 20),
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to EventRegistrationsListScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventRegistrationsListScreen(
                          eventId: programId, // Or actual global event ID if needed
                          eventName: programData['name'] ?? 'Event',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text("Manage Winners & Certificates"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
            ],
          ],
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
    return InkWell(
      onTap: active ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? Theme.of(context).primaryColor : Colors.grey[300],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: active ? Theme.of(context).primaryColor : Colors.grey[300],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
