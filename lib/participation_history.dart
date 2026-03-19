import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'feedback_screen.dart';

class ParticipationHistoryScreen extends StatelessWidget {
  const ParticipationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        title: const Text("My Awards & History", style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('registrations')
            .where('userId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "No achievements yet",
                    style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Participate in events to earn certificates!",
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms);
          }

          final registrations = snapshot.data!.docs;

          return ListView.builder(
            itemCount: registrations.length,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemBuilder: (context, index) {
              final regDoc = registrations[index];
              final reg = regDoc.data() as Map<String, dynamic>;
              final eventId = reg['eventId'];
              
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('events').doc(eventId).get(),
                builder: (context, eventSnap) {
                  if (!eventSnap.hasData) {
                    return Container(
                      height: 100,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }

                  final eventData = eventSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final bool isApproved = eventData['certsApproved'] == true;
                  final bool didParticipate = reg['participated'] == true;
                  final winners = eventData['manualWinners'] as Map<String, dynamic>? ?? {};
                  
                  String? userRank;
                  winners.forEach((key, value) {
                    if (value.toString().trim().toLowerCase() == reg['studentName']?.toString().toLowerCase().trim()) {
                      userRank = key;
                    }
                  });

                  final bool eligible = didParticipate || userRank != null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        onTap: (isApproved && eligible)
                            ? () => _generateUserCertificate(context, reg, eventData, userRank)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: (userRank != null ? Colors.orange : Theme.of(context).primaryColor).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      userRank != null ? Icons.workspace_premium : Icons.event_available, 
                                      color: userRank != null ? Colors.orange : Theme.of(context).primaryColor,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          reg['eventTitle'] ?? 'Event Name', 
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.5)
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          eventData['college'] ?? 'Club Event',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isApproved && eligible)
                                    const Icon(Icons.download_for_offline_rounded, color: Colors.green, size: 32)
                                  else if (isApproved && !eligible)
                                    Icon(Icons.info_outline_rounded, color: Colors.red[300], size: 24)
                                  else
                                    Icon(Icons.lock_clock_rounded, color: Colors.orange[300], size: 24),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _statusBadge(
                                    userRank != null 
                                      ? "WINNER ($userRank)" 
                                      : (didParticipate ? "PARTICIPANT" : "REGISTERED"),
                                    userRank != null 
                                      ? Colors.orange 
                                      : (didParticipate ? Colors.green : Colors.blue)
                                  ),
                                  if (!isApproved && eligible)
                                    Text(
                                      "Pending Verification",
                                      style: TextStyle(fontSize: 11, color: Colors.orange[700], fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
                                    ),
                                  if (isApproved && !eligible)
                                    Text(
                                      "No Participation Record",
                                      style: TextStyle(fontSize: 11, color: Colors.red[700], fontWeight: FontWeight.w600),
                                    ),
                                ],
                              ),
                              if (eligible) ...[
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: reg['rating'] != null 
                                      ? null 
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => FeedbackScreen(
                                                registrationRef: regDoc.reference,
                                                eventTitle: reg['eventTitle'] ?? 'Event',
                                              ),
                                            ),
                                          );
                                        },
                                    icon: Icon(
                                      reg['rating'] != null ? Icons.check_circle_outline : Icons.rate_review_outlined, 
                                      size: 18
                                    ),
                                    label: Text(reg['rating'] != null ? "Feedback Submitted" : "Give Feedback"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: reg['rating'] != null ? Colors.green : Theme.of(context).primaryColor,
                                      side: BorderSide(color: (reg['rating'] != null ? Colors.green : Theme.of(context).primaryColor).withOpacity(0.5)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: (50 * index).ms).slideY(begin: 0.1);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }

  Future<void> _generateUserCertificate(BuildContext context, Map<String, dynamic> reg, Map<String, dynamic> eventData, String? rank) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: Card(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Preparing Certificate...")] ))))
    );

    try {
      final clubId = eventData['clubId'];
      final clubDoc = await FirebaseFirestore.instance.collection('clubs').doc(clubId).get();
      final clubData = clubDoc.data() ?? {};
      
      final bool isWinner = rank != null;
      final Map<String, dynamic> settings = isWinner 
          ? (clubData['winnerSettings'] ?? _getDefaultWinnerSettings())
          : (clubData['certSettings'] ?? _getDefaultCertSettings());

      final pdf = pw.Document();
      
      pw.MemoryImage? logoImg;
      pw.MemoryImage? sig1Img;
      pw.MemoryImage? sig2Img;
      pw.MemoryImage? bgImg;

      if (settings['useLogo'] == true && clubData['profilePic'] != null) logoImg = await _loadNetworkImage(clubData['profilePic']);
      if (clubData['signatureUrl'] != null) sig1Img = await _loadNetworkImage(clubData['signatureUrl']);
      if (clubData['facultySignatureUrl'] != null) sig2Img = await _loadNetworkImage(clubData['facultySignatureUrl']);
      if (settings['bgUrl']?.toString().isNotEmpty == true) bgImg = await _loadNetworkImage(settings['bgUrl']);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                if (bgImg != null) pw.Positioned.fill(child: pw.Image(bgImg!, fit: pw.BoxFit.fill)),
                pw.Container(
                  margin: const pw.EdgeInsets.all(40),
                  padding: const pw.EdgeInsets.all(20),
                  decoration: bgImg == null ? pw.BoxDecoration(
                    border: pw.Border.all(color: isWinner ? PdfColors.orange : PdfColors.indigo, width: 5),
                  ) : null,
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      if (logoImg != null) pw.Container(height: 70, width: 70, child: pw.Image(logoImg!)),
                      pw.SizedBox(height: 10),
                      pw.Text(settings['title'] ?? 'CERTIFICATE', 
                        style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: bgImg == null ? (isWinner ? PdfColors.orange : PdfColors.indigo) : PdfColors.black)),
                      pw.SizedBox(height: 10),
                      pw.Text(settings['subtitle'] ?? '', style: const pw.TextStyle(fontSize: 16)),
                      pw.SizedBox(height: 15),
                      pw.Text(reg['studentName']?.toString().toUpperCase() ?? '', 
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                      pw.SizedBox(height: 15),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 40),
                        child: _buildBodyText(settings['body'] ?? '', eventData['title'] ?? eventData['name'] ?? '', eventData['date'] ?? '', rank ?? "participant"),
                      ),
                      pw.SizedBox(height: 30),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Column(children: [
                            if (sig1Img != null) pw.Container(height: 40, width: 100, child: pw.Image(sig1Img!)),
                            pw.Container(width: 140, height: 1, color: PdfColors.black),
                            pw.Text(settings['signatory1Name'] ?? '', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            pw.Text(settings['signatory1Title'] ?? '', style: const pw.TextStyle(fontSize: 10)),
                          ]),
                          pw.Column(children: [
                            if (sig2Img != null) pw.Container(height: 40, width: 100, child: pw.Image(sig2Img!)),
                            pw.Container(width: 140, height: 1, color: PdfColors.black),
                            pw.Text(settings['signatory2Name'] ?? '', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            pw.Text(settings['signatory2Title'] ?? '', style: const pw.TextStyle(fontSize: 10)),
                          ]),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      Navigator.pop(context);
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/certificate_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error downloading: $e")));
    }
  }

  pw.Widget _buildBodyText(String template, String eventName, String date, String rank) {
    final List<pw.InlineSpan> spans = [];
    final RegExp regex = RegExp(r'(\{event\}|\{date\}|\{rank\})');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(template)) {
      if (match.start > lastMatchEnd) {
        spans.add(pw.TextSpan(text: template.substring(lastMatchEnd, match.start)));
      }

      final placeholder = match.group(0);
      String value = '';
      bool isBold = false;

      if (placeholder == '{event}') {
        value = eventName;
        isBold = true;
      } else if (placeholder == '{date}') {
        value = date;
      } else if (placeholder == '{rank}') {
        value = rank;
        isBold = true;
      }

      spans.add(pw.TextSpan(
        text: value,
        style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < template.length) {
      spans.add(pw.TextSpan(text: template.substring(lastMatchEnd)));
    }

    return pw.RichText(
      textAlign: pw.TextAlign.center,
      text: pw.TextSpan(
        style: const pw.TextStyle(fontSize: 16),
        children: spans,
      ),
    );
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
    if (link.contains('drive.google.com/uc?export=view')) return link;
    final regex = RegExp(r'(?:drive\.google\.com/file/d/|id=)([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(link);
    if (match != null) return 'https://drive.google.com/uc?export=view&id=${match.group(1)}';
    return link;
  }

  Map<String, dynamic> _getDefaultCertSettings() => {
    'title': 'CERTIFICATE OF PARTICIPATION',
    'subtitle': 'This is to certify that',
    'body': 'has successfully participated in the event {event} held on {date}.',
    'signatory1Name': 'Event Coordinator',
    'signatory1Title': 'Coordinator',
    'signatory2Name': 'Principal',
    'signatory2Title': 'Institution Head',
    'useLogo': true,
  };

  Map<String, dynamic> _getDefaultWinnerSettings() => {
    'title': 'CERTIFICATE OF EXCELLENCE',
    'subtitle': 'This is to certify that',
    'body': 'has successfully won {rank} in the event {event} held on {date}.',
    'signatory1Name': 'Event Coordinator',
    'signatory1Title': 'Coordinator',
    'signatory2Name': 'Principal',
    'signatory2Title': 'Institution Head',
    'useLogo': true,
  };
}
