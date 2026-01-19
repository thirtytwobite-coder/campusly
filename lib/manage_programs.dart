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
                    _updateProgramStatus(programDoc.id, newStatus),
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
    bool hasPrizePool = false;
    String visibility = 'college'; // 'college' or 'public'
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
                TextField(
                  controller: posterLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Poster Link',
                    hintText: 'Google Drive or image URL',
                    helperText: 'Works with Google Drive links and image URLs',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Program Name',
                    hintText: 'e.g. Annual Tech Summit',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Event details and objectives',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  hint: const Text('Select Category'),
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Technical', 'Cultural', 'Sports', 'Academic', 'Social', 'Other']
                      .map((label) => DropdownMenuItem(
                            value: label,
                            child: Text(label),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      category = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date (YYYY-MM-DD)',
                    hintText: '2024-12-25',
                    border: OutlineInputBorder(),
                  ),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (pickedDate != null) {
                      dateController.text =
                          DateFormat('yyyy-MM-dd').format(pickedDate);
                    }
                  },
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(
                    labelText: 'Time (HH:MM)',
                    hintText: '14:30',
                    border: OutlineInputBorder(),
                  ),
                  onTap: () async {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (pickedTime != null) {
                      timeController.text =
                          '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                    }
                  },
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'Event venue',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: hasPrizePool,
                  onChanged: (value) {
                    setDialogState(() {
                      hasPrizePool = value ?? false;
                      if (!hasPrizePool) {
                        prizeAmountController.clear();
                      }
                    });
                  },
                  title: const Text('Prize Pool Available'),
                  subtitle: const Text('Does this program have prize rewards?'),
                  contentPadding: EdgeInsets.zero,
                ),
                if (hasPrizePool) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: prizeAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Prize Amount',
                      hintText: 'e.g., 5000, 10000',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Event Visibility',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  value: 'college',
                  groupValue: visibility,
                  onChanged: (value) {
                    setDialogState(() {
                      visibility = value!;
                    });
                  },
                  title: const Text('College Only'),
                  subtitle: const Text('Only students from this college can participate'),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  value: 'public',
                  groupValue: visibility,
                  onChanged: (value) {
                    setDialogState(() {
                      visibility = value!;
                    });
                  },
                  title: const Text('Public'),
                  subtitle: const Text('Students from other colleges can also participate'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final validationError = _validateProgramForm(
                  nameController.text,
                  dateController.text,
                  category,
                );

                if (validationError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(validationError)),
                  );
                  return;
                }

                _addProgram(
                  ctx,
                  nameController.text,
                  descriptionController.text,
                  dateController.text,
                  timeController.text,
                  locationController.text,
                  hasPrizePool,
                  prizeAmountController.text,
                  _convertGoogleDriveLink(posterLinkController.text),
                  visibility,
                  category!,
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProgramDialog(
    BuildContext context,
    String programId,
    Map<String, dynamic> programData,
  ) {
    final nameController = TextEditingController(text: programData['name']);
    final descriptionController =
        TextEditingController(text: programData['description']);
    final dateController = TextEditingController(text: programData['date']);
    final locationController =
        TextEditingController(text: programData['location']);
    final timeController = TextEditingController(text: programData['time']);
    final posterLinkController = TextEditingController(text: programData['posterLink'] ?? '');
    final prizeAmountController = TextEditingController(text: programData['prizeAmount'] ?? '');
    String visibility = programData['visibility'] ?? 'college';
    bool hasPrizePool = programData['hasPrizePool'] ?? false;
    String? category = programData['category'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Program'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: posterLinkController,
                decoration: const InputDecoration(
                  labelText: 'Poster Link (Google Drive)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.image),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Program Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                hint: const Text('Select Category'),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: ['Technical', 'Cultural', 'Sports', 'Academic', 'Social', 'Other']
                    .map((label) => DropdownMenuItem(
                          value: label,
                          child: Text(label),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    category = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    dateController.text =
                        DateFormat('yyyy-MM-dd').format(pickedDate);
                  }
                },
                readOnly: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: 'Time (HH:MM)',
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (pickedTime != null) {
                    timeController.text =
                        '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                  }
                },
                readOnly: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setDialogState) => CheckboxListTile(
                  value: hasPrizePool,
                  onChanged: (value) {
                    setDialogState(() {
                      hasPrizePool = value ?? false;
                      if (!hasPrizePool) {
                        prizeAmountController.clear();
                      }
                    });
                  },
                  title: const Text('Prize Pool Available'),
                  subtitle: const Text('Does this program have prize rewards?'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (hasPrizePool) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: prizeAmountController,
                  decoration: const InputDecoration(
                    labelText: 'Prize Amount',
                    hintText: 'e.g., 5000, 10000',
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Event Visibility',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setDialogState) => Column(
                  children: [
                    RadioListTile<String>(
                      value: 'college',
                      groupValue: visibility,
                      onChanged: (value) {
                        setDialogState(() {
                          visibility = value!;
                        });
                      },
                      title: const Text('College Only'),
                      subtitle: const Text('Only students from this college can participate'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      value: 'public',
                      groupValue: visibility,
                      onChanged: (value) {
                        setDialogState(() {
                          visibility = value!;
                        });
                      },
                      title: const Text('Public'),
                      subtitle: const Text('Students from other colleges can also participate'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final validationError = _validateProgramForm(
                nameController.text,
                dateController.text,
                category,
              );

              if (validationError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(validationError)),
                );
                return;
              }

              _updateProgram(
                ctx,
                programId,
                nameController.text,
                descriptionController.text,
                dateController.text,
                timeController.text,
                locationController.text,
                _convertGoogleDriveLink(posterLinkController.text),
                visibility,
                hasPrizePool,
                prizeAmountController.text,
                category!,
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  String? _validateProgramForm(String name, String date, String? category) {
    if (name.trim().isEmpty) {
      return 'Program name cannot be empty';
    }
    if (date.trim().isEmpty) {
      return 'Date cannot be empty';
    }
    if (category == null) {
      return 'Please select a category';
    }

    try {
      DateFormat('yyyy-MM-dd').parseStrict(date);
    } catch (e) {
      return 'Invalid date format. Use YYYY-MM-DD';
    }

    return null;
  }

  String _convertGoogleDriveLink(String link) {
    if (link.isEmpty) return '';

    if (link.contains('.jpg') || link.contains('.jpeg') || link.contains('.png') || link.contains('.gif') || link.contains('.webp')) {
      return link;
    }

    if (link.contains('drive.google.com/uc?export=view')) {
      return link;
    }

    final regex = RegExp(r'(?:drive\.google\.com/file/d/|id=)([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(link);

    if (match != null) {
      final fileId = match.group(1);
      return 'https://drive.google.com/uc?export=view&id=$fileId';
    }

    return link;
  }

  Future<void> _addProgram(
    BuildContext context,
    String name,
    String description,
    String date,
    String time,
    String location,
    bool hasPrizePool,
    String prizeAmount,
    String posterLink,
    String visibility,
    String category,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user = FirebaseAuth.instance.currentUser;

      final studentDoc = await FirebaseFirestore.instance.collection('student').doc(user?.uid).get();
      final coordinatorName = studentDoc.data()?['name'] ?? 'Unknown';

      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('programs')
          .add({
        'name': name.trim(),
        'description': description.trim(),
        'date': date,
        'time': time,
        'location': location.trim(),
        'posterLink': posterLink.isNotEmpty ? posterLink.trim() : null,
        'hasPrizePool': hasPrizePool,
        'prizeAmount': hasPrizePool && prizeAmount.isNotEmpty ? prizeAmount : null,
        'visibility': visibility,
        'category': category,
        'status': 'pending',
        'clubId': widget.clubId,
        'clubName': widget.clubName,
        'coordinatorId': user?.uid,
        'coordinatorName': coordinatorName,
        'coordinatorEmail': user?.email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Program sent for approval!')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _updateProgram(
    BuildContext context,
    String programId,
    String name,
    String description,
    String date,
    String time,
    String location,
    String posterLink,
    String visibility,
    bool hasPrizePool,
    String prizeAmount,
    String category,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('programs')
          .doc(programId)
          .update({
        'name': name.trim(),
        'description': description.trim(),
        'date': date,
        'time': time,
        'location': location.trim(),
        'posterLink': posterLink.isNotEmpty ? posterLink.trim() : null,
        'visibility': visibility,
        'hasPrizePool': hasPrizePool,
        'prizeAmount': hasPrizePool && prizeAmount.isNotEmpty ? prizeAmount.trim() : null,
        'category': category,
        'status': 'pending', // Reset status on edit
        'updatedAt': FieldValue.serverTimestamp(),
      });
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Program updated and sent for re-approval!')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _updateProgramStatus(String programId, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('programs')
          .doc(programId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      messenger.showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _confirmDelete(BuildContext context, String programId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Program?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(ctx);
              try {
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(widget.clubId)
                    .collection('programs')
                    .doc(programId)
                    .delete();

                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Program deleted')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
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

  const ProgramCard({
    required this.programId,
    required this.clubId,
    required this.programData,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final status = (programData['status'] ?? 'pending').toString().toLowerCase();
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final posterLink = programData['posterLink'] as String?;
    final rejectionReason = programData['rejectionReason'] as String?;

    final List<String> availableStatuses = ['ongoing', 'completed', 'cancelled'];
    if (status == 'approved') {
      availableStatuses.insert(0, 'approved');
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (posterLink != null && posterLink.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    posterLink,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: double.infinity, height: 200,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity, height: 200,
                        color: Colors.grey[300],
                        child: const Center(child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey)),
                      );
                    },
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        programData['name'] ?? 'Unnamed Program',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        programData['description'] ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: status, color: statusColor, icon: statusIcon),
              ],
            ),
            if (status == 'rejected' && rejectionReason != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reason: $rejectionReason',
                        style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16, runSpacing: 8,
              children: [
                _InfoRow(icon: Icons.calendar_today, text: programData['date'] ?? 'No date'),
                _InfoRow(icon: Icons.schedule, text: programData['time'] ?? 'No time'),
                _InfoRow(icon: Icons.location_on, text: programData['location'] ?? 'No location'),
                _InfoRow(
                  icon: (programData['visibility'] ?? 'college') == 'public' ? Icons.public : Icons.lock,
                  text: (programData['visibility'] ?? 'college') == 'public' ? 'Public Event' : 'College Only',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (status != 'pending' && status != 'rejected')
                  DropdownButton<String>(
                    value: status,
                    items: availableStatuses
                        .map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value[0].toUpperCase() + value.substring(1)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) onStatusChange(newValue);
                    },
                  )
                else
                  Text(
                    status == 'pending' ? 'Awaiting Approval' : 'Event Rejected',
                    style: TextStyle(color: statusColor, fontStyle: FontStyle.italic, fontSize: 12),
                  ),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: onEdit),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: onDelete),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'approved': return Colors.blue;
      case 'ongoing': return Colors.blue;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.schedule;
      case 'approved': return Icons.check_circle_outline;
      case 'ongoing': return Icons.play_circle_filled;
      case 'completed': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      case 'rejected': return Icons.error_outline;
      default: return Icons.help;
    }
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  final IconData icon;

  const StatusBadge({required this.status, required this.color, required this.icon, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
