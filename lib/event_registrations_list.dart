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
  State<EventRegistrationsListScreen> createState() =>
      _EventRegistrationsListScreenState();
}

class _EventRegistrationsListScreenState
    extends State<EventRegistrationsListScreen> {
  Map<String, dynamic> _certSettings = {
    'title': 'CERTIFICATE OF PARTICIPATION',
    'subtitle': 'This is to certify that',
    'body':
        'has successfully participated in the event {event} held on {date}.',
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

  final Map<String, String> _manualWinners = {'1st': '', '2nd': '', '3rd': ''};

  bool _isLoadingSettings = true;
  String? _clubId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();
      final eventData = eventDoc.data();
      _clubId = eventData?['clubId'];

      // Load manual winners if stored
      if (eventData != null && eventData.containsKey('manualWinners')) {
        setState(() {
          final stored = eventData['manualWinners'] as Map<String, dynamic>;
          _manualWinners['1st'] = stored['1st'] ?? '';
          _manualWinners['2nd'] = stored['2nd'] ?? '';
          _manualWinners['3rd'] = stored['3rd'] ?? '';
        });
      }

      if (_clubId != null) {
        final clubDoc = await FirebaseFirestore.instance
            .collection('clubs')
            .doc(_clubId!)
            .get();
        final clubData = clubDoc.data();
        if (clubData != null) {
          if (clubData.containsKey('certSettings')) {
            setState(
              () => _certSettings = Map<String, dynamic>.from(
                clubData['certSettings'],
              ),
            );
          }
          if (clubData.containsKey('winnerSettings')) {
            setState(
              () => _winnerSettings = Map<String, dynamic>.from(
                clubData['winnerSettings'],
              ),
            );
          }

          if (!clubData.containsKey('certSettings')) {
            setState(
              () => _certSettings['signatory2Name'] =
                  clubData['clubName'] ?? clubData['name'] ?? '',
            );
          }
          if (!clubData.containsKey('winnerSettings')) {
            setState(
              () => _winnerSettings['signatory2Name'] =
                  clubData['clubName'] ?? clubData['name'] ?? '',
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
    } finally {
      setState(() => _isLoadingSettings = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_clubId == null) return;
    try {
      await FirebaseFirestore.instance.collection('clubs').doc(_clubId!).update(
        {'certSettings': _certSettings, 'winnerSettings': _winnerSettings},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Templates saved successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving settings: $e")));
    }
  }

  Future<void> _saveManualWinners() async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .update({'manualWinners': _manualWinners});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Winners saved!")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  String? _getRankByName(String? name) {
    if (name == null || name.isEmpty) return null;
    final cleanName = name.trim().toLowerCase();
    for (var entry in _manualWinners.entries) {
      if (entry.value.trim().toLowerCase() == cleanName &&
          entry.value.isNotEmpty) {
        return entry.key;
      }
    }
    return null;
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
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: "Announce Winners",
            onPressed: () => _showWinnersDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_suggest_outlined),
            tooltip: "Design Template",
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
              "Participation & Results",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('registrations')
                  .where('eventId', isEqualTo: widget.eventId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(child: Text('Error: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data?.docs ?? [];

                // Sort: Winners first, then non-winners
                final List<QueryDocumentSnapshot> sortedDocs = List.from(docs);
                sortedDocs.sort((a, b) {
                  final aName =
                      (a.data() as Map<String, dynamic>)['studentName']
                          ?.toString();
                  final bName =
                      (b.data() as Map<String, dynamic>)['studentName']
                          ?.toString();

                  final aRank = _getRankByName(aName);
                  final bRank = _getRankByName(bName);

                  if (aRank != null && bRank == null) return -1;
                  if (aRank == null && bRank != null) return 1;
                  if (aRank != null && bRank != null)
                    return aRank.compareTo(bRank);

                  return (aName ?? '').compareTo(bName ?? '');
                });

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Total: ${docs.length} Students",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text("Bulk Generate All"),
                            onPressed: () {
                              // Filter out winners for bulk generation
                              final nonWinners = docs.where((doc) {
                                final name =
                                    (doc.data()
                                            as Map<
                                              String,
                                              dynamic
                                            >)['studentName']
                                        ?.toString();
                                return _getRankByName(name) == null;
                              }).toList();

                              if (nonWinners.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "All students are winners. Use Generate Winners Certs.",
                                    ),
                                  ),
                                );
                              } else {
                                _generateCertificatesFromDocs(
                                  nonWinners,
                                  isWinner: false,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    if (sortedDocs.isEmpty)
                      const Expanded(
                        child: Center(child: Text("No registrations yet")),
                      ),
                    if (sortedDocs.isNotEmpty)
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: sortedDocs.length,
                          separatorBuilder: (c, i) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final data =
                                sortedDocs[index].data()
                                    as Map<String, dynamic>;
                            final name = data['studentName']?.toString();
                            final rank = _getRankByName(name);
                            final String regType =
                                (data['registrationType'] ?? 'participant')
                                    .toString();
                            final bool isVolunteer =
                                regType.toLowerCase() == 'volunteer';
                            final bool isTeamEvent =
                                (data['isTeamEvent'] ?? false) == true;
                            final String teamId = (data['teamId'] ?? '')
                                .toString();

                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: rank != null
                                      ? Colors.orange
                                      : Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.1),
                                  child: rank != null
                                      ? const Icon(
                                          Icons.emoji_events,
                                          color: Colors.white,
                                          size: 20,
                                        )
                                      : Text(
                                          (name?[0] ?? '?').toUpperCase(),
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      name ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (rank != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          rank,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  rank != null
                                      ? "Ranked Winner"
                                      : (isVolunteer
                                            ? "Volunteer"
                                            : (isTeamEvent
                                                  ? "Team Participant"
                                                  : "Participant")),
                                ),
                                trailing: rank != null
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Text(
                                          "WINNER",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : Wrap(
                                        spacing: 6,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isVolunteer
                                                  ? Colors.green.withOpacity(
                                                      0.1,
                                                    )
                                                  : Colors.blue.withOpacity(
                                                      0.1,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: isVolunteer
                                                    ? Colors.green
                                                    : Colors.blue,
                                              ),
                                            ),
                                            child: Text(
                                              isVolunteer
                                                  ? "VOLUNTEER"
                                                  : "PARTICIPANT",
                                              style: TextStyle(
                                                color: isVolunteer
                                                    ? Colors.green
                                                    : Colors.blue,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (isTeamEvent)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.purple
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: Colors.purple,
                                                ),
                                              ),
                                              child: const Text(
                                                "TEAM",
                                                style: TextStyle(
                                                  color: Colors.purple,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 8.0,
                                    ),
                                    child: Column(
                                      children: [
                                        _buildDetailRow(
                                          Icons.badge_outlined,
                                          "KTU ID",
                                          data['ktuId'] ?? 'N/A',
                                        ),
                                        const SizedBox(height: 8),
                                        _buildDetailRow(
                                          Icons.email_outlined,
                                          "Email",
                                          data['studentEmail'] ?? 'N/A',
                                        ),
                                        if (isTeamEvent) ...[
                                          const SizedBox(height: 8),
                                          _buildDetailRow(
                                            Icons.groups_rounded,
                                            "Team ID",
                                            teamId.isNotEmpty
                                                ? teamId.substring(
                                                    0,
                                                    teamId.length > 8
                                                        ? 8
                                                        : teamId.length,
                                                  )
                                                : 'N/A',
                                          ),
                                        ],
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            // Only show Participation Cert for non-winners
                                            if (rank == null)
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  icon: const Icon(
                                                    Icons.card_membership,
                                                  ),
                                                  label: const Text("Cert"),
                                                  onPressed: () =>
                                                      _generateCertificatesFromDocs(
                                                        [sortedDocs[index]],
                                                        isWinner: false,
                                                      ),
                                                ),
                                              ),

                                            // Only show Winner Cert for winners
                                            if (rank != null)
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.orange,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.emoji_events,
                                                  ),
                                                  label: const Text(
                                                    "Winner Cert",
                                                  ),
                                                  onPressed: () =>
                                                      _generateCertificatesFromDocs(
                                                        [sortedDocs[index]],
                                                        isWinner: true,
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                    ),
                                  ),
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

  void _showWinnersDialog() {
    final w1 = TextEditingController(text: _manualWinners['1st']);
    final w2 = TextEditingController(text: _manualWinners['2nd']);
    final w3 = TextEditingController(text: _manualWinners['3rd']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Announce Winners"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: w1,
              decoration: const InputDecoration(
                labelText: "1st Place Name",
                prefixIcon: Icon(Icons.workspace_premium, color: Colors.amber),
              ),
            ),
            TextField(
              controller: w2,
              decoration: const InputDecoration(
                labelText: "2nd Place Name",
                prefixIcon: Icon(Icons.workspace_premium, color: Colors.grey),
              ),
            ),
            TextField(
              controller: w3,
              decoration: const InputDecoration(
                labelText: "3rd Place Name",
                prefixIcon: Icon(Icons.workspace_premium, color: Colors.brown),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _manualWinners['1st'] = w1.text.trim();
                _manualWinners['2nd'] = w2.text.trim();
                _manualWinners['3rd'] = w3.text.trim();
              });
              _saveManualWinners();
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(ctx);
              _generateWinnerCertificates();
            },
            child: const Text("Generate Winner Certs"),
          ),
        ],
      ),
    );
  }

  void _showDesignDialog() {
    showDialog(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: AlertDialog(
          title: const Text("Design Templates"),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: "Participant"),
                    Tab(text: "Winners"),
                  ],
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    children: [
                      _buildTemplateForm(
                        _certSettings,
                        (val) => setState(() => _certSettings = val),
                      ),
                      _buildTemplateForm(
                        _winnerSettings,
                        (val) => setState(() => _winnerSettings = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _saveSettings();
              },
              child: const Text("Save Templates"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateForm(
    Map<String, dynamic> settings,
    Function(Map<String, dynamic>) onUpdate,
  ) {
    final titleCtrl = TextEditingController(text: settings['title']);
    final subtitleCtrl = TextEditingController(text: settings['subtitle']);
    final bodyCtrl = TextEditingController(text: settings['body']);
    final sig1NameCtrl = TextEditingController(
      text: settings['signatory1Name'],
    );
    final sig1TitleCtrl = TextEditingController(
      text: settings['signatory1Title'],
    );
    final sig2NameCtrl = TextEditingController(
      text: settings['signatory2Name'],
    );
    final sig2TitleCtrl = TextEditingController(
      text: settings['signatory2Title'],
    );
    final bgUrlCtrl = TextEditingController(text: settings['bgUrl']);
    bool useLogo = settings['useLogo'] ?? true;

    return SingleChildScrollView(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              "Pro Tip 🚀 Let {event}, {date}, and {rank} do the typing for you.",
              style: TextStyle(
                fontSize: 12,
                color: Colors.blueAccent,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: "Main Title"),
            onChanged: (v) => settings['title'] = v,
          ),
          TextField(
            controller: subtitleCtrl,
            decoration: const InputDecoration(labelText: "Certify Text"),
            onChanged: (v) => settings['subtitle'] = v,
          ),
          TextField(
            controller: bodyCtrl,
            decoration: const InputDecoration(labelText: "Body Template"),
            maxLines: 2,
            onChanged: (v) => settings['body'] = v,
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: sig1NameCtrl,
                  decoration: const InputDecoration(labelText: "Sig 1 Name"),
                  onChanged: (v) => settings['signatory1Name'] = v,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: sig1TitleCtrl,
                  decoration: const InputDecoration(labelText: "Title"),
                  onChanged: (v) => settings['signatory1Title'] = v,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: sig2NameCtrl,
                  decoration: const InputDecoration(labelText: "Sig 2 Name"),
                  onChanged: (v) => settings['signatory2Name'] = v,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: sig2TitleCtrl,
                  decoration: const InputDecoration(labelText: "Title"),
                  onChanged: (v) => settings['signatory2Title'] = v,
                ),
              ),
            ],
          ),
          TextField(
            controller: bgUrlCtrl,
            decoration: const InputDecoration(labelText: "BG Image URL"),
            onChanged: (v) => settings['bgUrl'] = v,
          ),
          StatefulBuilder(
            builder: (context, setCheckState) => SwitchListTile(
              title: const Text("Show Logo"),
              value: useLogo,
              onChanged: (v) {
                setCheckState(() => useLogo = v);
                settings['useLogo'] = v;
              },
            ),
          ),
        ],
      ),
    );
  }

  void _generateWinnerCertificates() {
    List<Map<String, String>> winners = [];
    _manualWinners.forEach((rank, name) {
      if (name.isNotEmpty) {
        winners.add({'name': name, 'rank': rank});
      }
    });

    if (winners.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No winners specified.")));
      return;
    }

    _generateCertificatesBase(winners, isWinner: true);
  }

  void _generateCertificatesFromDocs(
    List<QueryDocumentSnapshot> studentDocs, {
    required bool isWinner,
  }) {
    List<Map<String, String>> data = studentDocs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final name = d['studentName']?.toString() ?? 'PARTICIPANT';
      final rank = _getRankByName(name) ?? 'participant';
      return {'name': name, 'rank': rank};
    }).toList();
    _generateCertificatesBase(data, isWinner: isWinner);
  }

  Future<void> _generateCertificatesBase(
    List<Map<String, String>> items, {
    required bool isWinner,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Generating Certificates..."),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final pdf = pw.Document();
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();
      final eventData = eventDoc.data() ?? {};
      final eventDate = eventData['date'] ?? "TBD";
      final clubId = eventData['clubId'];

      final activeSettings = isWinner ? _winnerSettings : _certSettings;

      pw.MemoryImage? logoImg;
      pw.MemoryImage? sig1Img;
      pw.MemoryImage? sig2Img;

      if (clubId != null) {
        final clubDoc = await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .get();
        final clubData = clubDoc.data();
        if (clubData != null) {
          if (activeSettings['useLogo'] == true &&
              clubData['profilePic'] != null)
            logoImg = await _loadNetworkImage(clubData['profilePic']);
          if (clubData['signatureUrl'] != null)
            sig1Img = await _loadNetworkImage(clubData['signatureUrl']);
          if (clubData['facultySignatureUrl'] != null)
            sig2Img = await _loadNetworkImage(clubData['facultySignatureUrl']);
        }
      }

      pw.MemoryImage? bgImg;
      if (activeSettings['bgUrl'].toString().isNotEmpty)
        bgImg = await _loadNetworkImage(activeSettings['bgUrl']);

      for (var item in items) {
        final studentName = item['name']!.toUpperCase();
        final rankValue = item['rank']!;

        String rankPlaceholderText = isWinner ? rankValue : "participant";

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  if (bgImg != null)
                    pw.Positioned.fill(
                      child: pw.Image(bgImg!, fit: pw.BoxFit.fill),
                    ),
                  pw.Container(
                    margin: const pw.EdgeInsets.all(40),
                    padding: const pw.EdgeInsets.all(20),
                    decoration: bgImg == null
                        ? pw.BoxDecoration(
                            border: pw.Border.all(
                              color: isWinner
                                  ? PdfColors.orange
                                  : PdfColors.indigo,
                              width: 5,
                            ),
                          )
                        : null,
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        if (logoImg != null)
                          pw.Container(
                            height: 70,
                            width: 70,
                            child: pw.Image(logoImg!),
                          ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          activeSettings['title'],
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: bgImg == null
                                ? (isWinner
                                      ? PdfColors.orange
                                      : PdfColors.indigo)
                                : PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          activeSettings['subtitle'],
                          style: const pw.TextStyle(fontSize: 16),
                        ),
                        pw.SizedBox(height: 15),
                        pw.Text(
                          studentName,
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            decoration: pw.TextDecoration.underline,
                          ),
                        ),
                        pw.SizedBox(height: 15),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 40,
                          ),
                          child: _buildBodyText(
                            activeSettings['body'],
                            widget.eventName,
                            eventDate,
                            rankPlaceholderText,
                          ),
                        ),
                        pw.SizedBox(height: 30),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Column(
                              children: [
                                if (sig1Img != null)
                                  pw.Container(
                                    height: 40,
                                    width: 100,
                                    child: pw.Image(sig1Img!),
                                  ),
                                pw.Container(
                                  width: 140,
                                  height: 1,
                                  color: PdfColors.black,
                                ),
                                pw.Text(
                                  activeSettings['signatory1Name'],
                                  style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  activeSettings['signatory1Title'],
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                            pw.Column(
                              children: [
                                if (sig2Img != null)
                                  pw.Container(
                                    height: 40,
                                    width: 100,
                                    child: pw.Image(sig2Img!),
                                  ),
                                pw.Container(
                                  width: 140,
                                  height: 1,
                                  color: PdfColors.black,
                                ),
                                pw.Text(
                                  activeSettings['signatory2Name'],
                                  style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  activeSettings['signatory2Title'],
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
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

      Navigator.pop(context);
      final output = await getTemporaryDirectory();
      final file = File(
        "${output.path}/certs_${DateTime.now().millisecondsSinceEpoch}.pdf",
      );
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  pw.Widget _buildBodyText(
    String template,
    String eventName,
    String date,
    String rank,
  ) {
    final List<pw.InlineSpan> spans = [];
    final RegExp regex = RegExp(r'(\{event\}|\{date\}|\{rank\})');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(template)) {
      if (match.start > lastMatchEnd) {
        spans.add(
          pw.TextSpan(text: template.substring(lastMatchEnd, match.start)),
        );
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

      spans.add(
        pw.TextSpan(
          text: value,
          style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

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
      final convertedUrl = _convertGoogleDriveLink(url);
      final response = await http.get(Uri.parse(convertedUrl));
      if (response.statusCode == 200) return pw.MemoryImage(response.bodyBytes);
      return null;
    } catch (e) {
      return null;
    }
  }

  String _convertGoogleDriveLink(String link) {
    if (link.isEmpty) return '';
    if (link.contains('drive.google.com/uc?export=view')) return link;
    final regex = RegExp(r'(?:drive\.google\.com/file/d/|id=)([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(link);
    if (match != null)
      return 'https://drive.google.com/uc?export=view&id=${match.group(1)}';
    return link;
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
