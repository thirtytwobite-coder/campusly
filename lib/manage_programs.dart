import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

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
                    labelText: 'https://drive.google.com/drive/folders/12Ru1KjEO2k2jynTgH3d2vuBJ_2cdtxMV',
                    hintText: 'https://drive.google.com/file/d/1csUPujcTjvMLSX942_9i95ulfkTkAoaj/view?usp=drivesdk',
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
                );

                if (validationError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(validationError)),
                  );
                  return;
                }

                _addProgram(
                  nameController.text,
                  descriptionController.text,
                  dateController.text,
                  timeController.text,
                  locationController.text,
                  hasPrizePool,
                  prizeAmountController.text,
                  _convertGoogleDriveLink(posterLinkController.text),
                  visibility,
                );
                Navigator.pop(ctx);
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
              );

              if (validationError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(validationError)),
                );
                return;
              }

              _updateProgram(
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
              );
              Navigator.pop(ctx);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  String? _validateProgramForm(String name, String date) {
    if (name.trim().isEmpty) {
      return 'Program name cannot be empty';
    }
    if (date.trim().isEmpty) {
      return 'Date cannot be empty';
    }

    // Validate date format
    try {
      DateFormat('yyyy-MM-dd').parseStrict(date);
    } catch (e) {
      return 'Invalid date format. Use YYYY-MM-DD';
    }

    return null;
  }

  String _convertGoogleDriveLink(String link) {
    if (link.isEmpty) return '';
    
    // If it's already a direct image URL, return as is
    if (link.contains('.jpg') || link.contains('.jpeg') || link.contains('.png') || link.contains('.gif') || link.contains('.webp')) {
      return link;
    }
    
    // If already a drive.google.com/uc link, return as is
    if (link.contains('drive.google.com/uc?export=view')) {
      return link;
    }
    
    // Convert Google Drive sharing link to direct download link
    // Format: https://drive.google.com/file/d/{id}/view -> https://drive.google.com/uc?export=view&id={id}
    final regex = RegExp(r'(?:drive\.google\.com/file/d/|id=)([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(link);
    
    if (match != null) {
      final fileId = match.group(1);
      return 'https://drive.google.com/uc?export=view&id=$fileId';
    }
    
    return link;
  }

  Future<void> _addProgram(
    String name,
    String description,
    String date,
    String time,
    String location,
    bool hasPrizePool,
    String prizeAmount,
    String posterLink,
    String visibility,
  ) async {
    try {
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
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Program created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateProgram(
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
  ) async {
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
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Program updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateProgramStatus(String programId, String newStatus) async {
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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
              await FirebaseFirestore.instance
                  .collection('clubs')
                  .doc(widget.clubId)
                  .collection('programs')
                  .doc(programId)
                  .delete();
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Program deleted')),
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

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster Image
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
                      if (loadingProgress == null) {
                        return child;
                      }
                      return Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            const Text('Image unavailable', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                // Show the link for debugging
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Link: ${posterLink.substring(0, math.min(50, posterLink.length))}...'),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              },
                              child: const Text(
                                'Tap for details',
                                style: TextStyle(color: Colors.blue, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        programData['description'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  status: status,
                  color: statusColor,
                  icon: statusIcon,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _InfoRow(
                  icon: Icons.calendar_today,
                  text: programData['date'] ?? 'No date',
                ),
                _InfoRow(
                  icon: Icons.schedule,
                  text: programData['time'] ?? 'No time',
                ),
                _InfoRow(
                  icon: Icons.location_on,
                  text: programData['location'] ?? 'No location',
                ),
                _InfoRow(
                  icon: (programData['visibility'] ?? 'college') == 'public' 
                      ? Icons.public 
                      : Icons.lock,
                  text: (programData['visibility'] ?? 'college') == 'public' 
                      ? 'Public Event' 
                      : 'College Only',
                ),
                if (programData['hasPrizePool'] ?? false) ...[
                  _InfoRow(
                    icon: Icons.card_giftcard,
                    text: 'Prize Pool Available',
                  ),
                  if (programData['prizeAmount'] != null &&
                      programData['prizeAmount'].toString().isNotEmpty)
                    _InfoRow(
                      icon: Icons.monetization_on,
                      text: '₹ ${programData['prizeAmount']}',
                    ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: status,
                  items: ['pending', 'ongoing', 'completed', 'cancelled']
                      .map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value[0].toUpperCase() + value.substring(1)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      onStatusChange(newValue);
                    }
                  },
                  underline: Container(
                    height: 2,
                    color: statusColor,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: onDelete,
                    ),
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
      case 'pending':
        return Colors.orange;
      case 'ongoing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'ongoing':
        return Icons.play_circle_filled;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  final IconData icon;

  const StatusBadge({
    required this.status,
    required this.color,
    required this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
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
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}