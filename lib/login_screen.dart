import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_faculty.dart';
import 'college_list.dart';
import 'faculty_home.dart';
import 'manage_clubs.dart';
import 'change_password.dart';
import 'student_home.dart';
import 'student_signup_screen.dart'; // Make sure this file exists

// ===== UNIFIED LOGIN SCREEN (Login + Registration) =====
class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  bool _isLoading = false;

  // Login controllers
  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();

  Future<void> _login() async {
    if (_loginEmail.text.isEmpty || _loginPass.text.isEmpty) {
      _showSnackBar("Please fill all fields");
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserCredential u = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _loginEmail.text.trim(), password: _loginPass.text.trim());

      if (_loginEmail.text.trim() == "admin@test.com") {
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
        }
        return;
      }

      var doc = await FirebaseFirestore.instance.collection('faculty').doc(u.user!.uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        if (data.containsKey('isActive') && data['isActive'] == false) {
          _showSnackBar("Account disabled. Contact Admin.");
          return;
        }

        if (data['role'] == 'Main Faculty') {
          if (mounted) {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        MainFacultyDashboard(collegeName: data['college'])));
          }
        } else if (data['role'] == 'Faculty') {
          if (mounted) {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => const FacultyHomeScreen()));
          }
        } else if (data['role'] == 'Student') {
          if (mounted) {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => const StudentHomeScreen()));
          }
        }
      }
    } catch (e) {
      _showSnackBar((e as FirebaseAuthException).message ?? "Login failed");

    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
            color: Color.fromARGB(255, 46, 55, 155)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 80),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo/Title
                  const Icon(Icons.rocket_launch_sharp, size: 60, color: Colors.white),
                  const SizedBox(height: 15),
                  const Text(
                    "CAMPUSLY",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2),
                  ),
                  const SizedBox(height: 40),

                  // LOGIN FORM (constrained width to keep centered)
                  SizedBox(width: 360, child: _buildTextField(_loginEmail, "Email", Icons.email, TextInputType.emailAddress)),
                  SizedBox(width: 360, child: _buildTextField(_loginPass, "Password", Icons.lock, TextInputType.text, obscure: true)),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator(color: Color.fromARGB(255, 250, 252, 245))
                      : SizedBox(
                    width: 360,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("LOGIN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Registration Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "If you are a new student, ",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const StudentSignUpScreen()),
                        ),
                        child: const Text(
                          "register here",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      TextInputType keyboardType, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white30),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity ,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color.fromARGB(255, 10, 10, 196), Color.fromARGB(255, 52, 57, 131)],
            begin: Alignment.topCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rocket_launch_sharp, size: 80, color: Colors.white),
            const SizedBox(height: 10),
            const Text("CAMPUSLY",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
            const SizedBox(height: 50),
            _roleButton(context, "Admin/Faculty", Icons.supervised_user_circle, true),
            const SizedBox(height: 20),
            _roleButton(context, "Student", Icons.school, false),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _roleButton(BuildContext context, String title, IconData icon, bool isFaculty) {
    return SizedBox(
      width: 250,
      height: 60,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.indigo),
        label: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.indigo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => AdminLoginScreen(isFacultyRole: isFaculty))),
      ),
    );
  }
}

class AdminLoginScreen extends StatefulWidget {
  final bool isFacultyRole;
  const AdminLoginScreen({super.key, required this.isFacultyRole});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _isLoading = false;

