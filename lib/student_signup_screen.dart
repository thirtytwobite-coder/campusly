import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentSignUpScreen extends StatefulWidget {
  const StudentSignUpScreen({super.key});

  @override
  State<StudentSignUpScreen> createState() => _StudentSignUpScreenState();
}

class _StudentSignUpScreenState extends State<StudentSignUpScreen> {
  // Controllers for the details you requested
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _dept = TextEditingController();
  final _batch = TextEditingController();
  final _ktuId = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _isLoading = false;

  Future<void> registerStudent() async {
    // Basic validation
    if (_email.text.isEmpty || _pass.text.isEmpty || _ktuId.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Name, Email, and KTU ID are required!"))
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Create user in Firebase Authentication
      UserCredential u = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text.trim());

      // 2. Save all the student details in Firestore
      // We use the 'faculty' collection because your login screen is already looking there
      await FirebaseFirestore.instance.collection('faculty').doc(u.user!.uid).set({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'department': _dept.text.trim(),
        'batch': _batch.text.trim(),
        'ktuId': _ktuId.text.trim().toUpperCase(),
        'email': _email.text.trim(),
        'role': 'Student', // Critical for your login logic
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account Created! Please Login.")));
      Navigator.pop(context); // Go back to login screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student Registration"), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTextField(_name, "Full Name", Icons.person),
            _buildTextField(_phone, "Phone Number", Icons.phone, keyboard: TextInputType.phone),
            _buildTextField(_dept, "Department (e.g. CSE)", Icons.school),
            _buildTextField(_batch, "Batch (e.g. 2021-25)", Icons.calendar_month),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                child: const Text("CREATE ACCOUNT"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false, TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}