import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Ensure these files exist in your project
import 'add_faculty.dart' as add_fac;
import 'college_list.dart';
import 'faculty_home.dart';
import 'change_password.dart';
import 'student_home.dart';
import 'student_signup_screen.dart';
import 'main_faculty_dashboard.dart' as main_fac;

// ===== 1. UNIFIED LOGIN SCREEN =====
class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  bool _isLoading = false;
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

      // Hardcoded Admin Check
      if (_loginEmail.text.trim() == "admin@test.com") {
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
        }
        return;
      }

      // Role-based navigation from Firestore
      var doc = await FirebaseFirestore.instance.collection('faculty').doc(u.user!.uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        if (data.containsKey('isActive') && data['isActive'] == false) {
          _showSnackBar("Account disabled. Contact Admin.");
          return;
        }

        if (mounted) {
          if (data['role'] == 'Main Faculty') {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => main_fac.MainFacultyDashboard(collegeName: data['college'])));
          } else if (data['role'] == 'Faculty') {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => const FacultyHomeScreen()));
          } else if (data['role'] == 'Student') {
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
        decoration: const BoxDecoration(color: Color.fromARGB(255, 46, 55, 155)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
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
              _buildTextField(_loginPass, "Password", Icons.lock, TextInputType.text, obscure: true),
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
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentSignUpScreen())),
                    child: const Text("Register here",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, TextInputType type, {bool obscure = false}) {
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
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

// ===== 2. ADMIN DASHBOARD =====
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final bool exit = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Are you sure you want to exit?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
                ],
              ),
            ) ??
            false;
        return exit;
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
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const UnifiedLoginScreen()));
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
            _card(context, "Add Main Faculty", Icons.person_add, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const add_fac.AddFacultyScreen(role: 'Main Faculty')))),
            _card(context, "Manage Clubs", Icons.group_work, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminClubsScreen()))),
            _card(context, "Colleges & Status", Icons.list_alt, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CollegeListView()))),
            _card(context, "Change Password", Icons.lock_reset, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ChangePasswordScreen()))),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String t, IconData i, VoidCallback o) {
    return InkWell(
      onTap: o,
      child: Card(
        elevation: 3,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(i, size: 35, color: Colors.indigo),
            const SizedBox(height: 10),
            Text(t, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ===== 3. ADMIN CLUBS SCREEN (Simplified) =====
class AdminClubsScreen extends StatefulWidget {
  const AdminClubsScreen({super.key});

  @override
  State<AdminClubsScreen> createState() => _AdminClubsScreenState();
}

class _AdminClubsScreenState extends State<AdminClubsScreen> {
  
  // Dialog to Add a Club
  Future<void> _showAddClubDialog() async {
    final clubName = TextEditingController();
    final clubDesc = TextEditingController();

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add New Club'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: clubName, decoration: const InputDecoration(labelText: 'Club Name')),
            TextField(controller: clubDesc, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = clubName.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(c);
              await FirebaseFirestore.instance.collection('clubs').add({
                'clubName': name,
                'description': clubDesc.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              });
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // Delete Function
  Future<void> _deleteClub(String docId) async {
    await FirebaseFirestore.instance.collection('clubs').doc(docId).delete();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Club removed')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Clubs'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      // Floating Plus Button at Right Bottom
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddClubDialog,
        backgroundColor: const Color(0xFF1A237E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('clubs').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data?.docs ?? [];
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

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Club"),
        content: const Text("Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No")),
          TextButton(onPressed: () { Navigator.pop(ctx); _deleteClub(id); }, child: const Text("Yes")),
        ],
      ),
    );
  }
}