  Future<void> login() async {
    setState(() => _isLoading = true);
    try {
      UserCredential u = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text.trim());

      if (_email.text.trim() == "admin@test.com") {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
        return;
      }

      var doc = await FirebaseFirestore.instance.collection('faculty').doc(u.user!.uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        if (data.containsKey('isActive') && data['isActive'] == false) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Account disabled. Contact Admin.")));
          return;
        }

        if (data['role'] == 'Main Faculty') {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      MainFacultyDashboard(collegeName: data['college'])));
        } else if (data['role'] == 'Faculty') {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const FacultyHomeScreen()));
        } else if (data['role'] == 'Student') {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const StudentHomeScreen()));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white)),
      body: Container(
        padding: const EdgeInsets.all(30),
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                begin: Alignment.topCenter)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.isFacultyRole ? "LOGIN" : "STUDENT LOGIN",
                style: const TextStyle(
                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            TextField(
                controller: _email,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: "Email", labelStyle: TextStyle(color: Colors.white70))),
            TextField(
                controller: _pass,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: "Password", labelStyle: TextStyle(color: Colors.white70))),
            const SizedBox(height: 40),
            _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(onPressed: login, child: const Text("LOGIN"))),

            if (!widget.isFacultyRole) ...[
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const StudentSignUpScreen())),
                child: const Text("Don't have an account? Register Here",
                    style: TextStyle(color: Colors.white, decoration: TextDecoration.underline)),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Replace with your real admin UID from Firebase Auth (or fetch dynamically)
  final String adminUid = "ADMIN_FIREBASE_UID";
  Future<bool> _onWillPop() async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit Dashboard?'),
          content: const Text('Are you sure you want to exit the dashboard?'),
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
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Dashboard"),
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (c) => const UnifiedLoginScreen())
                  );
                }
              },
            )
          ],
        ),
        body: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _card(context, "Add Main Faculty", Icons.person_add, () => Navigator.push(
                context, MaterialPageRoute(builder: (c) => const AddFacultyScreen(role: 'Main Faculty')))),
            _card(context, "Create Club", Icons.add_circle_outline, () => Navigator.push(
                context, MaterialPageRoute(builder: (c) => ManageClubsScreen(isGuest: false, college: 'Default College')))),
            _card(context, "Colleges & Status", Icons.list_alt, () => Navigator.push(
                context, MaterialPageRoute(builder: (c) => const CollegeListView()))),
            _card(context, "Change Password", Icons.lock_reset, () => Navigator.push(
                context, MaterialPageRoute(builder: (c) => const ChangePasswordScreen()))),

          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String t, IconData i, VoidCallback o) => InkWell(
      onTap: o,
      child: Card(
          elevation: 3,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(i, size: 35, color: Colors.indigo),
                const SizedBox(height: 10),
                Text(t, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))
              ]
          )
      )
  );
}

 
class MainFacultyDashboard extends StatefulWidget {
  final String collegeName;
  const MainFacultyDashboard({super.key, required this.collegeName});

  @override
  State<MainFacultyDashboard> createState() => _MainFacultyDashboardState();
}

