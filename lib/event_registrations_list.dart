import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'vibrant_background.dart';

class EventRegistrationsListScreen extends StatefulWidget {
  final String eventId;
  final String eventName;
  final bool isFacultyView;

  const EventRegistrationsListScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    this.isFacultyView = false,
  });

  @override
  State<EventRegistrationsListScreen> createState() => _EventRegistrationsListScreenState();
}

class _EventRegistrationsListScreenState extends State<EventRegistrationsListScreen> {
  Map<String, dynamic> _certSettings = {
    'title': 'CERTIFICATE OF PARTICIPATION',
    'subtitle': 'This is to certify that',
    'body': 'has successfully participated in the event {event} held on {date}.',
    'signatory1Name': 'Event Coordinator',
    'signatory1Title': 'Coordinator',
    'signatory2Name': '',
    'signatory2Title': 'Organizing Club',
    'useLogo': true,
    'bgUrl': '',
  };

  Map<String, dynamic> _winnerSettings = {
    'title': 'CERTIFICATE OF EXCELLENCE',
    'subtitle': 'This is to certify that',
    'body': 'has successfully won {rank} in the event {event} held on {date}.',
    'signatory1Name': 'Event Coordinator',
    'signatory1Title': 'Coordinator',
    'signatory2Name': '',
    'signatory2Title': 'Organizing Club',
    'useLogo': true,
    'bgUrl': '',
  };

  final Map<String, String> _manualWinners = {
    '1st': '',
    '2nd': '',
    '3rd': '',
  };

  bool _isLoadingSettings = true;
  String? _clubId;
  bool _certsApproved = false;
  String _eventStatus = 'approved';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final eventDoc = await FirebaseFirestore.instance.collection('events').doc(widget.eventId).get();
      final eventData = eventDoc.data();
      _clubId = eventData?['clubId'];
      _certsApproved = eventData?['certsApproved'] ?? false;
      _eventStatus = (eventData?['status'] ?? 'approved').toString().toLowerCase();

      if (eventData != null && eventData.containsKey('manualWinners')) {
        final stored = eventData['manualWinners'] as Map<String, dynamic>;
        _manualWinners['1st'] = stored['1st'] ?? '';
        _manualWinners['2nd'] = stored['2nd'] ?? '';
        _manualWinners['3rd'] = stored['3rd'] ?? '';
      }

