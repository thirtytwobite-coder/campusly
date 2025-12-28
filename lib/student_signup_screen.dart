import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentSignUpScreen extends StatefulWidget {
  const StudentSignUpScreen({super.key});

  @override
  State<StudentSignUpScreen> createState() => _StudentSignUpScreenState();
}

class _StudentSignUpScreenState extends State<StudentSignUpScreen> {
  // Added missing controllers for Year and Semester
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _dept = TextEditingController();
  final _year = TextEditingController();
  final _semester = TextEditingController();
  final _ktuId = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _isLoading = false;

  Future<void> registerStudent() async {
    // Basic validation
    if (_email.text.isEmpty || _pass.text.isEmpty || _ktuId.text.isEmpty || _name.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All fields are required!"))
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Create user in Firebase Authentication
      UserCredential u = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _pass.text.trim()
      );

      // 2. Save details in 'faculty' collection (as per your login logic)
      await FirebaseFirestore.instance.collection('faculty').doc(u.user!.uid).set({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'department': _dept.text.trim(),
        'year': _year.text.trim(),
        'semester': _semester.text.trim(),
        'ktuId': _ktuId.text.trim().toUpperCase(),
        'email': _email.text.trim(),
        'role': 'Student',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account Created! Please Login."))
        );
        Navigator.pop(context); // Go back to login
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()))
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Student Registration"),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTextField(_name, "Full Name", Icons.person),
            _buildTextField(_phone, "Phone Number", Icons.phone, keyboard: TextInputType.phone),
            _buildTextField(_dept, "Department", Icons.school),
            _buildTextField(_year, "Year", Icons.calendar_today),
            _buildTextField(_semester, "Semester", Icons.format_list_numbered),
            _buildTextField(_ktuId, "KTU ID", Icons.badge),
            _buildTextField(_email, "Email", Icons.email, keyboard: TextInputType.emailAddress),
            _buildTextField(_pass, "Password", Icons.lock, obscure: true),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: registerStudent,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                child: const Text("CREATE ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      {bool obscure = false, TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.indigo),
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.indigo, width: 2)),
        ),
      ),
    );
  }
}