class _MainFacultyDashboardState extends State<MainFacultyDashboard> {
  Future<bool> _onWillPop() async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit Dashboard?'),
          content: const Text('Are you sure you want to exit the dashboard?'),
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
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.collegeName),
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (c) => const UnifiedLoginScreen())
                  );
                }
              },
            )
          ],
        ),
        body: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _card(context, "Add Club", Icons.add_box, () => _addClubDialog()),
            _card(context, "Add Main Faculty", Icons.person_add, () => Navigator.push(
              context, MaterialPageRoute(builder: (c) => const AddFacultyScreen(role: 'Main Faculty')))),
            _card(context, "View Clubs", Icons.list, () => _openClubList()),
            _card(context, "Assign Faculty", Icons.group_add, () => _assignFacultyDialog()),
            _card(context, "Assign via CSV", Icons.upload_file, () => _showCSVInstructions(context)),
            _card(context, "Change Password", Icons.security, () => Navigator.push(
                context, MaterialPageRoute(builder: (c) => const ChangePasswordScreen()))),
          ],
        ),
      ),
    );
  }

  void _showCSVInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("CSV Bulk Upload"),
        content: const Text("Format: Name, Email, Password/ID\n\nDownload the template if you don't have one."),
        actions: [
          TextButton.icon(
            onPressed: () => AddFacultyScreenState.downloadCSVTemplate(context),
            icon: const Icon(Icons.download),
            label: const Text("Template"),
          ),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(c);
                AddFacultyScreenState.pickAndUploadCSV(context, widget.collegeName);
              },
              child: const Text("Upload File")
          ),
        ],
      ),
    );
  }

  Future<void> _addClubDialog() async {
    final _clubName = TextEditingController();
    final _clubDesc = TextEditingController();

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add Club'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _clubName, decoration: const InputDecoration(labelText: 'Club Name')),
            TextField(controller: _clubDesc, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = _clubName.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(c);
              final clubData = {
                'clubName': name,
                'description': _clubDesc.text.trim(),
                'college': widget.collegeName,
                'createdBy': FirebaseAuth.instance.currentUser?.uid,
                'facultyEmail': '',
                'createdAt': FieldValue.serverTimestamp(),
              };
              await FirebaseFirestore.instance.collection('clubs').add(clubData);
              print('===== DEBUG: Club Created =====');
              print('Club Name: $name');
              print('College: ${widget.collegeName}');
              print('Description: ${_clubDesc.text.trim()}');
              print('================================');
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Club added')));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignFacultyDialog() async {
    String? selectedClubId;
    String? selectedFacultyEmail;

    // fetch clubs and faculties
    final clubsSnap = await FirebaseFirestore.instance.collection('clubs').where('college', isEqualTo: widget.collegeName).get();
    final facultiesSnap = await FirebaseFirestore.instance.collection('faculty').where('role', isEqualTo: 'Faculty').where('college', isEqualTo: widget.collegeName).get();

    final clubs = clubsSnap.docs;
    final faculties = facultiesSnap.docs;

    // Debug logging
    print('===== DEBUG: Club & Faculty Retrieval =====');
    print('College Filter: ${widget.collegeName}');
    print('Clubs Found: ${clubs.length}');
    for (var club in clubs) {
      print('  - Club: ${club['clubName']} (ID: ${club.id}, College: ${club['college']})');
    }
    print('Faculty Found: ${faculties.length}');
    for (var faculty in faculties) {
      print('  - Faculty: ${faculty['name']} (Email: ${faculty['email']}, Role: ${faculty['role']})');
    }
    print('========================================');

    if (clubs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No clubs found. Please add a club first.')));
      return;
    }
    if (faculties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No faculty found. Please add faculty first.')));
      return;
    }

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Assign Faculty to Club'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Select Club'),
              items: clubs.map((d) => DropdownMenuItem(value: d.id, child: Text(d['clubName'] ?? ''))).toList(),
              onChanged: (v) => selectedClubId = v,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Select Faculty'),
              items: faculties
                  .map((d) => DropdownMenuItem<String>(
                        value: (d['email'] ?? '') as String,
                        child: Text((d['name'] ?? d['email'] ?? '') as String),
                      ))
                  .toList(),
              onChanged: (v) => selectedFacultyEmail = v,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (selectedClubId == null || selectedFacultyEmail == null) return;
              Navigator.pop(c);
              await FirebaseFirestore.instance.collection('clubs').doc(selectedClubId).update({
                'facultyEmail': selectedFacultyEmail,
                'assignedAt': FieldValue.serverTimestamp(),
              });
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Faculty assigned to club')));
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  void _openClubList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => Scaffold(
          appBar: AppBar(title: const Text('Clubs'), backgroundColor: const Color(0xFF1A237E)),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('clubs').where('college', isEqualTo: widget.collegeName).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data?.docs ?? [];
              
              // Debug logging
              if (docs.isNotEmpty) {
                print('===== DEBUG: Club List =====');
                print('Total Clubs: ${docs.length}');
                for (var doc in docs) {
                  print('  - ${doc['clubName']} | Faculty: ${doc['facultyEmail'] ?? 'Unassigned'} | College: ${doc['college']}');
                }
                print('============================');
              }
              
              if (docs.isEmpty) return const Center(child: Text('No clubs found'));
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final d = docs[index];
                  final facultyEmail = (d['facultyEmail'] ?? '').toString();
                  return ListTile(
                    title: Text(d['clubName'] ?? 'Unnamed Club'),
                    subtitle: Text(d['description'] ?? ''),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (facultyEmail.isNotEmpty) Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(facultyEmail, style: const TextStyle(fontSize: 12)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _assignFacultyToClub(d.id),
                      )
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _assignFacultyToClub(String clubId) async {
    String? selectedFacultyEmail;
    final facultiesSnap = await FirebaseFirestore.instance.collection('faculty').where('role', isEqualTo: 'Faculty').where('college', isEqualTo: widget.collegeName).get();
    final faculties = facultiesSnap.docs;

    if (faculties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No faculty found')));
      return;
    }

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Assign Faculty'),
        content: DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Select Faculty'),
          items: faculties
              .map((d) => DropdownMenuItem<String>(value: (d['email'] ?? '') as String, child: Text((d['name'] ?? d['email'] ?? '') as String)))
              .toList(),
          onChanged: (v) => selectedFacultyEmail = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            if (selectedFacultyEmail == null) return;
            Navigator.pop(c);
            await FirebaseFirestore.instance.collection('clubs').doc(clubId).update({
              'facultyEmail': selectedFacultyEmail,
              'assignedAt': FieldValue.serverTimestamp(),
            });
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Faculty assigned')));
          }, child: const Text('Assign'))
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String t, IconData i, VoidCallback o) => InkWell(
      onTap: o,
      child: Card(
          elevation: 3,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(i, size: 35, color: Colors.indigo),
                const SizedBox(height: 10),
                Text(t, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))
              ]
          )
      )
  );
}