import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Ensure these files exist
import 'add_faculty.dart' as add_fac;
import 'college_list.dart';
import 'faculty_home.dart';
import 'change_password.dart';
import 'student_home.dart';
import 'student_signup_screen.dart';
import 'main_faculty_dashboard.dart' as main_fac;
import 'club_coordinator_dashboard.dart';

// ==================== UNIFIED LOGIN SCREEN ====================
class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordObscured = true;

  Future<void> _login() async {
    if (_loginEmail.text.isEmpty || _loginPass.text.isEmpty) {
      _showErrorDialog("Please fill all fields");
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential u = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _loginEmail.text.trim(), password: _loginPass.text.trim());

      // --- ADMIN CHECK ---
      if (_loginEmail.text.trim() == "admin@test.com") {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
          );
        }
        return;
      }

      // --- FACULTY / STUDENT NAVIGATION ---
      var doc = await FirebaseFirestore.instance.collection('faculty').doc(u.user!.uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        if (data.containsKey('isActive') && data['isActive'] == false) {
          _showErrorDialog("Account disabled. Contact Admin.");
          return;
        }

        if (mounted) {
          switch (data['role']) {
            case 'Main Faculty':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => main_fac.MainFacultyDashboard(collegeName: data['college'])),
              );
              break;
            case 'Faculty':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const FacultyHomeScreen()),
              );
              break;
            case 'Student':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
              );
              break;
            default:
              _showErrorDialog("Invalid role assigned");
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      _showErrorDialog(e.message ?? "Login failed");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, TextInputType type,
      {bool obscure = false, Widget? suffixIcon}) {
    return Container(
      width: 360,
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.white70),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 46, 55, 155),
      body: SafeArea(
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.rocket_launch_sharp, size: 60, color: Colors.white),
                    const SizedBox(height: 15),
                    const Text("CAMPUSLY",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2)),
                    const SizedBox(height: 40),
                    _buildTextField(_loginEmail, "Email", Icons.email, TextInputType.emailAddress),
                    _buildTextField(
                      _loginPass,
                      "Password",
                      Icons.lock,
                      TextInputType.text,
                      obscure: _isPasswordObscured,
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordObscured ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                        onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("New student? ", style: TextStyle(color: Colors.white70)),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentSignUpScreen())),
                          child: const Text("Register here",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ADMIN DASHBOARD ====================
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final exit = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Exit'),
            content: const Text('Are you sure you want to exit?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
            ],
          ),
        );
        return exit ?? false;
      },
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
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()));
                  }
                })
          ],
        ),
        body: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _card(context, "Add Main Faculty", Icons.person_add,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const add_fac.AddFacultyScreen(role: 'Main Faculty')))),
            _card(context, "Manage Clubs", Icons.group_work,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminClubsScreen()))),
            _card(context, "Colleges & Status", Icons.list_alt,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CollegeListView()))),
            _card(context, "Change Password", Icons.lock_reset,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 3,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 35, color: Colors.indigo),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ==================== ADMIN CLUBS SCREEN ====================
class AdminClubsScreen extends StatefulWidget {
  const AdminClubsScreen({super.key});

  @override
  State<AdminClubsScreen> createState() => _AdminClubsScreenState();
}

class _AdminClubsScreenState extends State<AdminClubsScreen> {
  Future<void> _showAddClubDialog() async {
    final clubName = TextEditingController();
    final clubDesc = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add New Club'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: clubName, decoration: const InputDecoration(labelText: 'Club Name')),
            TextField(controller: clubDesc, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = clubName.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(context);

              await FirebaseFirestore.instance.collection('clubs').add({
                'clubName': name,
                'description': clubDesc.text.trim(),
                'createdBy': FirebaseAuth.instance.currentUser?.email ?? 'admin', // Store admin email
                'createdAt': FieldValue.serverTimestamp(),
              });
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClub(String docId) async {
    await FirebaseFirestore.instance.collection('clubs').doc(docId).delete();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Club removed')));
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Club"),
        content: const Text("Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
          TextButton(onPressed: () {
            Navigator.pop(context);
            _deleteClub(id);
          }, child: const Text("Yes")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Clubs'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddClubDialog,
        backgroundColor: const Color(0xFF1A237E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Filter clubs by current admin's email
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';
          final docs = (snapshot.data?.docs ?? [])
              .where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['createdBy'] == adminEmail;
          })
              .toList()
            ..sort((a, b) {
              final aTime = a['createdAt'] as Timestamp?;
              final bTime = b['createdAt'] as Timestamp?;
              return (bTime?.compareTo(aTime ?? Timestamp.now()) ?? 0);
            });

          if (docs.isEmpty) return const Center(child: Text("No clubs found."));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;

              return Card(
                child: ListTile(
                  title: Text(data['clubName'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['description'] ?? ""),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _confirmDelete(id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}