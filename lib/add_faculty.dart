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
        ["Name", "Email", "FacultyID_OR_Password"]
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
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
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
                      if(_e.text.isEmpty || _p.text.isEmpty) return;
                      setState(() => _isLoading = true);
                      try {
                        UserCredential u = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                            email: _e.text.trim(), password: _p.text.trim());
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
      ),
    );
  }
}