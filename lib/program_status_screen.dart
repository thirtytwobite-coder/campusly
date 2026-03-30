/// This screen displays programs filtered by their approval status.
/// It shows approved, rejected, or all programs for a specific club.
/// The screen allows faculty to view the status of program requests and track
/// the approval workflow. Different statuses are displayed with appropriate color coding.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProgramStatusScreen extends StatelessWidget {
  final String clubId;
  final String clubName;
  final String status;

  const ProgramStatusScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.status,
  });

  String get _titlePrefix {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Programs';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which statuses to display based on the selection
    final List<String> targetStatuses = status == 'approved'
        ? ['approved', 'ongoing', 'completed']
        : [status];

    return Scaffold(
      appBar: AppBar(
        title: Text('$_titlePrefix - $clubName'),
        backgroundColor: status == 'approved' ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('programs')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No programs found for this club.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Filter documents in memory to avoid index requirements and complex queries
          final filteredDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String docStatus = (data['status'] ?? '').toString().toLowerCase();
            return targetStatuses.contains(docStatus);
          }).toList();

          if (filteredDocs.isEmpty) {
            return Center(
              child: Text(
                'No $_titlePrefix programs yet.',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            );
          }

          // Sort by date (most recent first)
          filteredDocs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            
            final aTime = (aData['updatedAt'] ?? aData['approvedAt'] ?? aData['createdAt']) as Timestamp?;
            final bTime = (bData['updatedAt'] ?? bData['approvedAt'] ?? bData['createdAt']) as Timestamp?;
            
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final String name = data['name'] ?? 'Untitled Event';
              final String category = data['category'] ?? 'General';
              final String date = data['date'] ?? 'TBD';
              final String eventStatus = (data['status'] ?? 'approved').toString().toLowerCase();
              final String? reason = data['rejectionReason'];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(eventStatus).withOpacity(0.1),
                    child: Icon(_getStatusIcon(eventStatus), color: _getStatusColor(eventStatus)),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('$category • $date', style: TextStyle(color: Colors.grey[700])),
                      if (status == 'rejected' && reason != null && reason.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Reason: $reason',
                          style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                      if (status == 'approved' && eventStatus != 'approved') ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(eventStatus).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            eventStatus.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(eventStatus),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    // Could navigate to details if needed
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String s) {
    switch (s) {
      case 'ongoing': return Colors.orange;
      case 'completed': return Colors.blue;
      case 'cancelled': return Colors.grey;
      case 'rejected': return Colors.red;
      default: return Colors.green;
    }
  }

  IconData _getStatusIcon(String s) {
    switch (s) {
      case 'ongoing': return Icons.play_arrow;
      case 'completed': return Icons.done_all;
      case 'cancelled': return Icons.block;
      case 'rejected': return Icons.close;
      default: return Icons.check_circle;
    }
  }
}
