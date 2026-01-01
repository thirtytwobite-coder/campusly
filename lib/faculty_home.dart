import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class FacultyHomeScreen extends StatefulWidget {
  const FacultyHomeScreen({super.key});

  @override
  State<FacultyHomeScreen> createState() => _FacultyHomeScreenState();
}

class _FacultyHomeScreenState extends State<FacultyHomeScreen> {
  Future<bool> _onWillPop() async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Exit'),
              content: const Text('Are you sure you want to exit?'),
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
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("FACULTY DASHBOARD"),
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => const UnifiedLoginScreen()),
                    (route) => false,
                  );
                }
              },
            )
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          // Correctly fetch clubs from the 'club_mappings' collection
          stream: FirebaseFirestore.instance
              .collection('club_mappings')
              .where('facultyEmail', isEqualTo: user?.email)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                var data = doc.data() as Map<String, dynamic>;

                String clubName =
                    data.containsKey('clubName') ? data['clubName'] : "My Club";

                return _dashboardCard(
                    context, clubName, Icons.group_work, Colors.indigo, doc);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _dashboardCard(BuildContext context, String title, IconData icon,
      Color color, DocumentSnapshot doc) {
    return InkWell(
      onTap: () {
        // Navigate to the new ClubManagementScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClubManagementScreen(clubMappingDoc: doc),
          ),
        );
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_ind_outlined,
              size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "No Clubs Assigned",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              "Contact your college's Main Faculty to be assigned to a club.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== CLUB MANAGEMENT SCREEN ====================
class ClubManagementScreen extends StatefulWidget {
  final DocumentSnapshot clubMappingDoc;

  const ClubManagementScreen({super.key, required this.clubMappingDoc});

  @override
  State<ClubManagementScreen> createState() => _ClubManagementScreenState();
}

class _ClubManagementScreenState extends State<ClubManagementScreen> {
  // Function to show a dialog to ADD a student coordinator
  Future<void> _showAddCoordinatorDialog() async {
    final collegeName = widget.clubMappingDoc['college'];
    List<DocumentSnapshot> students = [];
    String searchQuery = "";

    // Fetch all students from the same college
    final studentSnap = await FirebaseFirestore.instance
        .collection('faculty')
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
                              await FirebaseFirestore.instance
                                  .collection('clubs')
                                  .doc(clubId)
                                  .update({
                                'coordinators': FieldValue.arrayUnion([
                                  {
                                    'studentId': student.id,
                                    'studentName': student['name'],
                                    'studentEmail': student['email'],
                                  }
                                ])
                              });
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

  // Function to remove a coordinator
  Future<void> _removeCoordinator(Map<String, dynamic> coordinator) async {
    final clubId = widget.clubMappingDoc['clubId'];
    await FirebaseFirestore.instance.collection('clubs').doc(clubId).update({
      'coordinators': FieldValue.arrayRemove([coordinator])
    });
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
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCoordinatorDialog,
        tooltip: 'Add Coordinator',
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: StreamBuilder<DocumentSnapshot>(
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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Club Coordinators',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                if (coordinators.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                          'No coordinators assigned. Use the + button to add one.'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: coordinators.length,
                      itemBuilder: (context, index) {
                        final coordinator = coordinators[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                          child: ListTile(
                            leading: const Icon(Icons.person, color: Colors.indigo),
                            title: Text(coordinator['studentName'] ?? 'Unnamed'),
                            subtitle:
                                Text(coordinator['studentEmail'] ?? 'No email'),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red),
                              onPressed: () => _removeCoordinator(coordinator),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
