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
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManageProgramsScreen(
            clubId: clubId!,
            clubName: clubName ?? 'Club',
          ),
        ),
      );
    } else if (index == 2) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }

    setState(() => _selectedIndex = 0);
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
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.add_circle), label: 'Programs'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person), label: 'Profile'),
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
                  "View Registrations",
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
                  const Text("Events",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28),
                    onPressed: () => _showAddProgramDialog(context),
                    tooltip: "Add Event",
                  ),
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
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.event_note, size: 60, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text(
                            'No programs created yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                          TextButton(
                            onPressed: () => _showAddProgramDialog(context),
                            child: const Text("Create One"),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final programDoc = snapshot.data!.docs[index];
                      final programData = programDoc.data() as Map<String, dynamic>;

                      return ProgramCard(
                        programId: programDoc.id,
                        clubId: clubId!,
                        programData: programData,
                        onEdit: () => _showEditProgramDialog(context, programDoc.id, programData),
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
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Club Description",
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.edit,
                      size: 20, color: Colors.blue),
                  onPressed: () =>
                      _showEditDescriptionDialog(description),
                ),
              ],
            ),
            const Divider(),
            Text(
              description,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.5),
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
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            Text(subtitle,
                style:
                const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTheme() async {
    themeNotifier.value =
    themeNotifier.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(
        'isDarkMode', themeNotifier.value == ThemeMode.dark);
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
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Exit")),
        ],
      ),
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
          decoration:
          const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (clubId != null &&
                  controller.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId!)
                    .update(
                    {'description': controller.text.trim()});
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Notifications"),
        content: SizedBox(
          width: double.maxFinite,
          height: 400, // Fixed height for the list
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('clubs')
                .doc(clubId)
                .collection('notifications')
                // .orderBy('timestamp', descending: true) // Temporarily removed to debug index issues
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off,
                          size: 40, color: Colors.grey),
                      SizedBox(height: 10),
                      Text("No notifications yet"),
                    ],
                  ),
                );
              }

              // Manually sort since we removed orderBy
              final docs = snapshot.data!.docs;
              docs.sort((a, b) {
                final tA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                final tB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                if (tA == null) return 1;
                if (tB == null) return -1;
                return tB.compareTo(tA);
              });

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (ctx, i) => const Divider(),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final timestamp = data['timestamp'] as Timestamp?;
                  final dateStr = timestamp != null
                      ? DateFormat('MMM d, h:mm a').format(timestamp.toDate())
                      : 'Just now';
                  final type = data['type'] as String?;
                  final isRejection = type == 'rejection';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                      isRejection ? Colors.red[100] : Colors.green[100],
                      child: Icon(
                        isRejection ? Icons.error : Icons.check_circle,
                        color: isRejection ? Colors.red : Colors.green,
                      ),
                    ),
                    title: Text(data['title'] ?? 'Notification',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(data['message'] ?? ''),
                        const SizedBox(height: 4),
                        Text(dateStr,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('clubs')
                            .doc(clubId)
                            .collection('notifications')
                            .doc(docs[index].id)
                            .delete();
                      },
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
  void _showAddProgramDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final dateController = TextEditingController();
    final locationController = TextEditingController();
    final timeController = TextEditingController();
    final prizeAmountController = TextEditingController();
    final posterLinkController = TextEditingController();
    bool hasPrizePool = false;
    String visibility = 'college'; // 'college' or 'public'
    String? category;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Program'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: posterLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Poster Link',
                    hintText: 'Google Drive or image URL',
                    helperText: 'Works with Google Drive links and image URLs',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Program Name',
                    hintText: 'e.g. Annual Tech Summit',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Event details and objectives',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  hint: const Text('Select Category'),
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Technical', 'Cultural', 'Sports', 'Academic', 'Social', 'Other']
                      .map((label) => DropdownMenuItem(
                            value: label,
                            child: Text(label),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      category = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date (YYYY-MM-DD)',
                    hintText: '2024-12-25',
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
                      dateController.text =
                          DateFormat('yyyy-MM-dd').format(pickedDate);
                    }
                  },
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(
                    labelText: 'Time (HH:MM)',
                    hintText: '14:30',
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
                    labelText: 'Location',
                    hintText: 'Event venue',
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
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Event Visibility',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  value: 'college',
                  groupValue: visibility,
                  onChanged: (value) {
                    setDialogState(() {
                      visibility = value!;
                    });
                  },
                  title: const Text('College Only'),
                  subtitle: const Text('Only students from this college can participate'),
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
                  subtitle: const Text('Students from other colleges can also participate'),
                  contentPadding: EdgeInsets.zero,
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
                  dateController.text,
                  category,
                );

                if (validationError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(validationError)),
                  );
                  return;
                }

                _addProgram(
                  ctx,
                  nameController.text,
                  descriptionController.text,
                  dateController.text,
                  timeController.text,
                  locationController.text,
                  hasPrizePool,
                  prizeAmountController.text,
                  _convertGoogleDriveLink(posterLinkController.text),
                  visibility,
                  category!,
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProgramDialog(
    BuildContext context,
    String programId,
    Map<String, dynamic> programData,
  ) {
    final nameController = TextEditingController(text: programData['name']);
    final descriptionController =
        TextEditingController(text: programData['description']);
    final dateController = TextEditingController(text: programData['date']);
    final locationController =
        TextEditingController(text: programData['location']);
    final timeController = TextEditingController(text: programData['time']);
    final posterLinkController = TextEditingController(text: programData['posterLink'] ?? '');
    final prizeAmountController = TextEditingController(text: programData['prizeAmount'] ?? '');
    String visibility = programData['visibility'] ?? 'college';
    bool hasPrizePool = programData['hasPrizePool'] ?? false;
    String? category = programData['category'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                  labelText: 'Program Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                hint: const Text('Select Category'),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: ['Technical', 'Cultural', 'Sports', 'Academic', 'Social', 'Other']
                    .map((label) => DropdownMenuItem(
                          value: label,
                          child: Text(label),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    category = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (YYYY-MM-DD)',
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
                    dateController.text =
                        DateFormat('yyyy-MM-dd').format(pickedDate);
                  }
                },
                readOnly: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: 'Time (HH:MM)',
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
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setDialogState) => CheckboxListTile(
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
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Event Visibility',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setDialogState) => Column(
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
                      subtitle: const Text('Only students from this college can participate'),
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
                      subtitle: const Text('Students from other colleges can also participate'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
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
                dateController.text,
                category,
              );

              if (validationError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(validationError)),
                );
                return;
              }

              _updateProgram(
                ctx,
                programId,
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
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  String? _validateProgramForm(String name, String date, String? category) {
    if (name.trim().isEmpty) {
      return 'Program name cannot be empty';
    }
    if (date.trim().isEmpty) {
      return 'Date cannot be empty';
    }
    if (category == null) {
      return 'Please select a category';
    }

    try {
      DateFormat('yyyy-MM-dd').parseStrict(date);
    } catch (e) {
      return 'Invalid date format. Use YYYY-MM-DD';
    }

    return null;
  }

  String _convertGoogleDriveLink(String link) {
    if (link.isEmpty) return '';

    if (link.contains('.jpg') || link.contains('.jpeg') || link.contains('.png') || link.contains('.gif') || link.contains('.webp')) {
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

  Future<void> _addProgram(
    BuildContext context,
    String name,
    String description,
    String date,
    String time,
    String location,
    bool hasPrizePool,
    String prizeAmount,
    String posterLink,
    String visibility,
    String category,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user = FirebaseAuth.instance.currentUser;

      // Try fetching from both student and faculty collections to be safe
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('student').doc(user?.uid).get();
      if (!userDoc.exists) {
        userDoc = await FirebaseFirestore.instance.collection('faculty').doc(user?.uid).get();
      }

      final coordinatorName = (userDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Unknown';
      final college = (userDoc.data() as Map<String, dynamic>?)?['college'] ?? 'Unknown College';

      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId!)
          .collection('programs')
          .add({
        'name': name.trim(),
        'description': description.trim(),
        'date': date,
        'time': time,
        'location': location.trim(),
        'posterLink': posterLink.isNotEmpty ? posterLink.trim() : null,
        'hasPrizePool': hasPrizePool,
        'prizeAmount': hasPrizePool && prizeAmount.isNotEmpty ? prizeAmount : null,
        'visibility': visibility,
        'college': college,
        'category': category,
        'status': 'pending',
        'clubId': clubId!,
        'clubName': clubName ?? '',
        'coordinatorId': user?.uid,
        'coordinatorName': coordinatorName,
        'coordinatorEmail': user?.email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Program sent for approval!')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
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
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
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
        'prizeAmount': hasPrizePool && prizeAmount.isNotEmpty ? prizeAmount.trim() : null,
        'category': category,
        'status': 'pending', // Reset status on edit
        'updatedAt': FieldValue.serverTimestamp(),
      });
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Program updated and sent for re-approval!')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _requestStatusChange(String programId, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId!)
          .collection('programs')
          .doc(programId)
          .update({
        'status': 'pending',
        'requestedStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      messenger.showSnackBar(
        SnackBar(content: Text('Request to change status to $newStatus sent for approval')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _confirmDelete(BuildContext context, String programId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Program?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(ctx);
              try {
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId!)
                    .collection('programs')
                    .doc(programId)
                    .delete();

                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Program deleted')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
