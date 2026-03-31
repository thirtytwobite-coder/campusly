// Event Registrations and Certificate Workflow
// ------------------------------------------------
// This screen is used by club coordinators (and faculty view) to:
// - list registrations for an event
// - display winners and participants
// - mark participation status
// - set winners via manual winner assignment
// - assign volunteer tasks for volunteer registrants
// - request certificate approval and generate certificates

import 'dart:io';
import 'dart:ui';
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
import 'dart:convert';

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
    // Initialize screen state by loading event and club certificate settings
    _loadSettings();
  }

  /// Load event and club settings needed for certificate UI and behavior.
  ///
  /// - `certsApproved` controls whether certificate actions are editable.
  /// - `isTeamEvent` affects winner selection by team.
  /// - `manualWinners` maps 1st/2nd/3rd names.
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

  /// Request faculty approval for event certificates.
  ///
  /// Creates a `certificate_approvals` doc in Firestore with `status='pending'`.
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

  Future<void> _generateEventReport() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Generating Report...", style: TextStyle(fontWeight: FontWeight.bold))
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final registrationsSnap = await FirebaseFirestore.instance
          .collection('registrations')
          .where('eventId', isEqualTo: widget.eventId)
          .get();

      final eventDoc = await FirebaseFirestore.instance.collection('events').doc(widget.eventId).get();
      final eventData = eventDoc.data() ?? {};
      final eventDate = eventData['date'] ?? "TBD";

      final pdf = pw.Document();

      final headers = ['Name', 'KTU ID', 'College', 'Status'];
      final data = registrationsSnap.docs.map((doc) {
        final d = doc.data();
        final name = d['studentName']?.toString() ?? 'N/A';
        final ktuId = d['ktuId']?.toString() ?? 'N/A';
        final college = d['college']?.toString() ?? 'N/A';
        
        final rank = _getRankByName(name);
        String status = 'Registered';
        if (rank != null) {
          status = "Winner ($rank)";
        } else if (d['participated'] == true) {
          status = 'Participated';
        }
        
        return [name, ktuId, college, status];
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(widget.eventName.toUpperCase(), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text("Date: $eventDate", style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 8),
              pw.Text("PARTICIPATION & WINNERS REPORT", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 16),
            ],
          ),
          footer: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          ),
          build: (pw.Context context) => [
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
              },
            ),
          ],
        ),
      );

      Navigator.pop(context);
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/Report_${widget.eventName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error generating report: $e")));
      }
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Registrations", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: "Export Report",
            onPressed: _generateEventReport,
          ),
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
                  _buildStatsHeader(context, winners.length, participants.length),
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

  Widget _buildStatsHeader(BuildContext context, int winnersCount, int participantsCount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = winnersCount + participantsCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
      child: GlassCard(
        borderRadius: 30,
        blur: 25,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                widget.eventName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  height: 1.1,
                ),
              ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.2),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem("Winners", winnersCount.toString(), Colors.orangeAccent, isDark),
                  Container(
                    width: 1,
                    height: 40,
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                  _buildStatItem("Total Registrations", total.toString(), isDark ? Colors.white70 : Colors.blue.shade700, isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildStatItem(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -1.0,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.white38 : Colors.black45,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, {VoidCallback? action, bool showGenerateAll = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, spreadRadius: -2),
                  ],
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      title == "Event Winners" ? "RECOGNIZING EXCELLENCE" : "COMMUNITY BUILDING",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: color.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (showGenerateAll && !widget.isFacultyView && _eventStatus == 'completed') ...[
                _buildActionChip(title == "Event Winners"),
              ],
              if (action != null) ...[
                const SizedBox(width: 8),
                _buildSmallActionButton(
                  onPressed: action,
                  label: _certsApproved ? "VIEW" : "SET WINNERS",
                  color: Colors.orange.shade800,
                  icon: _certsApproved ? Icons.visibility_rounded : Icons.add_circle_outline_rounded,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallActionButton({required VoidCallback onPressed, required String label, required Color color, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip(bool isWinner) {
    final color = isWinner ? Colors.orange.shade800 : Colors.green.shade800;
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _handleGenerateAll(isWinner),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: color),
              const SizedBox(width: 8),
              Text(
                "GENERATE ALL",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulkActionRow(List<QueryDocumentSnapshot> list, bool isCompleted, List<QueryDocumentSnapshot> allDocs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool allParticipated = list.every((d) => (d.data() as Map<String, dynamic>)['participated'] == true);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.white),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: CheckboxListTile(
            value: allParticipated,
            activeColor: Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            tileColor: Colors.transparent,
            title: Text(
              "Mark all as participated",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              "Checking this enables certificates for everyone",
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            onChanged: isCompleted ? (val) { if (val != null) _markAllParticipated(allDocs, val); } : null,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(QueryDocumentSnapshot doc, {required bool isWinner, bool isCompleted = false}) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['studentName']?.toString() ?? 'Unknown';
    final rank = _getRankByName(name);
    final bool participated = data['participated'] ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white12 : Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ExpansionTile(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
            collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: _buildLeading(doc, isWinner, participated, isCompleted),
            title: Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 8,
                children: [
                  if (rank != null && !isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF8C00), Color(0xFFFFA500)]),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        rank.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: (participated || isWinner) ? Colors.green.withOpacity(0.12) : (isDark ? Colors.white10 : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: (participated || isWinner) ? Colors.green.withOpacity(0.2) : Colors.transparent),
                    ),
                    child: Text(
                      isWinner ? "WINNER" : (participated ? "PARTICIPATED" : "REGISTERED"),
                      style: TextStyle(
                        fontSize: 9,
                        color: (participated || isWinner) ? (isDark ? Colors.greenAccent : Colors.green.shade700) : (isDark ? Colors.white38 : Colors.grey.shade600),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (data['registrationType']?.toString().toLowerCase() == 'volunteer')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volunteer_activism_rounded, size: 10, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            "VOLUNTEER",
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            iconColor: isDark ? Colors.white70 : Colors.black54,
            collapsedIconColor: isDark ? Colors.white38 : Colors.black38,
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Divider(color: isDark ? Colors.white10 : Colors.black12),
              const SizedBox(height: 16),
              _buildDetailGrid(data),
              if (data['registrationType']?.toString().toLowerCase() == 'volunteer') ...[
                const SizedBox(height: 16),
                _buildVolunteerSection(doc, data),
              ],
              if (!widget.isFacultyView && isCompleted && (participated || isWinner)) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleGenerateIndividual(doc, isWinner),
                    icon: Icon(isWinner ? Icons.emoji_events_rounded : Icons.card_membership_rounded, size: 18),
                    label: Text("GENERATE ${isWinner ? 'WINNER' : 'PARTICIPATION'} CERTIFICATE"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isWinner ? Colors.orange.shade800 : Colors.green.shade800,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 12, color: isDark ? Colors.white38 : Colors.black38),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(fontSize: 8, color: isDark ? Colors.white38 : Colors.grey[500], fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVolunteerSection(QueryDocumentSnapshot doc, Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final studentName = data['studentName']?.toString() ?? 'Unknown';
    final assignedTask = data['assignedTask']?.toString() ?? '';
    final registrationType = data['registrationType']?.toString().toLowerCase() ?? '';
    
    // Only show if user is a volunteer
    if (registrationType != 'volunteer') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.volunteer_activism_rounded, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  "Volunteer Assignment",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            if (!widget.isFacultyView && !_certsApproved)
              GestureDetector(
                onTap: () => _showAssignTaskDialog(doc, data),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 12, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        assignedTask.isEmpty ? "Assign" : "Update",
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (assignedTask.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text("Task Assigned", style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  assignedTask,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "No task assigned yet",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _showAssignTaskDialog(QueryDocumentSnapshot doc, Map<String, dynamic> data) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final studentName = data['studentName']?.toString() ?? 'Unknown';
    final currentTask = data['assignedTask']?.toString() ?? '';
    final taskController = TextEditingController(text: currentTask);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Assign Volunteer Task", style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              "For: $studentName",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.grey[600]),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: taskController,
                maxLines: 4,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: "Describe the volunteer task (e.g., 'Setup decoration', 'Manage registration desk', etc.)",
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                  fillColor: isDark ? Colors.white10 : Colors.grey[100],
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              final task = taskController.text.trim();
              if (task.isNotEmpty) {
                try {
                  await doc.reference.update({'assignedTask': task});
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Task assigned successfully!")),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e")),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a task description")),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Assign Task", style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildLeading(QueryDocumentSnapshot doc, bool isWinner, bool participated, bool isCompleted) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isWinner && !widget.isFacultyView && !_certsApproved) {
      return Container(
        decoration: BoxDecoration(
          color: participated ? Colors.green.withOpacity(0.12) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Checkbox(
          value: participated,
          activeColor: Colors.green.shade600,
          checkColor: Colors.white,
          side: BorderSide(color: isDark ? Colors.white38 : Colors.black26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          onChanged: isCompleted ? (val) {
            FirebaseFirestore.instance.collection('registrations').doc(doc.id).update({'participated': val});
          } : null,
        ),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: (isWinner || participated) ? Colors.green.withOpacity(0.12) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isWinner || participated) ? Colors.green.withOpacity(0.2) : Colors.transparent),
      ),
      child: Icon(
        isWinner ? Icons.workspace_premium_rounded : (participated ? Icons.verified_rounded : Icons.person_outline_rounded),
        color: (isWinner || participated) ? (isDark ? Colors.greenAccent : Colors.green.shade700) : (isDark ? Colors.white38 : Colors.grey.shade400),
        size: 24,
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: GlassCard(
        borderRadius: 32,
        blur: 15,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.blue).withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: (isDark ? Colors.white : Colors.blue).withOpacity(0.1), width: 2),
                ),
                child: Icon(
                  Icons.auto_awesome_motion_rounded,
                  size: 52,
                  color: isDark ? Colors.white24 : Colors.blue.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildVerificationFooter() {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('events').doc(widget.eventId).snapshots(),
        builder: (context, eventSnap) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final bool isApproved = (eventSnap.data?.data() as Map<String, dynamic>?)?['certsApproved'] == true;

          return Container(
            decoration: BoxDecoration(
              color: isApproved ? Colors.transparent : (isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.7)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5)),
              ],
            ),
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: isApproved
                        ? _buildVerifiedState()
                        : (widget.isFacultyView ? _buildFacultyApprovalBar() : _buildCoordinatorRequestBar()),
                  ),
                ),
              ),
            ),
          );
        }
    );
  }

  Widget _buildVerifiedState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_rounded, color: Colors.white, size: 28),
          SizedBox(width: 14),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("OFFICIALLY VERIFIED",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)
              ),
              Text("Certificates are ready for students",
                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)
              ),
            ],
          ),
        ],
      ),
    ).animate().scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack).fadeIn();
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
                  side: BorderSide(color: Colors.red.withOpacity(0.3), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  foregroundColor: Colors.red.shade400,
                ),
                child: const Text("REJECT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _handleFacultyApproval(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  shadowColor: Colors.green.withOpacity(0.4),
                ).copyWith(elevation: ButtonStyleButton.allOrNull(0)),
                child: const Text("VERIFY & APPROVE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCoordinatorRequestBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.orange.shade700,
                        backgroundColor: Colors.orange.withOpacity(0.1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "PENDING FACULTY VERIFICATION",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.orange.shade800,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Text(
                          "This usually takes 24-48 hours",
                          style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _requestUnifiedApproval(),
                    icon: const Icon(Icons.send_rounded, size: 20),
                    label: const Text(
                      "REQUEST FACULTY VERIFICATION",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ).copyWith(elevation: ButtonStyleButton.allOrNull(0)),
                  ),
                ),
              );
      },
    );
  }

  void _showDesignDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => DefaultTabController(
        length: 2,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Material(
                  color: isDark ? Colors.black.withOpacity(0.85) : Colors.white.withOpacity(0.95),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                "Certificate Design",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded),
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TabBar(
                          tabs: const [Tab(text: "Participation"), Tab(text: "Winners")],
                          labelColor: Colors.blueAccent,
                          unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
                          indicatorWeight: 4,
                          indicatorSize: TabBarIndicatorSize.label,
                          indicatorColor: Colors.blueAccent,
                          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          indicatorPadding: const EdgeInsets.only(top: 40),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildTemplateForm(_certSettings, (val) => setState(() => _certSettings = val)),
                              _buildTemplateForm(_winnerSettings, (val) => setState(() => _winnerSettings = val)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                                ),
                                child: Text("CANCEL", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () { Navigator.pop(ctx); _saveSettings(); },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  elevation: 0,
                                ),
                                child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: anim1.drive(CurveTween(curve: Curves.easeOutBack)),
          child: child,
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

  /// Shows a dialog letting the coordinator assign 1st/2nd/3rd winners.
  ///
  /// It reads all registered participants, allows search, and updates event `manualWinners`.
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

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (ctx, anim1, anim2) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Center(
            child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 15)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Material(
                  color: isDark ? Colors.black.withOpacity(0.85) : Colors.white.withOpacity(0.95),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    padding: const EdgeInsets.all(24),
                    child: StatefulBuilder(
                      builder: (context, setDialogState) => SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    (_certsApproved || widget.isFacultyView) ? "Winners List" : "Announce Winners",
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -1),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  icon: const Icon(Icons.close_rounded),
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Select the top performers from the participants list to announce results.",
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black54),
                            ),
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
                            const SizedBox(height: 24),
                            if (!(_certsApproved || widget.isFacultyView))
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
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
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    elevation: 0,
                                  ),
                                  child: const Text("SAVE RESULTS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
        transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: anim1.drive(CurveTween(curve: Curves.easeOutBack)),
            child: child,
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

  void _showStudentProfilePopup(BuildContext context, String userId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('student').doc(userId).get(),
          builder: (context, snapshot) {
            String name = "Loading...";
            String photo = "";
            String college = "N/A";
            String year = "N/A";
            String department = "N/A";
            String semester = "N/A";
            String ktuId = "N/A";
            bool isReady = false;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              name = data['name'] ?? 'Unknown Student';
              photo = data['profilePic'] ?? '';
              college = data['college'] ?? 'N/A';
              year = data['year']?.toString() ?? 'N/A';
              department = data['department'] ?? 'N/A';
              semester = data['semester']?.toString() ?? 'N/A';
              ktuId = data['ktuId'] ?? 'N/A';
              isReady = true;
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryColor = Theme.of(context).primaryColor;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Background
                      Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor.withOpacity(0.8),
                                  primaryColor.withOpacity(0.4),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 60,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: primaryColor.withOpacity(0.2),
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: photo.isNotEmpty
                                          ? (photo.startsWith('data:image')
                                              ? Image.memory(base64Decode(photo.split(',').last), fit: BoxFit.cover)
                                              : Image.network(photo, fit: BoxFit.cover))
                                          : Container(
                                              color: primaryColor.withOpacity(0.1),
                                              child: Icon(Icons.person_rounded, color: primaryColor, size: 60),
                                            ),
                                    ),
                                  ),
                                  if (!isReady)
                                    const SizedBox(
                                      width: 120,
                                      height: 120,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 65),
                      
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                        child: Column(
                          children: [
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildBadge(department, Colors.blue),
                                const SizedBox(width: 8),
                                _buildBadge("Year $year", Colors.orange),
                              ],
                            ),
                            const SizedBox(height: 28),
                            
                            _buildInfoRow(Icons.school_rounded, "College", college, isDark),
                            const SizedBox(height: 16),
                            _buildInfoRow(Icons.history_rounded, "Semester", "Semester $semester", isDark),
                            
                            const SizedBox(height: 36),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  "CLOSE",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: anim1.drive(CurveTween(curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlight 
            ? (isDark ? Colors.blueAccent.withOpacity(0.1) : Colors.blue.withOpacity(0.05))
            : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlight 
              ? (isDark ? Colors.blueAccent.withOpacity(0.2) : Colors.blue.withOpacity(0.1))
              : (isDark ? Colors.white10 : Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHighlight ? Colors.blue.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: isHighlight ? Colors.blue : Colors.grey[400]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    color: isHighlight ? Colors.blue.withOpacity(0.7) : Colors.grey,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? (isHighlight ? Colors.blueAccent : Colors.white) : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}