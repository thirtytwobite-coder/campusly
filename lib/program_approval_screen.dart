/// This screen allows faculty to approve or reject program/event requests from clubs.
/// It displays pending programs that require faculty approval before they can proceed.
/// Faculty can approve individual programs, reject them with reasons, or perform bulk operations.
/// The screen integrates with notification services to inform coordinators of approval decisions.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'vibrant_background.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'notification_sync_service.dart';
import 'notification_service.dart';

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
  Future<void> _rejectAll(BuildContext context, List<QueryDocumentSnapshot> docs) async {
    final reasonController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text('Reject All (${docs.length})', style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to reject all pending requests? This cannot be undone.',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason for Bulk Rejection',
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.comment_rounded),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.primary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a reason')));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Reject All'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final String reason = reasonController.text.trim();

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final String? requestedStatus = data['requestedStatus'];
          final programRef = FirebaseFirestore.instance
              .collection('clubs')
              .doc(widget.clubId)
              .collection('programs')
              .doc(doc.id);

          if (requestedStatus != null) {
            batch.update(programRef, {
              'status': 'approved',
              'requestedStatus': FieldValue.delete(),
              'rejectionReason': 'Status change rejected: $reason',
              'rejectedAt': FieldValue.serverTimestamp(),
            });
          } else {
            batch.update(programRef, {
              'status': 'rejected',
              'rejectionReason': reason,
              'rejectedAt': FieldValue.serverTimestamp(),
            });
          }


          // Send individual notifications
          final notifyRef = FirebaseFirestore.instance
              .collection('clubs')
              .doc(widget.clubId)
              .collection('notifications')
              .doc();
          batch.set(notifyRef, {
            'title': 'Request Rejected',
            'message': 'Your request for "${data['name']}" was rejected. Reason: $reason',
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'rejection',
            'read': false,
          });
        }

        await batch.commit();
        if (context.mounted) {
          Navigator.pop(context); // Go back to dashboard
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All requests rejected successfully.')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error rejecting all: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('programs')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        final List<QueryDocumentSnapshot> docs = snapshot.data?.docs ?? [];

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Column(
              children: [
                const Text(
                  'PENDING APPROVALS',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, fontSize: 18),
                ),
                Text(
                  widget.clubName.toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0, fontSize: 10, color: isDark ? Colors.white54 : Colors.black54),
                ),
              ],
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: (isDark ? Colors.black : Colors.white).withOpacity(isDark ? 0.4 : 0.6),
                ),
              ),
            ),
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              if (docs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                  tooltip: 'Reject All',
                  onPressed: () => _rejectAll(context, docs),
                ),
            ],
          ),
          body: Stack(
            children: [
              const VibrantBackground(),
              Builder(
                builder: (context) {
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No pending requests',
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    padding: const EdgeInsets.fromLTRB(20, 120, 20, 40),
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _ApprovalCard(
                          programId: doc.id,
                          clubId: widget.clubId,
                          data: data,
                          onProcessed: () => setState(() {}),
                        ),
                      ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
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
      final bool isStatusChange = requestedStatus != null;

      if (requestedStatus != null) {
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
        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('programs')
            .doc(programId)
            .update({
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
        });

        final existingEvents = await FirebaseFirestore.instance
            .collection('events')
            .where('programId', isEqualTo: programId)
            .limit(1)
            .get();

        final int approvedCapacity = data['totalSeats'] != null 
          ? (data['totalSeats'] is int ? data['totalSeats'] : int.tryParse(data['totalSeats'].toString()) ?? 100) 
          : (data['maxSeats'] != null 
              ? (data['maxSeats'] is int ? data['maxSeats'] : int.tryParse(data['maxSeats'].toString()) ?? 100)
              : 100);

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
          'eventMode': data['eventMode'] ?? 'Online',
          'status': 'approved',
          'totalSeats': approvedCapacity,
          'posterLink': data['posterLink'],
          'visibility': data['visibility'] ?? 'college',
          'college': data['college'],
          'requiresVolunteers': data['requiresVolunteers'] ?? false,
          'volunteerCount': data['volunteerCount'],
          'volunteerRole': data['volunteerRole'],
          'isTeamEvent': data['isTeamEvent'] ?? false,
          'teamSize': data['teamSize'],
          'registrationDeadlineDate': data['registrationDeadlineDate'],
          'registrationDeadlineTime': data['registrationDeadlineTime'],
        };

        if (existingEvents.docs.isNotEmpty) {
          await existingEvents.docs.first.reference.update(eventPayload);
        } else {
          eventPayload['filledSeats'] = 0;
          eventPayload['createdAt'] = FieldValue.serverTimestamp();
          await FirebaseFirestore.instance.collection('events').add(eventPayload);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event Approved and Published!')),
          );
        }

        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('notifications')
            .add({
          'type': 'approval',
          'read': false,
        });

        // 🔹 Trigger Notification for Club Coordinator
        final coordinatorId = data['coordinatorId'];
        if (coordinatorId != null) {
          await NotificationSyncService.sendNotification(
            targetUid: coordinatorId,
            channelId: NotificationService.successChannelId,
            title: 'Event Approved 🎉',
            body: 'Your event "${data['name']}" has been approved successfully.',
            data: {'type': 'approval_success', 'screen': 'event_details'},
          );
        }


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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('Reject Request', style: TextStyle(fontWeight: FontWeight.w900)),
          content: TextField(
            controller: reasonController,
            decoration: InputDecoration(
              labelText: 'Reason for Rejection',
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.error_outline_rounded),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please provide a reason')),
                  );
                  return;
                }

                final String? requestedStatus = data['requestedStatus'];

                if (requestedStatus != null) {
                  await FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(clubId)
                      .collection('programs')
                      .doc(programId)
                      .update({
                    'status': 'approved',
                    'requestedStatus': FieldValue.delete(),
                    'rejectionReason': 'Status change to $requestedStatus rejected: ${reasonController.text.trim()}',
                    'rejectedAt': FieldValue.serverTimestamp(),
                  });
                } else {
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
                  Navigator.pop(ctx); 
                  Navigator.pop(context); 
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request Rejected')),
                  );
                  onProcessed();
                }

                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId)
                    .collection('notifications')
                    .add({
                  'title': 'Request Rejected',
                  'message': 'Your request for "${data['name']}" was rejected. Reason: ${reasonController.text.trim()}',
                  'timestamp': FieldValue.serverTimestamp(),
                  'type': 'rejection',
                });

                // 🔹 Trigger Notification for Club Coordinator (Alert channel)
                final coordinatorId = data['coordinatorId'];
                if (coordinatorId != null) {
                  await NotificationSyncService.sendNotification(
                    targetUid: coordinatorId,
                    channelId: NotificationService.alertChannelId,
                    title: 'Event Request Rejected ❌',
                    body: 'Your event "${data['name']}" was rejected. Reason: ${reasonController.text.trim()}',
                    data: {'type': 'approval_rejection', 'screen': 'manage_programs'},
                  );
                }


              },
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? requestedStatus = data['requestedStatus'];
    final bool isStatusChange = requestedStatus != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['posterLink'] != null && data['posterLink'].toString().isNotEmpty)
              Container(
                width: double.infinity,
                height: 180,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: data['posterLink'].toString().startsWith('data:image') ? Image.memory(
                    base64Decode(data['posterLink'].toString().split(',').last),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
                  ) : Image.network(
                    _convertGoogleDriveLink(data['posterLink']),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
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
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.orangeAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "STATUS CHANGE REQUEST: ${requestedStatus.toUpperCase()}",
                        style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (data['visibility'] ?? 'college') == 'public' ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (data['visibility'] ?? 'college') == 'public' ? Colors.green : Colors.blue),
                  ),
                  child: Text(
                    (data['visibility'] ?? 'college') == 'public' ? 'PUBLIC' : 'COLLEGE ONLY',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: (data['visibility'] ?? 'college') == 'public' ? Colors.green : Colors.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data['description'] ?? '', 
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const Divider(height: 32, thickness: 0.5),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _detailChip(Icons.calendar_today_rounded, data['date']),
                _detailChip(Icons.schedule_rounded, data['time']),
                _detailChip(Icons.location_on_rounded, data['location']),
                _detailChip(Icons.category_rounded, data['category']),
                _detailChip(Icons.language_rounded, data['eventMode']),
                _detailChip(Icons.chair_alt_rounded, data['totalSeats'] != null ? '${data['totalSeats']} Seats' : (data['maxSeats'] != null ? '${data['maxSeats']} Seats' : 'N/A Seats')),
                if (data['registrationDeadlineDate'] != null && data['registrationDeadlineDate'].toString().isNotEmpty)
                  _detailChip(Icons.timer_off_rounded, 'Deadline: ${data['registrationDeadlineDate']} ${data['registrationDeadlineTime'] ?? ''}'),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w900)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: isStatusChange 
                              ? [const Color(0xFFF59E0B), const Color(0xFFD97706)] 
                              : [const Color(0xFF10B981), const Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isStatusChange ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => _approveEvent(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: Text(isStatusChange ? 'APPROVE UPDATE' : 'APPROVE EVENT', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.blueAccent),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _convertGoogleDriveLink(String? link) {
    if (link == null || link.isEmpty) return '';
    if (link.contains('.jpg') || link.contains('.jpeg') || link.contains('.png') || link.contains('.gif') || link.contains('.webp')) return link;
    if (link.contains('drive.google.com/uc?export=view')) return link;
    final regex = RegExp(r'(?:drive\.google\.com/file/d/|id=)([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(link);
    if (match != null) {
      final fileId = match.group(1);
      return 'https://drive.google.com/uc?export=view&id=$fileId';
    }
    return link;
  }
}
