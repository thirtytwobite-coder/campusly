/// This screen displays a list of colleges and their main faculty administrators.
/// It shows the status of each college admin (active/inactive) and provides an overview
/// of college-level administration in the system. The screen fetches data from the faculty collection
/// and displays it in a scrollable list with visual indicators for admin status.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'vibrant_background.dart';
import 'main.dart'; // For GlassCard

class CollegeListView extends StatelessWidget {
  const CollegeListView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("College Admin Status", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const VibrantBackground(),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('faculty').where('role', isEqualTo: 'Main Faculty').snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              if (snap.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black12),
                      const SizedBox(height: 16),
                      Text("No college admins found", style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 120, 20, 40),
                itemCount: snap.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snap.data!.docs[index];
                  bool isActive = doc.data().toString().contains('isActive') ? doc['isActive'] : true;
                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    borderRadius: 24,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      title: Text(
                        doc['name'] ?? 'N/A',
                        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                      subtitle: Text(
                        doc['college'] ?? 'N/A',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                      ),
                       trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 20),
                            onPressed: () => _showEditDialog(context, doc),
                            tooltip: "Edit College Details",
                          ),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              activeColor: theme.colorScheme.primary,
                              value: isActive,
                              onChanged: (v) => FirebaseFirestore.instance.collection('faculty').doc(doc.id).update({'isActive': v}),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nameController = TextEditingController(text: data['name'] ?? '');
    final collegeController = TextEditingController(text: data['college'] ?? '');
    final codeController = TextEditingController(text: data['collegeCode'] ?? '');
    bool isActive = data['isActive'] ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit College Details", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(nameController, "Admin Name", Icons.person_rounded),
                const SizedBox(height: 16),
                _buildDialogField(collegeController, "College Name", Icons.school_rounded),
                const SizedBox(height: 16),
                _buildDialogField(codeController, "College Code", Icons.code_rounded, 
                    formatters: [UpperCaseTextFormatter(), LengthLimitingTextInputFormatter(4)]),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text("Active Status", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('faculty').doc(doc.id).update({
                  'name': nameController.text.trim(),
                  'college': collegeController.text.trim(),
                  'collegeCode': codeController.text.trim().toUpperCase(),
                  'isActive': isActive,
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("SAVE CHANGES"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController controller, String label, IconData icon, {List<TextInputFormatter>? formatters}) {
    return TextField(
      controller: controller,
      inputFormatters: formatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
