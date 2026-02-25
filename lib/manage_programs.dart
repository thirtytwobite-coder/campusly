import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.clubName} - Programs'),
        backgroundColor: const Color(0xFF1A237E),
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
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
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
        backgroundColor: const Color(0xFF1A237E),
        onPressed: () => _showAddProgramDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddProgramDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final dateController = TextEditingController();
    final locationController = TextEditingController();
    final timeController = TextEditingController();
    final prizeAmountController = TextEditingController();
    final posterLinkController = TextEditingController();
    final maxSeatsController = TextEditingController(text: "100"); // 🔹 Default
    bool hasPrizePool = false;
    String visibility = 'college'; 
    String? category;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Program'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Program Name *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: maxSeatsController, decoration: const InputDecoration(labelText: 'Max Seats (0 for unlimited)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.event_seat)), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder()), maxLines: 3),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  hint: const Text('Select Category'),
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: ['Technical', 'Cultural', 'Sports', 'Academic', 'Social', 'Other'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                  onChanged: (v) => setDialogState(() => category = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)', border: OutlineInputBorder()),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                  },
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(labelText: 'Time (HH:MM) *', border: OutlineInputBorder()),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (picked != null) timeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                  },
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Venue *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: hasPrizePool,
                  title: const Text('Prize Pool'),
                  onChanged: (v) => setDialogState(() => hasPrizePool = v ?? false),
                ),
                if (hasPrizePool) TextField(controller: prizeAmountController, decoration: const InputDecoration(labelText: 'Prize Amount', border: OutlineInputBorder(), prefixText: '₹ ')),
                const SizedBox(height: 12),
                const Divider(),
                const Text('Event Visibility', style: TextStyle(fontWeight: FontWeight.bold)),
                RadioListTile<String>(value: 'college', groupValue: visibility, title: const Text('College Only'), onChanged: (v) => setDialogState(() => visibility = v!)),
                RadioListTile<String>(value: 'public', groupValue: visibility, title: const Text('Public'), onChanged: (v) => setDialogState(() => visibility = v!)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty || descriptionController.text.isEmpty || category == null) return;
                _addProgram(ctx, nameController.text, descriptionController.text, dateController.text, timeController.text, locationController.text, hasPrizePool, prizeAmountController.text, posterLinkController.text, visibility, category!, int.tryParse(maxSeatsController.text) ?? 100);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProgramDialog(BuildContext context, String programId, Map<String, dynamic> programData) {
    final nameController = TextEditingController(text: programData['name']);
    final descriptionController = TextEditingController(text: programData['description']);
    final dateController = TextEditingController(text: programData['date']);
    final locationController = TextEditingController(text: programData['location']);
    final timeController = TextEditingController(text: programData['time']);
    final maxSeatsController = TextEditingController(text: (programData['maxSeats'] ?? 100).toString());
    String visibility = programData['visibility'] ?? 'college';
    String? category = programData['category'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Program'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Program Name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: maxSeatsController, decoration: const InputDecoration(labelText: 'Max Seats', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()), maxLines: 3),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: ['Technical', 'Cultural', 'Sports', 'Academic', 'Social', 'Other'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                  onChanged: (v) => setDialogState(() => category = v),
                ),
                const SizedBox(height: 12),
                TextField(controller: dateController, decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()), readOnly: true),
                const SizedBox(height: 12),
                TextField(controller: timeController, decoration: const InputDecoration(labelText: 'Time', border: OutlineInputBorder()), readOnly: true),
                const SizedBox(height: 12),
                TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Venue', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => _updateProgram(ctx, programId, nameController.text, descriptionController.text, dateController.text, timeController.text, locationController.text, "", visibility, false, "", category!, int.tryParse(maxSeatsController.text) ?? 100),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addProgram(BuildContext context, String name, String description, String date, String time, String location, bool hasPrize, String prize, String poster, String visibility, String category, int maxSeats) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('student').doc(user?.uid).get();
      if (!userDoc.exists) userDoc = await FirebaseFirestore.instance.collection('faculty').doc(user?.uid).get();
      final coordinatorName = (userDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Unknown';
      final college = (userDoc.data() as Map<String, dynamic>?)?['college'] ?? 'Unknown';

      await FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).collection('programs').add({
        'name': name.trim(),
        'description': description.trim(),
        'date': date,
        'time': time,
        'location': location.trim(),
        'visibility': visibility,
        'college': college,
        'category': category,
        'maxSeats': maxSeats,
        'status': 'pending',
        'clubId': widget.clubId,
        'clubName': widget.clubName,
        'coordinatorId': user?.uid,
        'coordinatorName': coordinatorName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      Navigator.pop(context);
    } catch (e) { print(e); }
  }

  Future<void> _updateProgram(BuildContext context, String programId, String name, String description, String date, String time, String location, String poster, String visibility, bool hasPrize, String prize, String category, int maxSeats) async {
    try {
      await FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).collection('programs').doc(programId).update({
        'name': name.trim(),
        'description': description.trim(),
        'maxSeats': maxSeats,
        'category': category,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      Navigator.pop(context);
    } catch (e) { print(e); }
  }

  Future<void> _requestStatusChange(String programId, String newStatus) async {
    // 🔹 When approving, we must also sync 'maxSeats' to the 'events' collection
    final programRef = FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).collection('programs').doc(programId);
    await programRef.update({'status': newStatus, 'updatedAt': FieldValue.serverTimestamp()});
  }

  void _confirmDelete(BuildContext context, String programId) {}
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(programData['name'] ?? 'Unnamed'),
        subtitle: Text("Date: ${programData['date']} | Seats: ${programData['maxSeats'] ?? 'Unlimited'}"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: onEdit),
          ],
        ),
      ),
    );
  }
}
