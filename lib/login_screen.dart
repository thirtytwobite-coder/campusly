import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart'; // Access themeNotifier
import 'add_faculty.dart' as add_fac;
import 'college_list.dart';
import 'faculty_home.dart';
import 'change_password.dart';
import 'student_home.dart';
import 'student_signup_screen.dart';
import 'main_faculty_dashboard.dart' as main_fac;
import 'club_coordinator_dashboard.dart';
import 'role_selection_screen.dart';

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

      // --- CHECK FACULTY COLLECTION FIRST ---
      var facultyDoc = await FirebaseFirestore.instance.collection('faculty').doc(u.user!.uid).get();

      if (facultyDoc.exists) {
        final data = facultyDoc.data()!;
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
            default:
              _showErrorDialog("Invalid role assigned");
          }
        }
      } else {
        // --- CHECK STUDENT COLLECTION ---
        var studentDoc = await FirebaseFirestore.instance.collection('student').doc(u.user!.uid).get();
        if (studentDoc.exists) {
          await _handleStudentLogin(studentDoc);
        } else {
          _showErrorDialog("No user record found. Please register.");
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Login failed";
      if (e.code == 'user-not-found') {
        errorMessage = "No user found with this email.";
      } else if (e.code == 'wrong-password') {
        errorMessage = "Incorrect password.";
      } else if (e.code == 'invalid-credential') {
        errorMessage = "Incorrect password."; // Also show for invalid credentials to satisfy the requirement
      } else if (e.code == 'invalid-email') {
        errorMessage = "The email address is badly formatted.";
      } else if (e.code == 'user-disabled') {
        errorMessage = "This user account has been disabled.";
      }
      _showErrorDialog(errorMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStudentLogin(DocumentSnapshot studentDoc) async {
    final studentData = studentDoc.data() as Map<String, dynamic>;

    if (studentData.containsKey('isActive') && studentData['isActive'] == false) {
      _showErrorDialog("Account disabled. Contact Admin.");
      return;
    }

    // Check if this student is a coordinator for any club
    final coordinatorQuery = await FirebaseFirestore.instance
        .collection('clubs')
        .where('coordinators', arrayContains: {
      'studentId': studentDoc.id,
      'studentName': studentData['name'],
      'studentEmail': studentData['email'],
    })
        .limit(1)
        .get();

    if (mounted) {
      if (coordinatorQuery.docs.isNotEmpty) {
        // FIXED: Removed 'const' because RoleSelectionScreen might not have a const constructor
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RoleSelectionScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
        );
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_loginEmail.text.isEmpty) {
      _showErrorDialog("Please enter your email to reset the password.");
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _loginEmail.text.trim());
      _showErrorDialog("Password reset email sent. Please check your inbox.");
    } catch (e) {
      _showErrorDialog("Error: ${e.toString()}");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.rocket_launch_sharp, size: 80, color: Theme.of(context).primaryColor),
                const SizedBox(height: 15),
                Text("CAMPUSLY",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    )),
                const SizedBox(height: 40),
                TextField(
                  controller: _loginEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _loginPass,
                  obscureText: _isPasswordObscured,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordObscured ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: _handleForgotPassword, child: const Text("Forgot Password?")),
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: const Text("LOGIN", style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("New student? "),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentSignUpScreen())),
                      child: Text("Register here",
                          style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ],
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),
          ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () async {
              themeNotifier.value = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
              SharedPreferences prefs = await SharedPreferences.getInstance();
              prefs.setBool('isDarkMode', themeNotifier.value == ThemeMode.dark);
            },
          ),
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
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangePasswordScreen()))),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).primaryColor),
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
            TextField(controller: clubDesc, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (clubName.text.isEmpty) return;
              await FirebaseFirestore.instance.collection('clubs').add({
                'clubName': clubName.text.trim(),
                'description': clubDesc.text.trim(),
                'createdBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Clubs')),
      floatingActionButton: FloatingActionButton(onPressed: _showAddClubDialog, child: const Icon(Icons.add)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text(data['clubName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['description'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => FirebaseFirestore.instance.collection('clubs').doc(docs[index].id).delete(),
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