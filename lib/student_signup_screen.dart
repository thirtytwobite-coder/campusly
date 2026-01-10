import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StudentSignUpScreen extends StatefulWidget {
  const StudentSignUpScreen({super.key});

  @override
  State<StudentSignUpScreen> createState() => _StudentSignUpScreenState();
}

class _StudentSignUpScreenState extends State<StudentSignUpScreen> {
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

    String phone = _phone.text.trim();
    if (phone.isEmpty) {
      _showError("Phone Number is required");
      return;
    }

    if (!_isValidPhoneNumber(phone)) {
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

    int? year = int.tryParse(_year.text.trim());
    if (year == null || year < 1 || year > 4) {
      _showError("Year must be between 1 and 4");
      return;
    }

    int? sem = int.tryParse(_semester.text.trim());
    if (sem == null || sem < 1 || sem > 8) {
      _showError("Semester must be between 1 and 8");
      return;
    }

    String ktuId = _ktuId.text.trim().toUpperCase();
    if (ktuId.isEmpty) {
      _showError("KTU ID is required");
      return;
    }

    if (!_isValidKtuId(ktuId)) {
      _showError("Invalid KTU ID format (Example: IDK23IT040 or LIDK23IT040)");
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
      UserCredential u = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text.trim());

      await FirebaseFirestore.instance.collection('student').doc(u.user!.uid).set({
        'name': _name.text.trim(),
        'phone': phone,
        'department': _dept.text.trim(),
        'year': _year.text.trim(),
        'semester': _semester.text.trim(),
        'ktuId': ktuId,
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
    return RegExp(r'^\d{10}$').hasMatch(phone);
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  bool _isValidKtuId(String ktuId) {
    // Optional L, then IDK, then year 22-25, then dept, then constant 0, then 2 digits 00-99
    final ktuIdRegex = RegExp(r'^L?IDK(2[2-5])(CSE|IT|ME|EC|EEE|AI)0\d{2}$');
    return ktuIdRegex.hasMatch(ktuId);
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
                keyboard: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),
            _buildCollegeDropdown(),
            _buildTextField(_dept, "Department", Icons.school),
            _buildTextField(_year, "Year (1-4)", Icons.calendar_today,
                keyboard: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)]),
            _buildTextField(_semester, "Semester (1-8)", Icons.format_list_numbered,
                keyboard: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)]),
            _buildTextField(_ktuId, "KTU ID (e.g. IDK23IT040)", Icons.badge,
                inputFormatters: [UpperCaseTextFormatter()]),
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
              .toList();

          return DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'College',
              prefixIcon: Icon(Icons.school),
            ),
            value: _selectedCollege,
            items: colleges.map((college) {
              return DropdownMenuItem<String>(
                value: college,
                child: Text(college ?? '--', overflow: TextOverflow.ellipsis),
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
      {bool obscure = false, TextInputType keyboard = TextInputType.text, Widget? suffixIcon, List<TextInputFormatter>? inputFormatters}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
