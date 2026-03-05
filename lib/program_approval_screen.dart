import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProgramApprovalScreen extends StatefulWidget {
  final String clubId;
  final String clubName;

  const ProgramApprovalScreen({
    required this.clubId,
    required this.clubName,
    super.key,
  });

  @override
  State<ProgramApprovalScreen> createState() => _ProgramApprovalScreenState();
}

class _ProgramApprovalScreenState extends State<ProgramApprovalScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pending Approvals - ${widget.clubName}'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .doc(widget.clubId)
            .collection('programs')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No pending programs for approval'),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _ApprovalCard(
                programId: doc.id,
                clubId: widget.clubId,
                data: data,
                onProcessed: () => setState(() {}),
              );
            },
          );
        },
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final String programId;
  final String clubId;
  final Map<String, dynamic> data;
  final VoidCallback onProcessed;

  const _ApprovalCard({
    required this.programId,
    required this.clubId,
    required this.data,
    required this.onProcessed,
  });

  Future<void> _approveEvent(BuildContext context) async {
    try {
      final String? requestedStatus = data['requestedStatus'];

      if (requestedStatus != null) {
        // --- CASE 1: APPROVING A STATUS CHANGE (Ongoing/Completed/etc.) ---

        // 1. Update program status to the requested status
        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('programs')
            .doc(programId)
            .update({
          'status': requestedStatus,
          'requestedStatus': FieldValue.delete(),
          'approvedAt': FieldValue.serverTimestamp(),
        });

        // 2. Update the status in the global 'events' collection
        final eventQuery = await FirebaseFirestore.instance
            .collection('events')
            .where('programId', isEqualTo: programId)
            .limit(1)
            .get();

        if (eventQuery.docs.isNotEmpty) {
          await eventQuery.docs.first.reference.update({
            'status': requestedStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status update to $requestedStatus approved!')),
          );
        }

        // 3. Send Notification to Club Coordinator
        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('notifications')
            .add({
          'title': 'Status Update Approved',
          'message': 'Your request to change status of "${data['name']}" to "$requestedStatus" has been approved.',
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'approval',
          'read': false,
        });
      } else {
        // --- CASE 2: NEW PROGRAM APPROVAL ---

        // 1. Update program status to 'approved'
        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('programs')
            .doc(programId)
            .update({
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
        });

        // 2. Add or Update in global 'events' collection
        final existingEvents = await FirebaseFirestore.instance
            .collection('events')
            .where('programId', isEqualTo: programId)
            .limit(1)
            .get();

        final Map<String, dynamic> eventPayload = {
          'title': data['name'],
          'description': data['description'],
          'venue': data['location'],
          'date': data['date'],
          'time': data['time'],
          'clubName': data['clubName'],
          'coordinatorName': data['coordinatorName'] ?? '',
          'clubId': clubId,
          'programId': programId,
          'category': data['category'] ?? 'Technical',
          'status': 'approved',
          'maxSeats': 100,
          'filledSeats': 0,
          'posterLink': data['posterLink'],
          'visibility': data['visibility'] ?? 'college',
          'college': data['college'],
          'requiresVolunteers': data['requiresVolunteers'] ?? false,
          'volunteerCount': data['volunteerCount'],
          'volunteerRole': data['volunteerRole'],
          // Team event details
          'isTeamEvent': data['isTeamEvent'] ?? false,
          'teamSize': data['teamSize'],
          'createdAt': FieldValue.serverTimestamp(),
        };

        if (existingEvents.docs.isNotEmpty) {
          // Update existing event
          await existingEvents.docs.first.reference.update(eventPayload);
        } else {
          // Add new event
          await FirebaseFirestore.instance.collection('events').add(eventPayload);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event Approved and Published!')),
          );
        }

        // 3. Send Notification to Club Coordinator
        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('notifications')
            .add({
          'title': 'Event Approved',
          'message': 'Your event "${data['name']}" has been approved and published.',
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'approval',
          'read': false,
        });
      }
      onProcessed();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showRejectDialog(BuildContext context) async {
    final reasonController = TextEditingController();
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for Rejection',
            hintText: 'e.g., Change not allowed',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }

              final String? requestedStatus = data['requestedStatus'];

              if (requestedStatus != null) {
                // Rejecting a status change: Revert to previous status
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId)
                    .collection('programs')
                    .doc(programId)
                    .update({
                  'status': 'approved', // Revert from pending
                  'requestedStatus': FieldValue.delete(),
                  'rejectionReason': 'Status change to $requestedStatus rejected: ${reasonController.text.trim()}',
                  'rejectedAt': FieldValue.serverTimestamp(),
                });
              } else {
                // Rejecting a new program
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId)
                    .collection('programs')
                    .doc(programId)
                    .update({
                  'status': 'rejected',
                  'rejectionReason': reasonController.text.trim(),
                  'rejectedAt': FieldValue.serverTimestamp(),
                });
              }

              if (context.mounted) {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Redirect to Dashboard
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Request Rejected and returned to dashboard')),
                );
                onProcessed();
              }

              // Send Notification to Club Coordinator
              await FirebaseFirestore.instance
                  .collection('clubs')
                  .doc(clubId)
                  .collection('notifications')
                  .add({
                'title': 'Request Rejected',
                'message': 'Your request for "${data['name']}" was rejected. Reason: ${reasonController.text.trim()}',
                'timestamp': FieldValue.serverTimestamp(),
                'type': 'rejection',
                'read': false,
              });
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? requestedStatus = data['requestedStatus'];
    final bool isStatusChange = requestedStatus != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isStatusChange ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isStatusChange
            ? BorderSide(color: Colors.orange.shade300, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['posterLink'] != null && data['posterLink'].toString().isNotEmpty)
              Container(
                width: double.infinity,
                height: 180,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _convertGoogleDriveLink(data['posterLink']),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                ),
              ),
            if (isStatusChange)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "STATUS CHANGE REQUEST: ${requestedStatus.toUpperCase()}",
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    data['name'] ?? 'Unnamed Program',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (data['visibility'] ?? 'college') == 'public' ? Colors.green[50] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: (data['visibility'] ?? 'college') == 'public' ? Colors.green : Colors.blue),
                  ),
                  child: Text(
                    (data['visibility'] ?? 'college').toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: (data['visibility'] ?? 'college') == 'public' ? Colors.green[900] : Colors.blue[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(data['description'] ?? '', style: const TextStyle(color: Colors.grey)),
            const Divider(height: 24),
            _detailRow(Icons.calendar_today, 'Date', data['date']),
            _detailRow(Icons.schedule, 'Time', data['time']),
            _detailRow(Icons.location_on, 'Venue', data['location']),
            _detailRow(Icons.school, 'College', data['college']),
            _detailRow(Icons.person, 'Coordinator', data['coordinatorName']),
            _detailRow(Icons.category, 'Category', data['category'] ?? ''),
            _detailRow(Icons.event, 'Mode', data['eventMode'] ?? ''),
            // Prize details
            if ((data['hasPrizePool'] ?? false) == true) ...[
              _detailRow(Icons.emoji_events, 'Prize', data['prizeAmount']?.toString() ?? 'N/A'),
            ],
            // Volunteer details
            if ((data['requiresVolunteers'] ?? false) == true) ...[
              _detailRow(Icons.volunteer_activism, 'Volunteers Needed', (data['volunteerCount'] ?? '').toString()),
              if ((data['volunteerRole'] ?? '').toString().isNotEmpty) _detailRow(Icons.list, 'Volunteer Role', data['volunteerRole']?.toString()),
            ],
            // Team event details
            if ((data['isTeamEvent'] ?? false) == true) ...[
              _detailRow(Icons.groups, 'Team Size', (data['teamSize'] ?? '').toString()),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(context),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Reject', style: TextStyle(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveEvent(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isStatusChange ? Colors.orange : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check),
                    label: Text(isStatusChange ? 'Approve Update' : 'Approve Event'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value ?? 'N/A', style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  String _convertGoogleDriveLink(String? link) {
    if (link == null || link.isEmpty) return '';

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
}
