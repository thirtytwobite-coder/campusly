import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_faculty.dart';
import 'college_list.dart';
import 'faculty_home.dart';
import 'manage_clubs.dart';
import 'change_password.dart';

class RoleSelectionScreen extends StatelessWidget {
  RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Changed background to white
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        // Removed the LinearGradient decoration
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Changed icon color to indigo for visibility on white
            const Icon(Icons.rocket_launch_sharp, size: 80, color: Color(0xFF1A237E)),
            const SizedBox(height: 10),
            // Changed text color to indigo
            const Text(
              "CAMPUSLY",
              style: TextStyle(
                color: Color(0xFF1A237E),
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 50),
            _roleButton(context, "Admin", Icons.supervised_user_circle, true),
            const SizedBox(height: 20),
            _roleButton(context, "Faculty/Student", Icons.school, false),
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
        icon: Icon(icon, color: Colors.white), // White icon on blue button
        label: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          // Inverted colors: Blue background with white text for better contrast on white screen
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 4, // Added slight shadow for depth
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AdminLoginScreen(isFacultyRole: isFaculty)),
        ),
      ),
    );
  }
}
class AdminLoginScreen extends StatefulWidget{
  final bool isFacultyRole;
  const AdminLoginScreen({super.key, required this.isFacultyRole});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}
class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _email = TextEditingController(), _pass = TextEditingController();
  bool _isLoading = false;
  Future login() async {
    setState(() => _isLoading = true);
    try {
      UserCredential u = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text.trim());

      if (_email.text.trim() == "admin@test.com") {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
        return;
      }
      var doc = await FirebaseFirestore.instance.collection('faculty').doc(u.user!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data['role'] == 'Main Faculty') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainFacultyDashboard(collegeName: data['college'])));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const FacultyHomeScreen()));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: Container(
        padding: const EdgeInsets.all(30),
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)], begin: Alignment.topCenter)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.isFacultyRole ? "FACULTY LOGIN" : "STUDENT LOGIN", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            TextField(controller: _email, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Email", labelStyle: TextStyle(color: Colors.white70))),
            TextField(controller: _pass, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Password", labelStyle: TextStyle(color: Colors.white70))),
            const SizedBox(height: 40),
            _isLoading ? const CircularProgressIndicator(color: Colors.white) : SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: login, child: const Text("LOGIN"))),
          ],
        ),
      ),
    );
  }
}
// ADMIN SECTION - KEPT PERFECT AS REQUESTED
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dasboard"),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
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
              context, MaterialPageRoute(builder: (c) => ManageClubsScreen(isGuest: false)))),

          _card(context, "Colleges & Status", Icons.list_alt, () => Navigator.push(
              context, MaterialPageRoute(builder: (c) => const CollegeListView()))),

          _card(context, "Change Password", Icons.lock_reset, () => Navigator.push(
              context, MaterialPageRoute(builder: (c) => const ChangePasswordScreen()))),

          _card(context, "Logout", Icons.power_settings_new, () async {
            await FirebaseAuth.instance.signOut();
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (c) => RoleSelectionScreen())
            );
          }),
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
// MAIN FACULTY SECTION - CLEANED UP
class MainFacultyDashboard extends StatelessWidget {
  final String collegeName;
  const MainFacultyDashboard({super.key, required this.collegeName});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(collegeName),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: [
          _card(context, "Add Club Faculty", Icons.person_add_alt_1, () => Navigator.push(
              context, MaterialPageRoute(builder: (c) => AddFacultyScreen(role: 'Faculty', autoCollege: collegeName)))),
          _card(context, "Assign via CSV", Icons.upload_file, () => _showCSVInstructions(context)),
          _card(context, "Change Password", Icons.security, () => Navigator.push(
              context, MaterialPageRoute(builder: (c) => const ChangePasswordScreen()))),
          _card(context, "Logout", Icons.power_settings_new, () async {
            await FirebaseAuth.instance.signOut();
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (c) => RoleSelectionScreen())
            );
          }),
        ],
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
          // NEW: Download Template Button
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
                AddFacultyScreenState.pickAndUploadCSV(context, collegeName);
              },
              child: const Text("Upload File")
          ),
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