      if (_clubId != null) {
        final clubDoc = await FirebaseFirestore.instance.collection('clubs').doc(_clubId!).get();
        final clubData = clubDoc.data();
        if (clubData != null) {
          if (clubData.containsKey('certSettings')) {
            _certSettings = Map<String, dynamic>.from(clubData['certSettings']);
          }
          if (clubData.containsKey('winnerSettings')) {
            _winnerSettings = Map<String, dynamic>.from(clubData['winnerSettings']);
          }

          if (!clubData.containsKey('certSettings')) {
            _certSettings['signatory2Name'] = clubData['clubName'] ?? clubData['name'] ?? '';
          }
          if (!clubData.containsKey('winnerSettings')) {
            _winnerSettings['signatory2Name'] = clubData['clubName'] ?? clubData['name'] ?? '';
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingSettings = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_clubId == null) return;
    try {
      await FirebaseFirestore.instance.collection('clubs').doc(_clubId!).update({
        'certSettings': _certSettings,
        'winnerSettings': _winnerSettings,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Templates saved successfully!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving settings: $e")));
    }
  }

  String? _getRankByName(String? name) {
    if (name == null || name.isEmpty) return null;
    final cleanName = name.trim().toLowerCase();
    for (var entry in _manualWinners.entries) {
      if (entry.value.trim().toLowerCase() == cleanName && entry.value.isNotEmpty) {
        return entry.key;
      }
    }
    return null;
  }

  Future<void> _requestUnifiedApproval() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (_clubId == null) return;

      await FirebaseFirestore.instance.collection('certificate_approvals').add({
        'eventId': widget.eventId,
        'eventName': widget.eventName,
        'clubId': _clubId,
        'requestedBy': user?.email,
        'status': 'pending',
        'type': 'event_certificates',
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Certificate approval request sent to faculty!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending for approval: $e")),
      );
    }
  }

  Future<void> _handleFacultyApproval(bool approved) async {
    try {
      final approvalQuery = await FirebaseFirestore.instance
          .collection('certificate_approvals')
          .where('eventId', isEqualTo: widget.eventId)
          .where('status', isEqualTo: 'pending')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      
      for (var doc in approvalQuery.docs) {
        batch.update(doc.reference, {
          'status': approved ? 'approved' : 'rejected',
          'processedAt': FieldValue.serverTimestamp(),
        });
      }

      if (approved) {
        batch.update(FirebaseFirestore.instance.collection('events').doc(widget.eventId), {
          'certsApproved': true,
        });

        final eventDoc = await FirebaseFirestore.instance.collection('events').doc(widget.eventId).get();
        final programId = eventDoc.data()?['programId'];
        if (programId != null && _clubId != null) {
          batch.update(FirebaseFirestore.instance
              .collection('clubs')
              .doc(_clubId!)
              .collection('programs')
              .doc(programId), {'certsApproved': true});
        }
      } else {
        // Handle rejection notification
        if (_clubId != null) {
          final clubDoc = await FirebaseFirestore.instance.collection('clubs').doc(_clubId!).get();
          final coordinatorEmails = List<String>.from(clubDoc.data()?['coordinatorEmails'] ?? []);
          
          for (var email in coordinatorEmails) {
            await FirebaseFirestore.instance.collection('notifications').add({
              'recipientEmail': email,
              'title': 'Certificate Request Rejected',
              'body': 'Your certificate approval request for "${widget.eventName}" was rejected by faculty.',
              'type': 'certificate_rejection',
              'eventId': widget.eventId,
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            });
          }
        }
      }

      await batch.commit();
      
      setState(() {
        _certsApproved = approved;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approved ? "Certificates approved successfully!" : "Request rejected"),
            backgroundColor: approved ? Colors.green : Colors.red,
          ),
        );
        if (!approved) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markAllParticipated(List<QueryDocumentSnapshot> docs, bool value) async {
    if (_certsApproved) return;
    final batch = FirebaseFirestore.instance.batch();
    int count = 0;
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['studentName']?.toString();
      final isWinner = _getRankByName(name) != null;
      if (!isWinner) {
        batch.update(doc.reference, {'participated': value});
        count++;
      }
    }
    if (count > 0) {
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoadingSettings) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text("Registrations", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
          elevation: 0,
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final bool isCompleted = _eventStatus == 'completed';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Registrations", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (!widget.isFacultyView)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.palette_outlined),
                tooltip: "Design Template",
                onPressed: isCompleted ? () => _showDesignDialog() : () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event must be COMPLETED to design certificates")));
                },
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          const VibrantBackground(),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('registrations')
                .where('eventId', isEqualTo: widget.eventId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data?.docs ?? [];
              final winners = docs.where((d) => _getRankByName((d.data() as Map<String, dynamic>)['studentName']) != null).toList();
              final participants = docs.where((d) => _getRankByName((d.data() as Map<String, dynamic>)['studentName']) == null).toList();

              winners.sort((a, b) {
                final aRank = _getRankByName((a.data() as Map<String, dynamic>)['studentName']) ?? 'zzz';
                final bRank = _getRankByName((b.data() as Map<String, dynamic>)['studentName']) ?? 'zzz';
                return aRank.compareTo(bRank);
              });

              participants.sort((a, b) {
                final aName = (a.data() as Map<String, dynamic>)['studentName']?.toString() ?? '';
                final bName = (b.data() as Map<String, dynamic>)['studentName']?.toString() ?? '';
                return aName.compareTo(bName);
              });

              return Column(
                children: [
                  _buildStatsHeader(winners.length, participants.length),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildSectionHeader(
                          "Event Winners", 
                          Icons.emoji_events_rounded, 
                          Colors.orange.shade700, 
                          action: !widget.isFacultyView && isCompleted ? () => _showWinnersDialog() : null,
                          showGenerateAll: winners.isNotEmpty
                        ),
                        if (winners.isEmpty)
                          _buildEmptyState("No winners announced yet", "Tap 'Set Winners' to assign ranks")
                        else ...[
                          ...winners.map((doc) => _buildStudentCard(doc, isWinner: true, isCompleted: isCompleted)),
                        ],
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Icon(Icons.people_alt_rounded, color: Colors.grey, size: 20),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                        ),

                        _buildSectionHeader(
                          "General Participants", 
                          Icons.groups_rounded, 
                          theme.primaryColor,
                          showGenerateAll: participants.isNotEmpty
                        ),
                        if (participants.isEmpty)
                          _buildEmptyState("No participants registered", "Wait for students to sign up")
                        else ...[
                          if (!widget.isFacultyView && !_certsApproved)
                            _buildBulkActionRow(participants, isCompleted, docs),
                          const SizedBox(height: 12),
                          ...participants.map((doc) => _buildStudentCard(doc, isWinner: false, isCompleted: isCompleted)),
                        ],
                      ],
                    ),
                  ),
                  if (isCompleted) _buildVerificationFooter(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(int winnersCount, int participantsCount) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.eventName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.elasticOut).shimmer(duration: 2.seconds, color: Colors.white24),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("Winners", winnersCount.toString(), Colors.orange.shade300).animate().fadeIn(delay: 400.ms).slideX(begin: -0.2),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
              _buildStatItem("Total Registrations", (winnersCount + participantsCount).toString(), Colors.white).animate().fadeIn(delay: 400.ms).slideX(begin: 0.2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color, letterSpacing: -1)),
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w800, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, {VoidCallback? action, bool showGenerateAll = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const Spacer(),
          if (showGenerateAll && !widget.isFacultyView && _eventStatus == 'completed') ...[
            _buildActionChip(title == "Event Winners"),
          ],
          if (action != null) ...[
            const SizedBox(width: 8),
            _buildSmallActionButton(
              onPressed: action,
              label: _certsApproved ? "VIEW" : "SET WINNERS",
              color: Colors.orange.shade700,
              icon: _certsApproved ? Icons.visibility : Icons.add_circle,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallActionButton({required VoidCallback onPressed, required String label, required Color color, required IconData icon}) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip(bool isWinner) {
    final color = isWinner ? Colors.orange.shade700 : Colors.green.shade700;
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _handleGenerateAll(isWinner),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 14, color: color),
              const SizedBox(width: 6),
              const Text("GENERATE ALL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulkActionRow(List<QueryDocumentSnapshot> list, bool isCompleted, List<QueryDocumentSnapshot> allDocs) {
    final bool allParticipated = list.every((d) => (d.data() as Map<String, dynamic>)['participated'] == true);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: CheckboxListTile(
        value: allParticipated,
        activeColor: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Mark all as participated", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: const Text("Checking this enables certificates for everyone", style: TextStyle(fontSize: 11)),
        onChanged: isCompleted ? (val) { if (val != null) _markAllParticipated(allDocs, val); } : null,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildStudentCard(QueryDocumentSnapshot doc, {required bool isWinner, bool isCompleted = false}) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['studentName']?.toString() ?? 'Unknown';
    final rank = _getRankByName(name);
    final bool participated = data['participated'] ?? false;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
        collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildLeading(doc, isWinner, participated, isCompleted),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.3)),
        subtitle: Row(
          children: [
            if (rank != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.orange.shade700, Colors.orange.shade400]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(rank, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (participated || isWinner) ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isWinner ? "WINNER" : (participated ? "PARTICIPATED" : "REGISTERED"), 
                style: TextStyle(
                  fontSize: 9, 
                  color: (participated || isWinner) ? Colors.green.shade700 : Colors.grey.shade700, 
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5
                ),
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          const SizedBox(height: 12),
          _buildDetailGrid(data),
          if (!widget.isFacultyView && isCompleted && (participated || isWinner)) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleGenerateIndividual(doc, isWinner),
                icon: Icon(isWinner ? Icons.emoji_events : Icons.card_membership, size: 18),
                label: Text("GENERATE ${isWinner ? 'WINNER' : 'PARTICIPATION'} CERTIFICATE"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isWinner ? Colors.orange.shade700 : Colors.green.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05, curve: Curves.easeOutQuad);
  }

  Widget _buildDetailGrid(Map<String, dynamic> data) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 12,
      ),
      children: [
        _buildDetailItem(Icons.badge_outlined, "KTU ID", data['ktuId'] ?? 'N/A'),
        _buildDetailItem(Icons.school_outlined, "College", data['college'] ?? 'N/A'),
        _buildDetailItem(Icons.email_outlined, "Email", data['studentEmail'] ?? 'N/A'),
      ],
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeading(QueryDocumentSnapshot doc, bool isWinner, bool participated, bool isCompleted) {
    if (!isWinner && !widget.isFacultyView && !_certsApproved) {
      return Transform.scale(
        scale: 1.2,
        child: Checkbox(
          value: participated,
          activeColor: Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          onChanged: isCompleted ? (val) {
            FirebaseFirestore.instance.collection('registrations').doc(doc.id).update({'participated': val});
          } : null,
        ),
      );
    }
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: (isWinner || participated) ? Colors.green.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        isWinner ? Icons.workspace_premium_rounded : (participated ? Icons.verified_rounded : Icons.person_outline_rounded),
        color: (isWinner || participated) ? Colors.green.shade700 : Colors.grey.shade400,
        size: 24,
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.layers_clear_outlined, size: 48, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildVerificationFooter() {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('events').doc(widget.eventId).snapshots(),
        builder: (context, eventSnap) {
          final bool isApproved = (eventSnap.data?.data() as Map<String, dynamic>?)?['certsApproved'] == true;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: isApproved 
                  ? _buildVerifiedState()
                  : (widget.isFacultyView ? _buildFacultyApprovalBar() : _buildCoordinatorRequestBar()),
              ),
            ),
          );
        }
    );
  }

  Widget _buildVerifiedState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade400]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_rounded, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Text("CERTIFICATES VERIFIED BY FACULTY", 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyApprovalBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('certificate_approvals')
          .where('eventId', isEqualTo: widget.eventId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        bool isPending = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        if (!isPending) return const SizedBox.shrink();

        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _handleFacultyApproval(false),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text("REJECT", style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _handleFacultyApproval(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("VERIFY & APPROVE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCoordinatorRequestBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('certificate_approvals')
          .where('eventId', isEqualTo: widget.eventId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        bool isPending = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        return isPending
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.orange.shade700)),
                  const SizedBox(width: 12),
                  Text("PENDING FACULTY VERIFICATION", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.orange.shade800, fontSize: 13)),
                ],
              ),
            )
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _requestUnifiedApproval(),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text("REQUEST FACULTY VERIFICATION"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)
                ),
              ),
            );
      },
    );
  }

  void _showDesignDialog() {
    showDialog(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          title: const Text("Certificate Design", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          content: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TabBar(
                  tabs: const [Tab(text: "Participation"), Tab(text: "Winners")],
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorWeight: 4,
                  indicatorColor: Theme.of(context).primaryColor,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: TabBarView(
                    children: [
                      _buildTemplateForm(_certSettings, (val) => setState(() => _certSettings = val)),
                      _buildTemplateForm(_winnerSettings, (val) => setState(() => _winnerSettings = val)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.all(24),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: Text("Cancel", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w800))
            ),
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _saveSettings(); },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateForm(Map<String, dynamic> settings, Function(Map<String, dynamic>) onUpdate) {
    final titleCtrl = TextEditingController(text: settings['title'] ?? '');
    final subtitleCtrl = TextEditingController(text: settings['subtitle'] ?? '');
    final bodyCtrl = TextEditingController(text: settings['body'] ?? '');
    final sig1NameCtrl = TextEditingController(text: settings['signatory1Name'] ?? '');
    final sig1TitleCtrl = TextEditingController(text: settings['signatory1Title'] ?? '');
    final sig2NameCtrl = TextEditingController(text: settings['signatory2Name'] ?? '');
    final sig2TitleCtrl = TextEditingController(text: settings['signatory2Title'] ?? '');
    final bgUrlCtrl = TextEditingController(text: settings['bgUrl'] ?? '');
    bool useLogo = settings['useLogo'] ?? true;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDesignField(titleCtrl, "Certificate Title", Icons.title, (v) => settings['title'] = v),
          _buildDesignField(subtitleCtrl, "Certification Text", Icons.subtitles, (v) => settings['subtitle'] = v),
          _buildDesignField(bodyCtrl, "Main Content Body", Icons.text_fields, (v) => settings['body'] = v, maxLines: 3),
          const SizedBox(height: 24),
          const Text("SIGNATORIES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          _buildDesignField(sig1NameCtrl, "Signatory 1 Name", Icons.person, (v) => settings['signatory1Name'] = v),
          _buildDesignField(sig1TitleCtrl, "Signatory 1 Title", Icons.work, (v) => settings['signatory1Title'] = v),
          const SizedBox(height: 12),
          _buildDesignField(sig2NameCtrl, "Signatory 2 Name", Icons.person, (v) => settings['signatory2Name'] = v),
          _buildDesignField(sig2TitleCtrl, "Signatory 2 Title", Icons.work, (v) => settings['signatory2Title'] = v),
          const SizedBox(height: 24),
          const Text("BACKGROUND \u0026 LOGO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          _buildDesignField(bgUrlCtrl, "Background Image URL", Icons.image_search, (v) => settings['bgUrl'] = v),
          SwitchListTile(
            title: const Text("Include Club Logo", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            value: useLogo,
            activeColor: Theme.of(context).primaryColor,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) { setState(() { settings['useLogo'] = v; useLogo = v; }); },
          ),
          const SizedBox(height: 100), // Spacing for scroll
        ],
      ),
    );
  }

  Widget _buildDesignField(TextEditingController ctrl, String label, IconData icon, Function(String) onChange, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        onChanged: onChange,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w800),
          prefixIcon: Icon(icon, size: 20, color: Colors.grey[400]),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  void _handleGenerateAll(bool isWinnerList) {
    if (!_certsApproved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Certificates must be approved by faculty first.")));
      return;
    }
    
    FirebaseFirestore.instance
        .collection('registrations')
        .where('eventId', isEqualTo: widget.eventId)
        .get()
        .then((snapshot) {
      final docs = snapshot.docs;
      final eligible = docs.where((doc) {
        final d = doc.data();
        final name = d['studentName']?.toString();
        final isWinner = _getRankByName(name) != null;
        if (isWinnerList) return isWinner;
        return (d['participated'] == true) && !isWinner;
      }).toList();

      if (eligible.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No eligible ${isWinnerList ? 'winners' : 'participants'} found.")));
      } else {
        _generateCertificatesFromDocs(eligible, isWinner: isWinnerList);
      }
    });
  }

  void _handleGenerateIndividual(QueryDocumentSnapshot doc, bool isWinner) {
    if (!_certsApproved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Not approved by faculty")));
      return;
    }
    _generateCertificatesFromDocs([doc], isWinner: isWinner);
  }

  void _generateCertificatesFromDocs(List<QueryDocumentSnapshot> studentDocs, {required bool isWinner}) {
    List<Map<String, String>> data = studentDocs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final name = d['studentName']?.toString() ?? 'PARTICIPANT';
      final rank = _getRankByName(name) ?? 'participant';
      return {'name': name, 'rank': rank};
    }).toList();
    _generateCertificatesBase(data, isWinner: isWinner);
  }

  Future<void> _generateCertificatesBase(List<Map<String, String>> items, {required bool isWinner}) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: Card(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Generating PDF...", style: TextStyle(fontWeight: FontWeight.bold))])))));
    try {
      final pdf = pw.Document();
      final eventDoc = await FirebaseFirestore.instance.collection('events').doc(widget.eventId).get();
      final eventData = eventDoc.data() ?? {};
      final eventDate = eventData['date'] ?? "TBD";
      final activeSettings = isWinner ? _winnerSettings : _certSettings;
      pw.MemoryImage? logoImg; pw.MemoryImage? sig1Img; pw.MemoryImage? sig2Img;
      if (_clubId != null) {
        final clubDoc = await FirebaseFirestore.instance.collection('clubs').doc(_clubId!).get();
        final clubData = clubDoc.data();
        if (clubData != null) {
          if (activeSettings['useLogo'] == true && clubData['profilePic'] != null) logoImg = await _loadNetworkImage(clubData['profilePic']);
          if (clubData['signatureUrl'] != null) sig1Img = await _loadNetworkImage(clubData['signatureUrl']);
          if (clubData['facultySignatureUrl'] != null) sig2Img = await _loadNetworkImage(clubData['facultySignatureUrl']);
        }
      }
      pw.MemoryImage? bgImg;
      if (activeSettings['bgUrl'].toString().isNotEmpty) bgImg = await _loadNetworkImage(activeSettings['bgUrl']);
      for (var item in items) {
        final studentName = item['name']!.toUpperCase();
        final rankValue = item['rank']!;
        pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4.landscape, margin: pw.EdgeInsets.zero, build: (pw.Context context) {
          return pw.Stack(children: [
            if (bgImg != null) pw.Positioned.fill(child: pw.Image(bgImg!, fit: pw.BoxFit.fill)),
            pw.Container(margin: const pw.EdgeInsets.all(40), padding: const pw.EdgeInsets.all(20), decoration: bgImg == null ? pw.BoxDecoration(border: pw.Border.all(color: isWinner ? PdfColors.orange : PdfColors.indigo, width: 5)) : null, child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
              if (logoImg != null) pw.Container(height: 70, width: 70, child: pw.Image(logoImg!)),
              pw.SizedBox(height: 10),
              pw.Text(activeSettings['title'], style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: bgImg == null ? (isWinner ? PdfColors.orange : PdfColors.indigo) : PdfColors.black)),
              pw.SizedBox(height: 10),
              pw.Text(activeSettings['subtitle'], style: const pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 15),
              pw.Text(studentName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
              pw.SizedBox(height: 15),
              _buildBodyText(activeSettings['body'], widget.eventName, eventDate, rankValue),
              pw.SizedBox(height: 30),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Column(children: [if (sig1Img != null) pw.Container(height: 40, width: 100, child: pw.Image(sig1Img!)), pw.Container(width: 140, height: 1, color: PdfColors.black), pw.Text(activeSettings['signatory1Name'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(activeSettings['signatory1Title'], style: const pw.TextStyle(fontSize: 10))]),
                pw.Column(children: [if (sig2Img != null) pw.Container(height: 40, width: 100, child: pw.Image(sig2Img!)), pw.Container(width: 140, height: 1, color: PdfColors.black), pw.Text(activeSettings['signatory2Name'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(activeSettings['signatory2Title'], style: const pw.TextStyle(fontSize: 10))]),
              ]),
            ])),
          ]);
        }));
      }
      Navigator.pop(context);
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/certs_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) { Navigator.pop(context); }
  }

  pw.Widget _buildBodyText(String template, String eventName, String date, String rank) {
    String text = template.replaceAll('{event}', eventName).replaceAll('{date}', date).replaceAll('{rank}', rank);
    return pw.Text(text, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 16));
  }

  Future<pw.MemoryImage?> _loadNetworkImage(String url) async {
    try {
      final response = await http.get(Uri.parse(_convertGoogleDriveLink(url)));
      if (response.statusCode == 200) return pw.MemoryImage(response.bodyBytes);
      return null;
    } catch (e) { return null; }
  }

  String _convertGoogleDriveLink(String link) {
    if (link.isEmpty) return '';
    final regex = RegExp(r'(?:drive\.google\.com/file/d/|id=)([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(link);
    if (match != null) return 'https://drive.google.com/uc?export=view&id=${match.group(1)}';
    return link;
  }

  void _showWinnersDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final snap = await FirebaseFirestore.instance
          .collection('registrations')
          .where('eventId', isEqualTo: widget.eventId)
          .where('participated', isEqualTo: true)
          .get();

      if (!mounted) return;
      Navigator.pop(context);

      final participants = snap.docs
          .map((d) => (d.data() as Map<String, dynamic>)['studentName']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList();
      participants.sort();

      String? s1 = _manualWinners['1st'];
      String? s2 = _manualWinners['2nd'];
      String? s3 = _manualWinners['3rd'];

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Text((_certsApproved || widget.isFacultyView) ? "Winners List" : "Announce Winners", style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            content: Container(
              width: MediaQuery.of(context).size.width,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Select the top performers from the participants list to announce results.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 24),
                    IgnorePointer(
                      ignoring: _certsApproved || widget.isFacultyView,
                      child: Opacity(
                        opacity: (_certsApproved || widget.isFacultyView) ? 0.7 : 1.0,
                        child: Column(
                          children: [
                            _buildWinnerDropdown("1st Place", Colors.amber.shade700, participants, s1, (val) => setDialogState(() => s1 = val)),
                            const SizedBox(height: 16),
                            _buildWinnerDropdown("2nd Place", Colors.blueGrey.shade700, participants, s2, (val) => setDialogState(() => s2 = val)),
                            const SizedBox(height: 16),
                            _buildWinnerDropdown("3rd Place", Colors.brown.shade700, participants, s3, (val) => setDialogState(() => s3 = val)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Close", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w800))),
              if (!(_certsApproved || widget.isFacultyView))
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _manualWinners['1st'] = s1 ?? '';
                      _manualWinners['2nd'] = s2 ?? '';
                      _manualWinners['3rd'] = s3 ?? '';
                    });
                    FirebaseFirestore.instance.collection('events').doc(widget.eventId).update({
                      'manualWinners': _manualWinners,
                    }).then((_) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Winners saved!")));
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text("Save Results", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching participants: $e")));
      }
    }
  }

  Widget _buildWinnerDropdown(String label, Color iconColor, List<String> options, String? currentValue, Function(String?) onChanged) {
    String? value = (currentValue != null && options.contains(currentValue)) ? currentValue : null;
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: iconColor, fontWeight: FontWeight.w900, fontSize: 13),
        prefixIcon: Icon(Icons.workspace_premium, color: iconColor, size: 20),
        filled: true,
        fillColor: iconColor.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: iconColor, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w700),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text("Not Assigned", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ...options.map((name) => DropdownMenuItem<String>(value: name, child: Text(name, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis))),
      ],
      onChanged: onChanged,
    );
  }
}
