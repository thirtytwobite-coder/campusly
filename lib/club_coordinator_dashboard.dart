import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_screen.dart';
import 'change_password.dart';
import 'login_screen.dart';
import 'main.dart';
import 'manage_programs.dart';
import 'profile_screen.dart';
import 'student_home.dart';

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
  int _selectedIndex = 0;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    clubId = widget.initialClubId;
    clubName = widget.initialClubName;

    if (clubId == null) {
      _fetchClubInfo();
    } else {
      _loading = false;
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
                  MaterialPageRoute(
                    builder: (_) => const StudentHomeScreen(),
                  ),
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
        body: _loading
            ? _buildLoadingState()
            : clubId == null
            ? const Center(child: Text("No club assigned"))
            : _buildDashboardBody(),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex == 1 ? 0 : _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle, color: Colors.blue, size: 30), label: 'Add Program'),
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

        final clubData =
        snapshot.data!.data() as Map<String, dynamic>;
        final description =
            clubData['description'] ?? 'No description set.';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome Back,",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.grey)),
              Text(
                clubName ?? "Coordinator",
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 25),

              _clubDescriptionCard(description),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
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

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Recent Programs",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
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
                  if (snapshot.hasError) return Text('Error: ${snapshot.error}');
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          children: [
                            const Icon(Icons.event_note, size: 60, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text('No programs created yet', style: TextStyle(color: Colors.grey)),
                            TextButton(
                              onPressed: () => _showAddProgramProcedure(context),
                              child: const Text("Create your first program"),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length > 3 ? 3 : docs.length,
                    itemBuilder: (context, index) {
                      final programDoc = docs[index];
                      final programData = programDoc.data() as Map<String, dynamic>;

                      return ProgramCard(
                        programId: programDoc.id,
                        clubId: clubId!,
                        programData: programData,
                        onEdit: () => _showEditProgramDialog(context, programDoc.id, programData),
                        onDelete: () => _confirmDelete(context, programDoc.id),
                        onStatusChange: (newStatus) => _requestStatusChange(programDoc.id, newStatus),
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
                const Text("Club Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                  onPressed: () => _showEditDescriptionDialog(description),
                ),
              ],
            ),
            const Divider(),
            Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildQuickActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
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
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 24),
            const Text("Program Proposal Procedure", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Follow these steps to submit a new event for approval.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            _buildStep(icon: Icons.edit_note, title: "1. Basic Info", description: "Provide event name, category, and a clear description."),
            _buildStep(icon: Icons.calendar_month, title: "2. Schedule", description: "Pick a date and time that doesn't conflict with other events."),
            _buildStep(icon: Icons.location_on_outlined, title: "3. Venue", description: "Specify the exact location/venue for the event."),
            _buildStep(icon: Icons.visibility_outlined, title: "4. Scope", description: "Choose if the event is 'College Only' or open to the 'Public'."),
            _buildStep(icon: Icons.send_rounded, title: "5. Faculty Review", description: "Once proposed, faculty will review and notify you of the status."),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _showAddProgramDialog(context);
                },
                child: const Text("PROCEED TO PROPOSAL FORM", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({required IconData icon, required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle), child: Icon(icon, color: Colors.blue, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(description, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ])),
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
    bool hasPrizePool = false;
    String visibility = 'college';
    String? category;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Program Proposal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: posterLinkController, decoration: const InputDecoration(labelText: 'Poster Link', border: OutlineInputBorder(), prefixIcon: Icon(Icons.image))),
                const SizedBox(height: 12),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Program Name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()), maxLines: 3),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category, hint: const Text('Select Category'), decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: ['Technical', 'Cultural', 'Sports', 'Academic', 'Social', 'Other'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                  onChanged: (v) => setDialogState(() => category = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)', border: OutlineInputBorder()),
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (d != null) dateController.text = DateFormat('yyyy-MM-dd').format(d);
                  },
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeController, decoration: const InputDecoration(labelText: 'Time (HH:MM)', border: OutlineInputBorder()),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (t != null) timeController.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                  },
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: hasPrizePool, title: const Text('Prize Pool'), contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() { hasPrizePool = v ?? false; if (!hasPrizePool) prizeAmountController.clear(); }),
                ),
                if (hasPrizePool) TextField(controller: prizeAmountController, decoration: const InputDecoration(labelText: 'Prize Amount', prefixText: '₹ ', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                const Divider(),
                const Text('Visibility', style: TextStyle(fontWeight: FontWeight.bold)),
                RadioListTile<String>(value: 'college', groupValue: visibility, onChanged: (v) => setDialogState(() => visibility = v!), title: const Text('College Only')),
                RadioListTile<String>(value: 'public', groupValue: visibility, onChanged: (v) => setDialogState(() => visibility = v!), title: const Text('Public')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => _handlePropose(ctx, nameController.text, descriptionController.text, dateController.text, timeController.text, locationController.text, hasPrizePool, prizeAmountController.text, posterLinkController.text, visibility, category), child: const Text('Submit Proposal')),
          ],
        ),
      ),
    );
  }

  void _handlePropose(BuildContext ctx, String name, String desc, String date, String time, String loc, bool hasPrize, String prize, String poster, String vis, String? cat) async {
    if (name.trim().isEmpty || date.trim().isEmpty || cat == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill required fields (Name, Date, Category)')));
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      DocumentSnapshot uDoc = await FirebaseFirestore.instance.collection('student').doc(user?.uid).get();
      if (!uDoc.exists) uDoc = await FirebaseFirestore.instance.collection('faculty').doc(user?.uid).get();
      final nameStr = (uDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Unknown';
      final coll = (uDoc.data() as Map<String, dynamic>?)?['college'] ?? 'Unknown';

      await FirebaseFirestore.instance.collection('clubs').doc(clubId!).collection('programs').add({
        'name': name.trim(), 'description': desc.trim(), 'date': date, 'time': time, 'location': loc.trim(), 'posterLink': poster.trim(),
        'hasPrizePool': hasPrize, 'prizeAmount': prize, 'visibility': vis, 'college': coll, 'category': cat, 'status': 'pending',
        'clubId': clubId, 'clubName': clubName, 'coordinatorId': user?.uid, 'coordinatorName': nameStr, 'coordinatorEmail': user?.email,
        'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
      });
      Navigator.pop(ctx);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Program proposed successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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
            stream: FirebaseFirestore.instance.collection('clubs').doc(clubId).collection('notifications').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No notifications"));
              final docs = snapshot.data!.docs;
              return ListView.separated(
                itemCount: docs.length, separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['title'] ?? 'Notification', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(data['message'] ?? ''),
                    trailing: IconButton(icon: const Icon(Icons.delete, size: 20), onPressed: () => docs[index].reference.delete()),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  void _requestStatusChange(String pId, String s) async {
    try {
      await FirebaseFirestore.instance.collection('clubs').doc(clubId!).collection('programs').doc(pId).update({'status': 'pending', 'requestedStatus': s, 'updatedAt': FieldValue.serverTimestamp()});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status change to $s requested.')));
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
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
          content: const Text('This program has registered participants and cannot be deleted.'),
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
        title: const Text('Delete Program?'), content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () async { await FirebaseFirestore.instance.collection('clubs').doc(clubId!).collection('programs').doc(pId).delete(); Navigator.pop(ctx); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _showEditProgramDialog(BuildContext context, String pId, Map<String, dynamic> data) {
    // Implement edit if needed
  }

  Future<void> _toggleTheme() async {
    themeNotifier.value = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    (await SharedPreferences.getInstance()).setBool('isDarkMode', themeNotifier.value == ThemeMode.dark);
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
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Describe your club activities..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (clubId != null && controller.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance.collection('clubs').doc(clubId!).update({'description': controller.text.trim()});
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Exit")),
        ],
      ),
    );
  }
}

class _ProcedureStep extends StatelessWidget {
  final String step;
  final String text;
  const _ProcedureStep({required this.step, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 12, backgroundColor: Colors.blue, child: Text(step, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
