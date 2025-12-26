import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

class AddFacultyScreen extends StatefulWidget {
  final String role;
  final String? autoCollege;

  const AddFacultyScreen({super.key, required this.role, this.autoCollege});

  @override
  State<AddFacultyScreen> createState() => AddFacultyScreenState();
}

class AddFacultyScreenState extends State<AddFacultyScreen> {
  final _n = TextEditingController(); // Name
  final _e = TextEditingController(); // Email
  final _p = TextEditingController(); // Password
  final _c = TextEditingController(); // College
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoCollege != null) {
      _c.text = widget.autoCollege!;
    }
  }

  static Future<void> pickAndUploadCSV(BuildContext context, String college) async {
    try {
      FilePickerResult? res = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv']
      );

      if (res != null) {
        final input = File(res.files.single.path!).openRead();
        final fields = await input
            .transform(utf8.decoder)
            .transform(const CsvToListConverter())
            .toList();

        for (var i = 1; i < fields.length; i++) {
          String name = fields[i][0].toString();
          String email = fields[i][1].toString().trim();
          String password = fields[i][2].toString().trim();

          UserCredential u = await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: email,
              password: password
          );

          await FirebaseFirestore.instance.collection('faculty').doc(u.user!.uid).set({
            'name': name,
            'email': email,
            'role': 'Faculty',
            'college': college,
            'isActive': true,
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bulk Upload Success!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add ${widget.role}"),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _n, decoration: const InputDecoration(labelText: "Full Name")),
            TextField(controller: _e, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: _p, decoration: const InputDecoration(labelText: "Password / Faculty ID")),
            TextField(
                controller: _c,
                decoration: const InputDecoration(labelText: "College"),
                enabled: widget.autoCollege == null
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    try {
                      // Corrected to use the controllers defined above
                      UserCredential u = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                          email: _e.text.trim(),
                          password: _p.text.trim()
                      );
                      await FirebaseFirestore.instance.collection('faculty').doc(u.user!.uid).set({
                        'name': _n.text,
                        'email': _e.text,
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
                  child: const Text("Create Account")
              ),
            ),
          ],
        ),
      ),
    );
  }
}