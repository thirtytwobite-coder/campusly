/// This screen displays certificates for events organized by a specific club.
/// It allows club coordinators and faculty to view and manage certificates for their programs.
/// The screen fetches program IDs and shows certificate-related information with search functionality.
/// Users can navigate to detailed event registration lists and approval screens from this view.

import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'event_registrations_list.dart';
import 'list_approval_screen.dart';
import 'vibrant_background.dart';
import 'dart:convert';

class CertificatesScreen extends StatefulWidget {
  final String clubId;
  final String clubName;
  final String? coordinatorId;
  final bool isFaculty;

  const CertificatesScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.coordinatorId,
    this.isFaculty = false,
  });

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  Set<String> _myProgramIds = {};
  bool _isLoadingIds = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchMyProgramIds();
  }

  Future<void> _fetchMyProgramIds() async {
    if (widget.isFaculty || widget.coordinatorId == null) {
      if (mounted) setState(() => _isLoadingIds = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('programs')
          .where('coordinatorId', isEqualTo: widget.coordinatorId)
          .get();

      if (mounted) {
        setState(() {
          _myProgramIds = snapshot.docs.map((d) => d.id).toSet();
          _isLoadingIds = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching program IDs: $e");
      if (mounted) setState(() => _isLoadingIds = false);
    }
  }

  String _convertGoogleDriveLink(String link) {
    if (link.isEmpty) return '';
    if (link.contains('drive.google.com/uc?export=view')) return link;
    final regex = RegExp(r'(?:drive\.google\.com/file/d/|id=)([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(link);
    if (match != null) return 'https://drive.google.com/uc?export=view&id=${match.group(1)}';
    return link;
  }

  Future<void> _showCoordinatorCertDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text("Coordinator Certificates", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || !snapshot.data!.exists) return const Text("Club not found");
              
              final clubData = snapshot.data!.data() as Map<String, dynamic>;
              final List<String> coordinatorEmails = List<String>.from(clubData['coordinatorEmails'] ?? []);

              if (coordinatorEmails.isEmpty) return const Text("No coordinators assigned.");

              return ListView.builder(
                shrinkWrap: true,
                itemCount: coordinatorEmails.length,
                itemBuilder: (context, index) {
                  final email = coordinatorEmails[index];
                  return ListTile(
                    title: Text(email, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                    trailing: const Icon(Icons.file_download_rounded, color: Colors.blueAccent),
                    onTap: () async {
                      Navigator.pop(context);
                      await _generateCoordinatorCert(email, clubData);
                    },
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

  Future<void> _generateCoordinatorCert(String email, Map<String, dynamic> clubData) async {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: Card(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Generating Certificate...", style: TextStyle(fontWeight: FontWeight.bold))])))),
    );

    try {
      final userSnap = await FirebaseFirestore.instance.collection('student').where('email', isEqualTo: email).limit(1).get();
      String name = email.split('@')[0].toUpperCase();
      if (userSnap.docs.isNotEmpty) {
        name = (userSnap.docs.first.data())['name']?.toString().toUpperCase() ?? name;
      }

      final pdf = pw.Document();
      pw.MemoryImage? logoImg;
      pw.MemoryImage? sigImg;
      pw.MemoryImage? facSigImg;

      if (clubData['profilePic'] != null && clubData['profilePic'].toString().isNotEmpty) {
        logoImg = await _loadCertImage(clubData['profilePic']);
      }
      if (clubData['signatureUrl'] != null && clubData['signatureUrl'].toString().isNotEmpty) {
        sigImg = await _loadCertImage(clubData['signatureUrl']);
      }
      if (clubData['facultySignatureUrl'] != null && clubData['facultySignatureUrl'].toString().isNotEmpty) {
        facSigImg = await _loadCertImage(clubData['facultySignatureUrl']);
      }

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.all(30),
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blueGrey900, width: 5)),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (logoImg != null) pw.Container(height: 80, width: 80, child: pw.Image(logoImg!)),
                pw.SizedBox(height: 20),
                pw.Text("CERTIFICATE OF LEADERSHIP", style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.SizedBox(height: 10),
                pw.Text("This is to certify that", style: pw.TextStyle(fontSize: 18, fontStyle: pw.FontStyle.italic)),
                pw.SizedBox(height: 20),
                pw.Text(name, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                pw.SizedBox(height: 20),
                pw.Text("has exceptionally served as the Club Coordinator for", style: const pw.TextStyle(fontSize: 16)),
                pw.Text(widget.clubName.toUpperCase(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text("during the academic period and has demonstrated outstanding commitment and leadership.", textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 50),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(children: [
                      if (sigImg != null) pw.Container(height: 40, width: 100, child: pw.Image(sigImg!)),
                      pw.Container(width: 140, height: 1, color: PdfColors.black),
                      pw.Text("Coordinator", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ]),
                    pw.Column(children: [
                      if (facSigImg != null) pw.Container(height: 40, width: 100, child: pw.Image(facSigImg!)),
                      pw.Container(width: 140, height: 1, color: PdfColors.black),
                      pw.Text("Faculty In-Charge", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ]),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text("Generated on ${DateFormat('dd MMMM yyyy').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
          );
        },
      ));

      if (mounted) Navigator.pop(context);
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/coordinator_cert_${name.replaceAll(' ', '_')}.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<pw.MemoryImage?> _loadCertImage(String data) async {
    try {
      if (data.startsWith('data:image')) {
        return pw.MemoryImage(base64Decode(data.split(',').last));
      } else {
        final response = await http.get(Uri.parse(_convertGoogleDriveLink(data)));
        if (response.statusCode == 200) return pw.MemoryImage(response.bodyBytes);
      }
    } catch (e) {
      debugPrint("Image load error: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "CERTIFICATES HUB",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.4 : 0.6),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.stars_rounded),
            tooltip: 'Coordinator Certificates',
            onPressed: _showCoordinatorCertDialog,
          ),
          if (widget.isFaculty)
            IconButton(
              icon: const Icon(Icons.playlist_add_check_rounded),
              tooltip: 'Approve Participant/Winner Lists',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ListApprovalScreen(
                      clubId: widget.clubId,
                      clubName: widget.clubName,
                    ),
                  ),
                );
              },
            )
        ],
      ),
      body: Stack(
        children: [
          const VibrantBackground(),
          _isLoadingIds
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverToBoxAdapter(
                        child: GlassCard(
                          borderRadius: 20,
                          child: TextField(
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                            decoration: InputDecoration(
                              hintText: "Search events...",
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                              prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white54 : Colors.black54),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            ),
                          ),
                        ).animate().fadeIn().slideY(begin: 0.1),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('events')
                          .where('clubId', isEqualTo: widget.clubId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
                        }

                        final allEvents = snapshot.data?.docs ?? [];
                        var events = allEvents.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          if (widget.coordinatorId != null && !widget.isFaculty) {
                            final pId = data['programId'];
                            if (!_myProgramIds.contains(pId)) return false;
                          }
                          final title = (data['title'] ?? '').toString().toLowerCase();
                          return title.contains(_searchQuery);
                        }).toList();

                        events.sort((a, b) {
                          final dateA = (a.data() as Map<String, dynamic>)['date'] ?? '';
                          final dateB = (b.data() as Map<String, dynamic>)['date'] ?? '';
                          return dateB.compareTo(dateA);
                        });

                        if (events.isEmpty) {
                          return SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_busy_rounded, size: 80, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1)),
                                  const SizedBox(height: 16),
                                  Text("No events found", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey[600], fontSize: 16)),
                                ],
                              ),
                            ),
                          );
                        }

                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              childAspectRatio: 0.8,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final event = events[index];
                                final data = event.data() as Map<String, dynamic>;
                                final title = data['title'] ?? 'Untitled Event';
                                final date = data['date'] ?? 'N/A';
                                return _buildCertificateGridItem(event.id, title, date, index, isDark);
                              },
                              childCount: events.length,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildCertificateGridItem(String eventId, String title, String date, int index, bool isDark) {
    final theme = Theme.of(context);
    return GlassCard(
      borderRadius: 24,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventRegistrationsListScreen(
                eventId: eventId,
                eventName: title,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.workspace_premium_rounded, color: theme.colorScheme.primary, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: -0.2),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).scale(begin: const Offset(0.9, 0.9));
  }
}
