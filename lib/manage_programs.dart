import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ManageProgramsScreen extends StatefulWidget {
  final String clubId;
  final String clubName;

  const ManageProgramsScreen({
    required this.clubId,
    required this.clubName,
    super.key,
  });

  @override
  State<ManageProgramsScreen> createState() => _ManageProgramsScreenState();
}

class _ManageProgramsScreenState extends State<ManageProgramsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.clubName} - Programs'),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .doc(widget.clubId)
            .collection('programs')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_note, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No programs created yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddProgramDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Program'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final programDoc = snapshot.data!.docs[index];
              final programData = programDoc.data() as Map<String, dynamic>;

              return ProgramCard(
                programId: programDoc.id,
                clubId: widget.clubId,
                programData: programData,
                onEdit: () => _showEditProgramDialog(context, programDoc.id, programData),
                onDelete: () => _confirmDelete(context, programDoc.id),
                onStatusChange: (newStatus) =>
                    _requestStatusChange(programDoc.id, newStatus),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProgramDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddProgramDialog(BuildContext context) {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Program'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Program Name')),
                TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category')),
                ListTile(
                  title: Text(selectedDate == null ? 'Select Date' : DateFormat('yyyy-MM-dd').format(selectedDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && categoryController.text.isNotEmpty && selectedDate != null) {
                  _addProgram(nameController.text, categoryController.text, DateFormat('yyyy-MM-dd').format(selectedDate!));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProgramDialog(BuildContext context, String programId, Map<String, dynamic> programData) {
    final nameController = TextEditingController(text: programData['name']);
    final categoryController = TextEditingController(text: programData['category']);
    DateTime? selectedDate;
    if (programData['date'] != null) {
      try { selectedDate = DateFormat('yyyy-MM-dd').parse(programData['date']); } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Program'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Program Name')),
                TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category')),
                ListTile(
                  title: Text(selectedDate == null ? 'Select Date' : DateFormat('yyyy-MM-dd').format(selectedDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && categoryController.text.isNotEmpty && selectedDate != null) {
                  _updateProgram(programId, nameController.text, categoryController.text, DateFormat('yyyy-MM-dd').format(selectedDate!));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addProgram(String name, String category, String date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final programRef = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('programs')
        .add({
      'name': name,
      'category': category,
      'date': date,
      'status': 'pending',
      'coordinatorId': user.uid,
      'clubId': widget.clubId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('events').add({
      'title': name,
      'clubId': widget.clubId,
      'programId': programRef.id,
      'status': 'pending',
      'visibility': 'college',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateProgram(String programId, String name, String category, String date) async {
    await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('programs')
        .doc(programId)
        .update({
      'name': name,
      'category': category,
      'date': date,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final events = await FirebaseFirestore.instance
        .collection('events')
        .where('programId', isEqualTo: programId)
        .get();
    
    for (var doc in events.docs) {
      await doc.reference.update({
        'title': name,
      });
    }
  }

  Future<void> _requestStatusChange(String programId, String newStatus) async {
    final programRef = FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).collection('programs').doc(programId);
    await programRef.update({'status': newStatus, 'updatedAt': FieldValue.serverTimestamp()});

    final eventQuery = await FirebaseFirestore.instance.collection('events').where('programId', isEqualTo: programId).get();
    for (var doc in eventQuery.docs) {
      await doc.reference.update({'status': newStatus, 'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  void _confirmDelete(BuildContext context, String programId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Program?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).collection('programs').doc(programId).delete();
              final events = await FirebaseFirestore.instance.collection('events').where('programId', isEqualTo: programId).get();
              for (var d in events.docs) await d.reference.delete();
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class ProgramCard extends StatelessWidget {
  final String programId;
  final String clubId;
  final Map<String, dynamic> programData;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(String) onStatusChange;

  const ProgramCard({required this.programId, required this.clubId, required this.programData, required this.onEdit, required this.onDelete, required this.onStatusChange, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = (programData['status'] ?? 'pending').toString().toLowerCase();
    
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved': statusColor = Colors.green; statusIcon = Icons.check_circle; break;
      case 'ongoing': statusColor = Colors.orange; statusIcon = Icons.play_circle; break;
      case 'completed': statusColor = Colors.blue; statusIcon = Icons.task_alt; break;
      case 'rejected': statusColor = Colors.red; statusIcon = Icons.cancel; break;
      default: statusColor = Colors.grey; statusIcon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5)),
        ],
        border: Border.all(color: statusColor.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.edit, size: 16, color: Colors.blue), onPressed: onEdit, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  IconButton(icon: const Icon(Icons.delete, size: 16, color: Colors.red), onPressed: onDelete, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            programData['name'] ?? 'Untitled',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            programData['category'] ?? 'General',
            style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (status == 'approved') 
            ElevatedButton(
              onPressed: () => onStatusChange('ongoing'),
              style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(double.infinity, 30)),
              child: const Text("START", style: TextStyle(fontSize: 10)),
            )
          else if (status == 'ongoing')
            ElevatedButton(
              onPressed: () => onStatusChange('completed'),
              style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(double.infinity, 30), backgroundColor: Colors.orange),
              child: const Text("FINISH", style: TextStyle(fontSize: 10)),
            )
          else
            Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9));
  }
}
