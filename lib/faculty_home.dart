import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart'; // Import main.dart to access themeNotifier
import 'login_screen.dart';
import 'change_password.dart';
import 'profile_screen.dart';
import 'program_approval_screen.dart';

class FacultyHomeScreen extends StatefulWidget {
  const FacultyHomeScreen({super.key});

  @override
  State<FacultyHomeScreen> createState() => _FacultyHomeScreenState();
}

class _FacultyHomeScreenState extends State<FacultyHomeScreen> {
  int _selectedIndex = 0;
  String? facultyCollege;
  bool _isLoadingInfo = true;

  @override
  void initState() {
    super.initState();
    _fetchFacultyInfo();
  }

  Future<void> _fetchFacultyInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('faculty').doc(user.uid).get();
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

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("FACULTY DASHBOARD"),
          actions: [
            IconButton(
              icon: const Icon(Icons.brightness_6),
              onPressed: () async {
                themeNotifier.value = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                SharedPreferences prefs = await SharedPreferences.getInstance();
                prefs.setBool('isDarkMode', themeNotifier.value == ThemeMode.dark);
              },
            ),
          ],
        ),
        body: _isLoadingInfo 
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
            final clubIds = docs.map((d) => d['clubId'] as String).toList();

            return CustomScrollView(
              slivers: [
                // --- INSTITUTION HEADER ---
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance, color: Colors.blueAccent, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            facultyCollege ?? "Institution Unknown",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: -0.1),
                ),

                if (docs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildEmptyState(),
                      ).animate().fadeIn(duration: 500.ms).slideY(),
                    ),
                  ),

                if (docs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _buildApprovalSummaryCard(clubIds),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Your Clubs', style: Theme.of(context).textTheme.titleLarge),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RejectedEventsScreen(clubIds: clubIds),
                                ),
                              );
                            },
                            icon: const Icon(Icons.history_toggle_off, color: Colors.red),
                            label: const Text('Rejected Events', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          var doc = docs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          String clubName = data.containsKey('clubName')
                              ? data['clubName']
                              : "My Club";

                          return _buildDashboardCard(
                            title: clubName,
                            icon: Icons.group_work,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ClubManagementScreen(clubMappingDoc: doc),
                                ),
                              );
                            },
                          ).animate().fadeIn(duration: 300.ms, delay: (index * 100).ms).slideX();
                        },
                        childCount: docs.length,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text('Approved Events', style: Theme.of(context).textTheme.titleLarge),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final clubId = clubIds[index];
                        return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance.collection('clubs').doc(clubId).snapshots(),
                            builder: (context, clubSnap) {
                              if (!clubSnap.hasData || !clubSnap.data!.exists) return const SizedBox.shrink();
                              final clubData = clubSnap.data!.data() as Map<String, dynamic>;
                              final clubName = clubData['clubName'] ?? clubData['name'] ?? 'Club';

                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('clubs')
                                    .doc(clubId)
                                    .collection('programs')
                                    .where('status', isEqualTo: 'approved')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Column(
                                    children: snapshot.data!.docs.map((doc) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      return Card(
                                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: ListTile(
                                          leading: const Icon(Icons.event_available, color: Colors.green),
                                          title: Text(data['name'] ?? 'Unnamed Program'),
                                          subtitle: Text('${data['date'] ?? 'N/A'} at ${data['time'] ?? 'N/A'}'),
                                          trailing: const Icon(Icons.chevron_right),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ProgramApprovalDetailScreen(
                                                  programId: doc.id,
                                                  clubId: clubId,
                                                  clubName: clubName,
                                                  data: data,
                                                  readOnly: true,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              );
                            }
                        );
                      },
                      childCount: clubIds.length,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  Widget _buildApprovalSummaryCard(List<String> clubIds) {
    return StreamBuilder<int>(
      stream: _getPendingCountStream(clubIds),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();

        return Card(
          elevation: 4,
          color: Colors.orange[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.orange, width: 1),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange,
              child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: const Text('Pending Event Approvals', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('You have $count events waiting for your review'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.orange),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MultiClubApprovalScreen(clubIds: clubIds),
                ),
              );
            },
          ),
        ).animate().shake(duration: 500.ms);
      },
    );
  }

  Stream<int> _getPendingCountStream(List<String> clubIds) {
    if (clubIds.isEmpty) return Stream.value(0);
    return Stream.fromFuture(Future.wait(
        clubIds.map((clubId) => FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('programs')
            .where('status', isEqualTo: 'pending')
            .get())
    )).map((snapshots) {
      int total = 0;
      for (var snap in snapshots) {
        total += snap.docs.length;
      }
      return total;
    });
  }

  Widget _buildDashboardCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0),
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.assignment_ind_outlined,
            size: 80, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
        const SizedBox(height: 16),
        Text(
          "No Clubs Assigned",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            "Contact your college's Main Faculty to be assigned to a club.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
          ),
        ),
      ],
    );
  }
}

