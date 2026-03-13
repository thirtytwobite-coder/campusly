import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UnifiedApprovalScreen extends StatefulWidget {
  final String clubId;
  final String clubName;

  const UnifiedApprovalScreen({
    required this.clubId,
    required this.clubName,
    super.key,
  });

  @override
  State<UnifiedApprovalScreen> createState() => _UnifiedApprovalScreenState();
}

class _UnifiedApprovalScreenState extends State<UnifiedApprovalScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pending Certificates - ${widget.clubName}'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: _buildCertificatesTab(),
    );
  }

  Widget _buildCertificatesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('certificate_approvals')
          .where('clubId', isEqualTo: widget.clubId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text('No pending certificate requests'));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _CertificateApprovalCard(
              approvalId: doc.id,
              data: data,
              onProcessed: () => setState(() {}),
            );
          },
        );
      },
    );
  }
}

class _CertificateApprovalCard extends StatelessWidget {
  final String approvalId;
  final Map<String, dynamic> data;
  final VoidCallback onProcessed;

  const _CertificateApprovalCard({
    required this.approvalId,
    required this.data,
    required this.onProcessed,
  });

  Future<void> _processApproval(BuildContext context, bool approve, {String? reason}) async {
    try {
      final eventId = data['eventId'];
      
      final Map<String, dynamic> updateData = {
        'status': approve ? 'approved' : 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
      };
      if (!approve && reason != null) {
        updateData['rejectionReason'] = reason;
      }

      await FirebaseFirestore.instance
          .collection('certificate_approvals')
          .doc(approvalId)
          .update(updateData);

      if (approve) {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .update({'certsApproved': true});
      }

      // 🔹 Notify the club with explicit rejection data
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(data['clubId'])
          .collection('notifications')
          .add({
        'title': approve ? 'Certificates Approved' : 'Certificates Rejected',
        'message': approve 
          ? 'Certificates for "${data['eventName']}" have been approved.'
          : 'Certificates for "${data['eventName']}" were rejected by faculty.${reason != null ? "\nReason: $reason" : ""}',
        'timestamp': FieldValue.serverTimestamp(),
        'type': approve ? 'approval' : 'rejection',
        'eventId': eventId,
        'eventName': data['eventName'],
        'rejectionReason': reason,
        'read': false,
      });

      onProcessed();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? 'Certificates Approved!' : 'Certificates Rejected')),
        );
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showRejectDialog(BuildContext context) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Certificates'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for Rejection',
            hintText: 'e.g., Winners list incorrect',
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
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }
              Navigator.pop(ctx);
              _processApproval(context, false, reason: reasonController.text.trim());
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showParticipantsDialog(BuildContext context) {
    final eventId = data['eventId'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Event Results: ${data['eventName']}"),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('events').doc(eventId).get(),
            builder: (context, eventSnap) {
              if (eventSnap.connectionState == ConnectionState.waiting) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
              
              final eventData = eventSnap.data?.data() as Map<String, dynamic>?;
              final winners = eventData?['manualWinners'] as Map<String, dynamic>? ?? {};
              
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('registrations')
                    .where('eventId', isEqualTo: eventId)
                    .snapshots(),
                builder: (context, regSnap) {
                  if (regSnap.connectionState == ConnectionState.waiting) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                  
                  final regs = regSnap.data?.docs ?? [];
                  final participants = regs.where((doc) => (doc.data() as Map<String, dynamic>)['participated'] == true).toList();
                  
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (winners.values.any((v) => v.toString().isNotEmpty)) ...[
                          const Row(
                            children: [
                              Icon(Icons.emoji_events, color: Colors.orange, size: 20),
                              SizedBox(width: 8),
                              Text("Winners", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
                            ],
                          ),
                          const Divider(),
                          ...winners.entries.where((e) => e.value.toString().isNotEmpty).map((e) => ListTile(
                            dense: true,
                            title: Text(e.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Rank: ${e.key}"),
                          )),
                          const SizedBox(height: 16),
                        ],
                        const Row(
                          children: [
                            Icon(Icons.people, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Text("Marked Participants", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                          ],
                        ),
                        const Divider(),
                        if (participants.isEmpty) 
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text("No participants marked yet.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                          ),
                        ...participants.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          return ListTile(
                            dense: true,
                            leading: const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
                            title: Text(d['studentName'] ?? 'Unknown'),
                            subtitle: Text(d['studentEmail'] ?? '', style: const TextStyle(fontSize: 11)),
                          );
                        }),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
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
              children: [
                const Icon(Icons.card_membership, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text("Certificates: ${data['eventName']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 8),
            Text("Requested by: ${data['requestedBy'] ?? 'Unknown'}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showParticipantsDialog(context),
              icon: const Icon(Icons.list_alt, size: 18),
              label: const Text("View Participants & Winners"),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: Theme.of(context).primaryColor),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => _showRejectDialog(context), child: const Text('Reject', style: TextStyle(color: Colors.red)))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () => _processApproval(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), child: const Text('Approve', style: TextStyle(color: Colors.white)))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
