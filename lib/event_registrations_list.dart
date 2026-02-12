import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class EventRegistrationsListScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const EventRegistrationsListScreen({
    super.key,
    required this.eventId,
    required this.eventName,
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

  bool _isLoadingSettings = true;
  String? _clubId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final eventDoc = await FirebaseFirestore.instance.collection('events').doc(widget.eventId).get();
      _clubId = eventDoc.data()?['clubId'];
      
      if (_clubId != null) {
        final clubDoc = await FirebaseFirestore.instance.collection('clubs').doc(_clubId!).get();
        final clubData = clubDoc.data();
        if (clubData != null && clubData.containsKey('certSettings')) {
          setState(() {
            _certSettings = Map<String, dynamic>.from(clubData['certSettings']);
          });
        } else {
          // Default signatory 2 to club name if not set
          setState(() {
            _certSettings['signatory2Name'] = clubData?['clubName'] ?? clubData?['name'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading cert settings: $e");
    } finally {
      setState(() => _isLoadingSettings = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_clubId == null) return;
    try {
      await FirebaseFirestore.instance.collection('clubs').doc(_clubId!).update({
        'certSettings': _certSettings,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Certificate template saved!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving settings: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.eventName),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest_outlined),
            tooltip: "Design Certificate",
            onPressed: () => _showDesignDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
           Container(
             width: double.infinity,
             padding: const EdgeInsets.all(16.0),
             color: Theme.of(context).primaryColor,
             child: const Text(
               "Registered Students", 
               style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
             ),
           ),
           Expanded(
             child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('registrations')
                  .where('eventId', isEqualTo: widget.eventId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                   return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                         const SizedBox(height: 16),
                         Text("No registrations yet for ${widget.eventName}", style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                     Padding(
                       padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text(
                             "Total: ${docs.length} Students", 
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                           ),
                           ElevatedButton.icon(
                             style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                             icon: const Icon(Icons.auto_awesome),
                             label: const Text("Bulk Generate"),
                             onPressed: () => _generateCertificates(docs),
                           ),
                         ],
                       ),
                     ),
                     Expanded(
                       child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: docs.length,
                          separatorBuilder: (c, i) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                  child: Text(
                                      (data['studentName']?[0] ?? '?').toUpperCase(),
                                      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)
                                  ),
                                ),
                                title: Text(data['studentName'] ?? 'Unknown Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  "${data['department'] ?? 'N/A'} - S${data['semester'] ?? '?'}",
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    child: Column(
                                      children: [
                                        _buildDetailRow(Icons.badge_outlined, "KTU ID", data['ktuId'] ?? 'N/A'),
                                        const SizedBox(height: 8),
                                        _buildDetailRow(Icons.phone_outlined, "Phone", data['studentPhone'] ?? 'N/A'),
                                        const SizedBox(height: 8),
                                        _buildDetailRow(Icons.email_outlined, "Email", data['studentEmail'] ?? 'N/A'),
                                        const SizedBox(height: 8),
                                        _buildDetailRow(Icons.calendar_today, "Registered At", 
                                          _formatTimestamp(data['registeredAt'])
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.card_membership),
                                          label: const Text("Single Certificate"),
                                          onPressed: () => _generateCertificates([docs[index]]),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ).animate().fadeIn().slideX(delay: (30 * index).ms);
                          },
                       ),
                     ),
                  ],
                );
              },
                     ),
           ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.grey)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      ],
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      return "${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return timestamp.toString();
  }

  void _showDesignDialog() {
    final titleCtrl = TextEditingController(text: _certSettings['title']);
    final subtitleCtrl = TextEditingController(text: _certSettings['subtitle']);
    final bodyCtrl = TextEditingController(text: _certSettings['body']);
    final sig1NameCtrl = TextEditingController(text: _certSettings['signatory1Name']);
    final sig1TitleCtrl = TextEditingController(text: _certSettings['signatory1Title']);
    final sig2NameCtrl = TextEditingController(text: _certSettings['signatory2Name']);
    final sig2TitleCtrl = TextEditingController(text: _certSettings['signatory2Title']);
    final bgUrlCtrl = TextEditingController(text: _certSettings['bgUrl']);
    bool useLogo = _certSettings['useLogo'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Design Certificate Template"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Use {event} and {date} as placeholders in body text.", style: TextStyle(fontSize: 11, color: Colors.blue)),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Main Title")),
                TextField(controller: subtitleCtrl, decoration: const InputDecoration(labelText: "Certify Text")),
                TextField(controller: bodyCtrl, decoration: const InputDecoration(labelText: "Body Template"), maxLines: 2),
                const SizedBox(height: 10),
                const Divider(),
                Row(children: [
                  Expanded(child: TextField(controller: sig1NameCtrl, decoration: const InputDecoration(labelText: "Signatory 1 Name"))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: sig1TitleCtrl, decoration: const InputDecoration(labelText: "Title"))),
                ]),
                Row(children: [
                  Expanded(child: TextField(controller: sig2NameCtrl, decoration: const InputDecoration(labelText: "Signatory 2 Name"))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: sig2TitleCtrl, decoration: const InputDecoration(labelText: "Title"))),
                ]),
                const SizedBox(height: 10),
                const Divider(),
                TextField(controller: bgUrlCtrl, decoration: const InputDecoration(labelText: "Background Image URL (Optional)")),
                SwitchListTile(
                  title: const Text("Show Club Logo"),
                  value: useLogo, 
                  onChanged: (v) => setState(() => useLogo = v)
                ),
                const Text("Logo and Signatures are automatically used from Club Branding.", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                _certSettings = {
                  'title': titleCtrl.text.trim(),
                  'subtitle': subtitleCtrl.text.trim(),
                  'body': bodyCtrl.text.trim(),
                  'signatory1Name': sig1NameCtrl.text.trim(),
                  'signatory1Title': sig1TitleCtrl.text.trim(),
                  'signatory2Name': sig2NameCtrl.text.trim(),
                  'signatory2Title': sig2TitleCtrl.text.trim(),
                  'useLogo': useLogo,
                  'bgUrl': bgUrlCtrl.text.trim(),
                };
                Navigator.pop(ctx);
                _saveSettings();
              },
              child: const Text("Save Template"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateCertificates(List<QueryDocumentSnapshot> studentDocs) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: Card(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Generating Certificates...")]))))
    );

    try {
      final pdf = pw.Document();
      
      // Fetch Event Data
      final eventDoc = await FirebaseFirestore.instance.collection('events').doc(widget.eventId).get();
      final eventData = eventDoc.data() ?? {};
      final eventDate = eventData['date'] ?? "TBD";
      final clubId = eventData['clubId'];

      // 🔹 Fetch Club Branding Assets (Always the same for the club)
      pw.MemoryImage? logoImg;
      pw.MemoryImage? sig1Img; // Coordinator Signature
      pw.MemoryImage? sig2Img; // Faculty Signature (Signatory 2 in branding)

      if (clubId != null) {
        final clubDoc = await FirebaseFirestore.instance.collection('clubs').doc(clubId).get();
        final clubData = clubDoc.data();
        if (clubData != null) {
          // Logo
          if (_certSettings['useLogo'] == true && clubData['profilePic'] != null) {
            logoImg = await _loadNetworkImage(clubData['profilePic']);
          }
          // Coordinator Signature (Signature 1)
          if (clubData['signatureUrl'] != null) {
            sig1Img = await _loadNetworkImage(clubData['signatureUrl']);
          }
          // Faculty Signature (Signature 2)
          if (clubData['facultySignatureUrl'] != null) {
            sig2Img = await _loadNetworkImage(clubData['facultySignatureUrl']);
          }
        }
      }

      // Fetch Background if per-event background is set in template
      pw.MemoryImage? bgImg;
      if (_certSettings['bgUrl'].toString().isNotEmpty) {
        bgImg = await _loadNetworkImage(_certSettings['bgUrl']);
      }

      for (var doc in studentDocs) {
        final student = doc.data() as Map<String, dynamic>;
        final studentName = student['studentName']?.toString().toUpperCase() ?? "PARTICIPANT";
        
        String bodyText = _certSettings['body']
            .replaceAll('{event}', widget.eventName)
            .replaceAll('{date}', eventDate);

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
                      border: pw.Border.all(color: PdfColors.indigo, width: 5),
                    ) : null,
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        if (logoImg != null) pw.Container(height: 70, width: 70, child: pw.Image(logoImg!)),
                        pw.SizedBox(height: 10),
                        pw.Text(_certSettings['title'], 
                          style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: bgImg == null ? PdfColors.indigo : PdfColors.black)),
                        pw.SizedBox(height: 10),
                        pw.Text(_certSettings['subtitle'], style: const pw.TextStyle(fontSize: 16)),
                        pw.SizedBox(height: 15),
                        pw.Text(studentName, 
                          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                        pw.SizedBox(height: 15),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 40),
                          child: pw.Text(bodyText, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 16)),
                        ),
                        pw.SizedBox(height: 30),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            // Signatory 1: Coordinator
                            pw.Column(children: [
                              if (sig1Img != null) pw.Container(height: 40, width: 100, child: pw.Image(sig1Img!)),
                              pw.Container(width: 140, height: 1, color: PdfColors.black),
                              pw.Text(_certSettings['signatory1Name'], style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                              pw.Text(_certSettings['signatory1Title'], style: const pw.TextStyle(fontSize: 10)),
                            ]),
                            // Signatory 2: Faculty
                            pw.Column(children: [
                              if (sig2Img != null) pw.Container(height: 40, width: 100, child: pw.Image(sig2Img!)),
                              pw.Container(width: 140, height: 1, color: PdfColors.black),
                              pw.Text(_certSettings['signatory2Name'], style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                              pw.Text(_certSettings['signatory2Title'], style: const pw.TextStyle(fontSize: 10)),
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
      }

      Navigator.pop(context); // Remove loading
      final output = await getTemporaryDirectory();
      final fileName = studentDocs.length == 1 
          ? "certificate_${(studentDocs.first.data() as Map)['studentName']}.pdf"
          : "certificates_${widget.eventName}.pdf";
      final file = File("${output.path}/$fileName");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<pw.MemoryImage?> _loadNetworkImage(String url) async {
    try {
      final convertedUrl = _convertGoogleDriveLink(url);
      final response = await http.get(Uri.parse(convertedUrl));
      if (response.statusCode == 200) {
        return pw.MemoryImage(response.bodyBytes);
      }
      return null;
    } catch (e) {
      debugPrint("Error loading network image: $e");
      return null;
    }
  }

  String _convertGoogleDriveLink(String link) {
    if (link.isEmpty) return '';
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