class RejectedEventsScreen extends StatelessWidget {
  final List<String> clubIds;
  const RejectedEventsScreen({required this.clubIds, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rejected Events')),
      body: ListView.builder(
        itemCount: clubIds.length,
        itemBuilder: (context, index) {
          final clubId = clubIds[index];
          return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('clubs').doc(clubId).snapshots(),
              builder: (context, clubSnap) {
                if (!clubSnap.hasData || !clubSnap.data!.exists) return const SizedBox.shrink();
                final clubData = clubSnap.data!.data() as Map<String, dynamic>;
                final clubName = clubData['clubName'] ?? clubData['name'] ?? 'Club';

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(clubId)
                      .collection('programs')
                      .where('status', isEqualTo: 'rejected')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...snapshot.data!.docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: Colors.red[50],
                            child: ListTile(
                              leading: const Icon(Icons.cancel, color: Colors.red),
                              title: Text(data['name'] ?? 'Unnamed'),
                              subtitle: Text('Reason: ${data['rejectionReason'] ?? 'No reason'}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProgramApprovalDetailScreen(
                                      programId: doc.id,
                                      clubId: clubId,
                                      clubName: clubName,
                                      data: data,
                                      readOnly: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  },
                );
              }
          );
        },
      ),
    );
  }
}

