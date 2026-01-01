
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Ensure these imports match your actual file names
import 'change_password.dart';
import 'login_screen.dart';

class MainFacultyDashboard extends StatefulWidget {
  final String collegeName;
  const MainFacultyDashboard({super.key, required this.collegeName});

  @override
  State<MainFacultyDashboard> createState() => _MainFacultyDashboardState();
}

class _MainFacultyDashboardState extends State<MainFacultyDashboard> {
  final Color primaryColor = const Color(0xFF1A237E);

  // --- Navigation Logic ---

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const UnifiedLoginScreen()),
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
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          body: StreamBuilder<QuerySnapshot>(
            // We fetch all clubs and filter them on the client side
            stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              // Logic: Show club if it belongs to THIS college OR has no college (Admin/Global)
              final docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final clubCollege = data['college'];
                return clubCollege == null || clubCollege == '' || clubCollege == widget.collegeName;
              }).toList();

              if (docs.isEmpty) return const Center(child: Text("No clubs available for mapping."));

              return ListView.separated(
                padding: const EdgeInsets.all(10),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final clubData = docs[index].data() as Map<String, dynamic>;
                  final clubId = docs[index].id;
                  final bool isGlobal = clubData['college'] == null || clubData['college'] == '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isGlobal ? Colors.orange[100] : Colors.blue[100],
                      child: Icon(isGlobal ? Icons.public : Icons.school,
                          color: isGlobal ? Colors.orange[900] : Colors.blue[900]),
                    ),
                    title: Text(clubData['clubName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: StreamBuilder<DocumentSnapshot>(
                      // Look up the mapping in the junction collection
                      stream: FirebaseFirestore.instance
                          .collection('club_mappings')
                          .doc("${widget.collegeName}_$clubId")
                          .snapshots(),
                      builder: (context, mapSnap) {
                        String assigned = "Not Assigned";
                        if (mapSnap.hasData && mapSnap.data!.exists) {
                          assigned = (mapSnap.data!.data() as Map<String, dynamic>)['facultyEmail'] ?? "Not Assigned";
                        }
                        return Text("Faculty: $assigned",
                            style: TextStyle(color: assigned == "Not Assigned" ? Colors.red : Colors.green));
                      },
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.assignment_ind_rounded, color: Colors.indigo),
                      onPressed: () => _assignFacultyToClub(clubId, clubData['clubName']),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _assignFacultyToClub(String clubId, String clubName) async {
    String? selectedEmail;

    // Fetch local faculty
    final facultySnap = await FirebaseFirestore.instance
        .collection('faculty')
        .where('college', isEqualTo: widget.collegeName)
        .get();

    if (facultySnap.docs.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No faculty registered in your college.")));
      return;
    }

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("Map Faculty to $clubName"),
        content: DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: "Select Faculty Member"),
          items: facultySnap.docs.map((d) => DropdownMenuItem(
            value: d['email'] as String,
            child: Text(d['name'] ?? d['email']),
          )).toList(),
          onChanged: (v) => selectedEmail = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (selectedEmail == null) return;

              // This mapping document belongs ONLY to this college
              await FirebaseFirestore.instance
                  .collection('club_mappings')
                  .doc("${widget.collegeName}_$clubId")
                  .set({
                'clubId': clubId,
                'clubName': clubName,
                'college': widget.collegeName,
                'facultyEmail': selectedEmail,
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

  // --- Add Club Logic (Local) ---

  Future<void> _addClubDialog() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add Local Club'),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Club Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                await FirebaseFirestore.instance.collection('clubs').add({
                  'clubName': nameController.text.trim(),
                  'college': widget.collegeName, // Marked as local
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(c);
              },
              child: const Text('Add')
          ),
        ],
      ),
    );
  }

  // --- Main UI Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collegeName),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout)],
      ),
      body: Container(
        color: Colors.grey[50],
        child: GridView.count(
          padding: const EdgeInsets.all(20),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildCard("Mapping Dashboard", Icons.map_rounded, _openMappingDashboard),
            _buildCard("Add Local Club", Icons.add_business_rounded, _addClubDialog),
            _buildCard("Register Faculty", Icons.person_add_rounded, () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => AddFacultyScreen(collegeName: widget.collegeName)));
            }),
            _buildCard("Security", Icons.security_rounded, () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const ChangePasswordScreen()));
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: primaryColor),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// --- Faculty Registration Screen ---

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

  Future<void> _register() async {
    try {
      // NOTE: In a production app, use a Cloud Function to create users
      // so the admin isn't logged out by FirebaseAuth.instance.createUserWithEmailAndPassword
      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );

      await FirebaseFirestore.instance.collection('faculty').doc(cred.user!.uid).set({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'college': widget.collegeName,
        'role': 'Faculty',
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Faculty")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: "Full Name")),
            TextField(controller: _email, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: _pass, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _register, child: const Text("Create Faculty Account")),
          ],
        ),
      ),
    );
  }
}
