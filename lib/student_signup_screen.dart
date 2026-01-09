import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
  String? _selectedCollege;

  bool _isLoading = false;
  bool _isPasswordObscured = true;

  Future<void> registerStudent() async {
    // Validate all fields
    if (_name.text.trim().isEmpty) {
      _showError("Full Name is required");
      return;
    }

    if (_phone.text.trim().isEmpty) {
      _showError("Phone Number is required");
      return;
    }

    if (!_isValidPhoneNumber(_phone.text)) {
      _showError("Please enter a valid 10-digit phone number");
      return;
    }

    if (_selectedCollege == null || _selectedCollege!.isEmpty) {
      _showError("Please select a college");
      return;
    }

    if (_dept.text.trim().isEmpty) {
      _showError("Department is required");
      return;
    }

    if (_year.text.trim().isEmpty) {
      _showError("Year is required");
      return;
    }

    if (_semester.text.trim().isEmpty) {
      _showError("Semester is required");
      return;
    }

    if (_ktuId.text.trim().isEmpty) {
      _showError("KTU ID is required");
      return;
    }

    if (_email.text.trim().isEmpty) {
      _showError("Email is required");
      return;
    }

    if (!_isValidEmail(_email.text.trim())) {
      _showError("Please enter a valid email address");
      return;
    }

    if (_pass.text.isEmpty) {
      _showError("Password is required");
      return;
    }

    if (_pass.text.length < 6) {
      _showError("Password must be at least 6 characters");
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Create user in Firebase Authentication
      UserCredential u = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text.trim());

      // 2. Save details in 'faculty' collection (as per your login logic)
      await FirebaseFirestore.instance.collection('student').doc(u.user!.uid).set({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'department': _dept.text.trim(),
        'year': _year.text.trim(),
        'semester': _semester.text.trim(),
        'ktuId': _ktuId.text.trim().toUpperCase(),
        'email': _email.text.trim(),
        'college': _selectedCollege,
        'role': 'Student',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account Created! Please Login.")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  bool _isValidPhoneNumber(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length == 10;
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Registration"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTextField(_name, "Full Name", Icons.person),
            _buildTextField(_phone, "Phone Number", Icons.phone,
                keyboard: TextInputType.phone),
            _buildCollegeDropdown(), // Add college dropdown
            _buildTextField(_dept, "Department", Icons.school),
            _buildTextField(_year, "Year", Icons.calendar_today),
            _buildTextField(_semester, "Semester", Icons.format_list_numbered),
            _buildTextField(_ktuId, "KTU ID", Icons.badge),
            _buildTextField(_email, "Email", Icons.email,
                keyboard: TextInputType.emailAddress),
            _buildTextField(_pass, "Password", Icons.lock,
                obscure: _isPasswordObscured,
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordObscured
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _isPasswordObscured = !_isPasswordObscured;
                    });
                  },
                )),
            const SizedBox(height: 30),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: registerStudent,
                      child: const Text("CREATE ACCOUNT"),
                    ),
                  ),
          ],
        ).animate().slideY(duration: 300.ms, delay: 200.ms).fadeIn(),
      ),
    );
  }

  Widget _buildCollegeDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('faculty')
            .where('role', isEqualTo: 'Main Faculty')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return TextField(
              decoration: InputDecoration(
                labelText: 'No colleges available',
                prefixIcon: Icon(Icons.school, color: Theme.of(context).disabledColor),
              ),
              enabled: false,
            );
          }

          final colleges = snapshot.data!.docs
              .map((doc) => doc['college'] as String?)
              .where((college) => college != null)
              .toSet()
              .toList(); // Use a Set to get unique college names

          return DropdownButtonFormField<String>(
            isExpanded: true, // Allow the dropdown to expand
            decoration: const InputDecoration(
              labelText: 'College',
              prefixIcon: Icon(Icons.school),
            ),
            value: _selectedCollege,
            items: colleges.map((college) {
              return DropdownMenuItem<String>(
                value: college,
                child: Text(college ?? '--', overflow: TextOverflow.ellipsis), // Handle overflow
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCollege = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a college';
              }
              return null;
            },
          );
        },
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      {bool obscure = false, TextInputType keyboard = TextInputType.text, Widget? suffixIcon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
