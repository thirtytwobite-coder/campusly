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

      // 2. Add to global 'events' collection so students can see it
      await FirebaseFirestore.instance.collection('events').add({
        'title': data['name'],
        'description': data['description'],
        'venue': data['location'],
        'date': data['date'],
        'time': data['time'],
        'clubName': data['clubName'],
        'clubId': clubId,
        'programId': programId,
        'category': data['category'] ?? 'Technical',
        'maxSeats': 100, // Default
        'filledSeats': 0,
        'posterLink': data['posterLink'],
        'visibility': data['visibility'] ?? 'college',
        'college': data['college'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event Approved and Published!')),
        );
        onProcessed();
      }
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
        title: const Text('Reject Event'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for Rejection',
            hintText: 'e.g., Venue already booked',
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
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Event Rejected')),
                );
                onProcessed();
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
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
}