import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

class AddFacultyScreen extends StatefulWidget {
  final String role;
  final String? autoCollege;

  const AddFacultyScreen({super.key, required this.role, this.autoCollege});

  @override
  State<AddFacultyScreen> createState() => AddFacultyScreenState();
}

class AddFacultyScreenState extends State<AddFacultyScreen> {
  final _n = TextEditingController();
  final _e = TextEditingController();
  final _p = TextEditingController();
  final _ph = TextEditingController();
  final _c = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoCollege != null) {
      _c.text = widget.autoCollege!;
    }
  }

  // --- DOWNLOAD TEMPLATE LOGIC ---
  static Future<void> downloadCSVTemplate(BuildContext context) async {
    try {
      List<List<dynamic>> csvData = [
        ["Name", "Email", "FacultyID_OR_Password", "Phone"]
      ];
      String csvString = const ListToCsvConverter().convert(csvData);

      Directory? dir;
      if (Platform.isAndroid) {
        // Using getExternalStorageDirectory avoids the "Permission Denied" popup
        // while still saving to the phone's storage.
        dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final file = File('${dir!.path}/Faculty_Template.csv');
      await file.writeAsString(csvString);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Saved to: Android/data/com.example.../files"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // --- UPLOAD CSV LOGIC ---
  static Future<void> pickAndUploadCSV(BuildContext context, String college) async {
    try {
      FilePickerResult? res = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['csv']
      );

      if (res != null) {
        final file = File(res.files.single.path!);
        final input = await file.readAsString();
        List<List<dynamic>> fields = const CsvToListConverter().convert(input);

        for (var i = 1; i < fields.length; i++) {
          if (fields[i].length < 3) continue;

          UserCredential u = await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: fields[i][1].toString().trim(),
              password: fields[i][2].toString().trim()
          );

          await FirebaseFirestore.instance.collection('faculty').doc(u.user!.uid).set({
            'name': fields[i][0].toString(),
            'email': fields[i][1].toString(),
            'phone': fields[i].length > 3 ? fields[i][3].toString() : '',
            'role': 'Faculty',
            'college': college,
            'isActive': true,
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bulk Upload Success!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add ${widget.role}"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            _buildTextField(_n, "Full Name", Icons.person_outline),
            const SizedBox(height: 20),
            _buildTextField(_e, "Email", Icons.email_outlined),
            const SizedBox(height: 20),
            _buildTextField(_p, "Password / Faculty ID", Icons.lock_outline, obscure: true),
            const SizedBox(height: 20),
            _buildTextField(_ph, "Phone Number", Icons.phone_outlined),
            const SizedBox(height: 20),
            _buildTextField(_c, "College", Icons.school_outlined, enabled: widget.autoCollege == null),
            const SizedBox(height: 40),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: () async {
                // Validate all fields
                if (_n.text.trim().isEmpty) {
                  _showError("Full Name is required");
                  return;
                }

                if (_e.text.trim().isEmpty) {
                  _showError("Email is required");
                  return;
                }

                if (!_isValidEmail(_e.text.trim())) {
                  _showError("Please enter a valid email address");
                  return;
                }

                if (_p.text.isEmpty) {
                  _showError("Password is required");
                  return;
                }

                if (_p.text.length < 6) {
                  _showError("Password must be at least 6 characters");
                  return;
                }

                if (_ph.text.isNotEmpty && !_isValidPhoneNumber(_ph.text)) {
                  _showError("Please enter a valid 10-digit phone number");
                  return;
                }

                if (_c.text.trim().isEmpty) {
                  _showError("College is required");
                  return;
                }

                setState(() => _isLoading = true);
                try {
                  UserCredential u = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                      email: _e.text.trim(), password: _p.text.trim());
                  await FirebaseFirestore.instance.collection('faculty').doc(u.user!.uid).set({
                    'name': _n.text,
                    'email': _e.text,
                    'phone': _ph.text,
                    'role': widget.role,
                    'college': _c.text,
                    'isActive': true,
                  });
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                } finally {
                  setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("CREATE ACCOUNT", style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false, bool enabled = true}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
      ),
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