class MultiClubApprovalScreen extends StatelessWidget {
  final List<String> clubIds;
  const MultiClubApprovalScreen({required this.clubIds, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: clubIds.length,
        itemBuilder: (context, index) {
          final clubId = clubIds[index];
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('clubs').doc(clubId).snapshots(),
            builder: (context, clubSnap) {
              if (!clubSnap.hasData || !clubSnap.data!.exists) return const SizedBox.shrink();
              final clubData = clubSnap.data!.data() as Map<String, dynamic>;
              final clubName = clubData['clubName'] ?? clubData['name'] ?? 'Club';

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId)
                    .collection('programs')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, programSnap) {
                  if (!programSnap.hasData || programSnap.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          clubName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A237E)),
                        ),
                      ),
                      ...programSnap.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _ApprovalListItem(
                          programId: doc.id,
                          clubId: clubId,
                          clubName: clubName,
                          data: data,
                        );
                      }).toList(),
                      const Divider(),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ApprovalListItem extends StatelessWidget {
  final String programId;
  final String clubId;
  final String clubName;
  final Map<String, dynamic> data;

  const _ApprovalListItem({
    required this.programId,
    required this.clubId,
    required this.clubName,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(data['name'] ?? 'Unnamed Program', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${data['date'] ?? 'No Date'} at ${data['time'] ?? 'No Time'}'),
            Text('Venue: ${data['location'] ?? 'No Venue'}'),
            Text('By: ${data['coordinatorName'] ?? 'Unknown'}', style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProgramApprovalDetailScreen(
                programId: programId,
                clubId: clubId,
                clubName: clubName,
                data: data,
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProgramApprovalDetailScreen extends StatelessWidget {
  final String programId;
  final String clubId;
  final String clubName;
  final Map<String, dynamic> data;
  final bool readOnly;

  const ProgramApprovalDetailScreen({
    required this.programId,
    required this.clubId,
    required this.clubName,
    required this.data,
    this.readOnly = false,
    super.key,
  });

  Future<void> _approveEvent(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('programs')
          .doc(programId)
          .update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('events').add({
        'title': data['name'],
        'description': data['description'],
        'venue': data['location'],
        'date': data['date'],
        'time': data['time'],
        'clubName': clubName,
        'clubId': clubId,
        'programId': programId,
        'category': data['category'] ?? 'Technical',
        'college': data['college'] ?? 'Unknown',
        'maxSeats': 100,
        'filledSeats': 0,
        'posterLink': data['posterLink'],
        'visibility': data['visibility'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event Approved and Published!')),
        );
      }

      // Send Notification to Club Coordinator
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('notifications')
          .add({
        'title': 'Event Approved',
        'message': 'Your event "${data['name']}" has been approved and published.',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'approval',
        'read': false,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event Approved, Published, and Notification Sent!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showRejectDialog(BuildContext context) async {
    final reasonController = TextEditingController();
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Event'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for Rejection',
            hintText: 'e.g., Venue already booked',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }
              await FirebaseFirestore.instance
                  .collection('clubs')
                  .doc(clubId)
                  .collection('programs')
                  .doc(programId)
                  .update({
                'status': 'rejected',
                'rejectionReason': reasonController.text.trim(),
                'rejectedAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Event Rejected')),
                );
              }

              // Send Notification to Club Coordinator
              await FirebaseFirestore.instance
                  .collection('clubs')
                  .doc(clubId)
                  .collection('notifications')
                  .add({
                'title': 'Event Rejected',
                'message': 'Your event "${data['name']}" was rejected. Reason: ${reasonController.text.trim()}',
                'timestamp': FieldValue.serverTimestamp(),
                'type': 'rejection',
                'read': false,
              });

              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Event Rejected and Notification Sent!')),
                );
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Program Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['posterLink'] != null && data['posterLink'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    data['posterLink'],
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            Text(data['name'] ?? 'Unnamed', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(data['description'] ?? 'No description'),
            const Divider(height: 32),
            _infoRow(Icons.calendar_today, 'Date', data['date']),
            _infoRow(Icons.schedule, 'Time', data['time']),
            _infoRow(Icons.location_on, 'Venue', data['location']),
            _infoRow(Icons.group, 'Club', clubName),
            _infoRow(Icons.person, 'Coordinator', data['coordinatorName']),
            if (data['hasPrizePool'] == true)
              _infoRow(Icons.monetization_on, 'Prize Amount', '₹ ${data['prizeAmount'] ?? 'TBD'}', color: Colors.green),
            _infoRow(
              (data['visibility'] ?? 'college') == 'public' ? Icons.public : Icons.lock,
              'Visibility',
              (data['visibility'] ?? 'college') == 'public' ? 'Public Event' : 'College Only',
              color: Colors.blue,
            ),
            if (data['status'] == 'rejected')
              _infoRow(Icons.error_outline, 'Rejection Reason', data['rejectionReason'], color: Colors.red),
            const SizedBox(height: 40),
            if (!readOnly)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showRejectDialog(context),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      child: const Text('REJECT'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approveEvent(context),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: const Text('APPROVE'),
                    ),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey),
          const SizedBox(width: 12),
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Expanded(child: Text(value ?? 'N/A', style: TextStyle(color: color))),
        ],
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
                        onChanged: (value) {
                          setDialogState(() {
                            searchQuery = value;
                          });
                        },
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
                                    }
                                  ]),
                                  'coordinatorEmails':
                                  FieldValue.arrayUnion([studentEmail])
                                });
                              }

                              if (mounted) Navigator.of(context).pop();
                            },
                          ).animate().fadeIn(duration: 500.ms).slideX();
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
      'coordinators': FieldValue.arrayRemove([coordinator])
    };

    if (studentEmail != null) {
      updateData['coordinatorEmails'] = FieldValue.arrayRemove([studentEmail]);
    }

    await FirebaseFirestore.instance.collection('clubs').doc(clubId).update(updateData);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${coordinator['studentName']} removed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clubId = widget.clubMappingDoc['clubId'];
    final clubName = widget.clubMappingDoc['clubName'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage "$clubName"'),
      ),
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
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final clubData = snapshot.data!.data() as Map<String, dynamic>?;
                final coordinators = (clubData?['coordinators'] as List<dynamic>?)
                    ?.map((e) => e as Map<String, dynamic>)
                    .toList() ??
                    [];

                if (coordinators.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text('No coordinators assigned.'),
                    ),
                  );
                }

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
                        subtitle: Text(coordinator['studentEmail'] ?? 'No email'),
                        trailing: IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              color: Theme.of(context).colorScheme.error),
                          onPressed: () => _removeCoordinator(coordinator),
                        ),
                      ),
                    ).animate().fadeIn(duration: 500.ms).slideX();
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
