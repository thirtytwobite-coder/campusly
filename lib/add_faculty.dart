import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'vibrant_background.dart';

// Assuming GlassCard is available globally or through main.dart imports
// Since I can't be sure, I'll use the one I've seen in other files or implement a local one if needed.
// However, the project seems to have many files with GlassCard.
import 'main.dart'; // Often contains the global GlassCard

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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  bool _isValidEmail(String email) => RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  bool _isValidPhoneNumber(String phone) => RegExp(r'^\d{10}$').hasMatch(phone);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Add ${widget.role}", style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const VibrantBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 120, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassCard(
                  borderRadius: 32,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person_add_rounded, size: 32, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Manual Registration",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(_n, "Full Name", Icons.person_outline_rounded),
                        const SizedBox(height: 16),
                        _buildTextField(_e, "Email Address", Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 16),
                        _buildTextField(_p, "Password / ID", Icons.lock_outline_rounded, obscure: true),
                        const SizedBox(height: 16),
                        _buildTextField(_ph, "Phone Number", Icons.phone_android_rounded, 
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ]),
                        const SizedBox(height: 16),
                        _buildTextField(_c, "College Name", Icons.school_outlined, enabled: widget.autoCollege == null),
                        const SizedBox(height: 32),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _handleManualSubmit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: const Text("CREATE ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ).animate().scale(delay: 200.ms),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleManualSubmit() async {
    if (_n.text.trim().isEmpty) { _showError("Full Name is required"); return; }
    if (_e.text.trim().isEmpty) { _showError("Email is required"); return; }
    if (!_isValidEmail(_e.text.trim())) { _showError("Valid email required"); return; }
    if (_p.text.isEmpty) { _showError("Password is required"); return; }
    if (_p.text.length < 6) { _showError("Password must be at least 6 characters"); return; }
    if (_c.text.trim().isEmpty) { _showError("College is required"); return; }

    setState(() => _isLoading = true);
    try {
      UserCredential u = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _e.text.trim(), password: _p.text.trim());
      await FirebaseFirestore.instance.collection('faculty').doc(u.user!.uid).set({
        'name': _n.text.trim(),
        'email': _e.text.trim(),
        'phone': _ph.text.trim(),
        'role': widget.role,
        'college': _c.text.trim(),
        'isActive': true,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, 
      {bool obscure = false, bool enabled = true, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  // Static methods kept as is but themed
  static Future<void> downloadCSVTemplate(BuildContext context) async {
    try {
      List<List<dynamic>> csvData = [["Name", "Email", "FacultyID_OR_Password", "Phone"]];
      String csvString = const ListToCsvConverter().convert(csvData);
      Directory? dir = Platform.isAndroid ? await getExternalStorageDirectory() : await getApplicationDocumentsDirectory();
      final file = File('${dir!.path}/Faculty_Template.csv');
      await file.writeAsString(csvString);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Template saved to documents"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  static Future<void> pickAndUploadCSV(BuildContext context, String college) async {
    if (college.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please specify a college first"), backgroundColor: Colors.orange));
      return;
    }
    try {
      FilePickerResult? res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
      if (res != null) {
        final file = File(res.files.single.path!);
        final input = await file.readAsString();
        List<List<dynamic>> fields = const CsvToListConverter().convert(input);
        for (var i = 1; i < fields.length; i++) {
          if (fields[i].length < 3) continue;
          UserCredential u = await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: fields[i][1].toString().trim(), password: fields[i][2].toString().trim());
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
}
