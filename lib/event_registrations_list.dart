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
        final clubDoc = await FirebaseFirestore.instance.collection('clubs').doc(_clubId!).get();
        final clubData = clubDoc.data();
        if (clubData != null) {
          if (clubData.containsKey('certSettings')) {
            setState(() => _certSettings = Map<String, dynamic>.from(clubData['certSettings']));
          }
          if (clubData.containsKey('winnerSettings')) {
            setState(() => _winnerSettings = Map<String, dynamic>.from(clubData['winnerSettings']));
          }
          
          if (!clubData.containsKey('certSettings')) {
            setState(() => _certSettings['signatory2Name'] = clubData['clubName'] ?? clubData['name'] ?? '');
          }
          if (!clubData.containsKey('winnerSettings')) {
            setState(() => _winnerSettings['signatory2Name'] = clubData['clubName'] ?? clubData['name'] ?? '');
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
      await FirebaseFirestore.instance.collection('clubs').doc(_clubId!).update({
        'certSettings': _certSettings,
        'winnerSettings': _winnerSettings,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Templates saved successfully!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving settings: $e")));
    }
  }

  Future<void> _saveManualWinners() async {
    try {
      await FirebaseFirestore.instance.collection('events').doc(widget.eventId).update({
        'manualWinners': _manualWinners,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Winners saved!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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

      // Create a unified approval request in Firestore
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

  Future<void> _markAllParticipated(List<QueryDocumentSnapshot> docs, bool value) async {
    if (_certsApproved) return; // Prevent changes after verification
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
    final bool isCompleted = _eventStatus == 'completed';

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
            onPressed: isCompleted ? () => _showWinnersDialog() : () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event must be COMPLETED to set winners")));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_suggest_outlined),
            tooltip: "Design Template",
            onPressed: isCompleted ? () => _showDesignDialog() : () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event must be COMPLETED to design certificates")));
            },
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
               style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
             ),
           ),
           if (!isCompleted)
             Container(
               width: double.infinity,
               padding: const EdgeInsets.all(12),
               color: Colors.orange.shade50,
               child: Row(
                 children: [
                   const Icon(Icons.info_outline, color: Colors.orange),
                   const SizedBox(width: 8),
                   const Expanded(child: Text("Event must be marked as COMPLETED to manage winners and certificates.", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))),
                 ],
               ),
             ),
           Expanded(
             child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('registrations')
                  .where('eventId', isEqualTo: widget.eventId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data?.docs ?? [];
                
                // Sort: Winners first, then non-winners
                final List<QueryDocumentSnapshot> sortedDocs = List.from(docs);
                sortedDocs.sort((a, b) {
                  final aName = (a.data() as Map<String, dynamic>)['studentName']?.toString();
                  final bName = (b.data() as Map<String, dynamic>)['studentName']?.toString();
                  
                  final aRank = _getRankByName(aName);
                  final bRank = _getRankByName(bName);
                  
                  if (aRank != null && bRank == null) return -1;
                  if (aRank == null && bRank != null) return 1;
                  if (aRank != null && bRank != null) return aRank.compareTo(bRank);
                  
                  return (aName ?? '').compareTo(bName ?? '');
                });

                final nonWinners = docs.where((d) => _getRankByName((d.data() as Map<String, dynamic>)['studentName']) == null).toList();
                final bool allParticipated = nonWinners.isNotEmpty && nonWinners.every((d) => (d.data() as Map<String, dynamic>)['participated'] == true);
                
                // Count winners to find where to insert the "Select All" option
                int winnersCount = sortedDocs.where((d) => _getRankByName((d.data() as Map<String, dynamic>)['studentName']) != null).length;

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
                             label: const Text("Generate All"),
                             onPressed: isCompleted ? () {
                               if (!_certsApproved) {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Certificates must be approved by faculty first.")));
                                 return;
                               }
                               // Filter: (Participated OR Winner) AND non-winners (for Participation Cert)
                               final eligible = docs.where((doc) {
                                 final data = doc.data() as Map<String, dynamic>;
                                 final name = data['studentName']?.toString();
                                 final participated = data['participated'] ?? false;
                                 final isWinner = _getRankByName(name) != null;
                                 return (participated || isWinner) && !isWinner;
                               }).toList();
                               
                               if (eligible.isEmpty) {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No eligible participants found.")));
                               } else {
                                 _generateCertificatesFromDocs(eligible, isWinner: false);
                               }
                             } : null,
                           ),
                         ],
                       ),
                     ),
                     if (sortedDocs.isEmpty) 
                       const Expanded(child: Center(child: Text("No registrations yet"))),
                     if (sortedDocs.isNotEmpty)
                       Expanded(
                         child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: sortedDocs.length + (_certsApproved ? 0 : 1), // Only +1 if not approved
                            separatorBuilder: (c, i) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              // Insert "Select All" row after winners list only if not approved
                              if (!_certsApproved && index == winnersCount) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: allParticipated,
                                        onChanged: isCompleted ? (val) {
                                          if (val != null) {
                                            _markAllParticipated(docs, val);
                                          }
                                        } : null,
                                      ),
                                      const Text("Select All Participants", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                      const Expanded(child: Divider(indent: 16)),
                                    ],
                                  ),
                                );
                              }

                              // Adjust index for data access
                              int dataIndex = (!_certsApproved && index > winnersCount) ? index - 1 : index;
                              
                              final data = sortedDocs[dataIndex].data() as Map<String, dynamic>;
                              final name = data['studentName']?.toString();
                              final rank = _getRankByName(name);
                              final bool participated = data['participated'] ?? false;
                              final bool isWinner = rank != null;
                              final bool isVolunteer = data['registrationType']?.toString().toLowerCase() == 'volunteer';
                              final String assignedTask = data['assignedTask'] as String? ?? '';

                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ExpansionTile(
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!_certsApproved) ...[
                                        if (!isWinner)
                                          Checkbox(
                                            value: participated,
                                            onChanged: isCompleted ? (val) {
                                              FirebaseFirestore.instance
                                                  .collection('registrations')
                                                  .doc(sortedDocs[dataIndex].id)
                                                  .update({'participated': val});
                                            } : null,
                                          )
                                        else
                                          const SizedBox(width: 48, child: Icon(Icons.stars, color: Colors.orange)),
                                      ],
                                      CircleAvatar(
                                        backgroundColor: rank != null ? Colors.orange : Theme.of(context).primaryColor.withOpacity(0.1),
                                        child: rank != null 
                                          ? const Icon(Icons.emoji_events, color: Colors.white, size: 20)
                                          : Text(
                                              (name?[0] ?? '?').toUpperCase(),
                                              style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)
                                            ),
                                      ),
                                    ],
                                  ),
                                  title: Row(
                                    children: [
                                      Text(name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      if (rank != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                                          child: Text(rank, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(rank != null ? "Ranked Winner" : (isVolunteer ? "Volunteer" : (participated ? "Participated" : "Registered"))),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (rank != null) 
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Text("WINNER", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: participated ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: participated ? Colors.green : Colors.blue),
                                          ),
                                          child: Text(participated ? "PARTICIPATED" : "REGISTERED", style: TextStyle(color: participated ? Colors.green : Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                      child: Column(
                                        children: [
                                          _buildDetailRow(Icons.badge_outlined, "KTU ID", data['ktuId'] ?? 'N/A'),
                                          const SizedBox(height: 8),
                                          _buildDetailRow(Icons.email_outlined, "Email", data['studentEmail'] ?? 'N/A'),
                                          const SizedBox(height: 16),
                                          if (isVolunteer) ...[
                                            _buildDetailRow(Icons.assignment, "Assigned Task", assignedTask.isEmpty ? "No task assigned" : assignedTask),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton.icon(
                                                icon: const Icon(Icons.edit, size: 16),
                                                label: Text(assignedTask.isEmpty ? "Assign Task" : "Edit Task"),
                                                onPressed: () {
                                                  _showAssignTaskDialog(
                                                    sortedDocs[dataIndex].id, 
                                                    name ?? 'Unknown', 
                                                    assignedTask,
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          Row(children: [
                                            // Show buttons if participated or winner
                                            if (!participated && !isWinner)
                                              const Expanded(child: Center(child: Text("Mark as participated to enable certificates", style: TextStyle(fontSize: 12, color: Colors.grey)))),
                                            
                                            if (participated || isWinner) ...[
                                              // Participation Cert for non-winners
                                              if (rank == null)
                                                Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.card_membership), label: const Text("Cert"), onPressed: isCompleted ? () {
                                                  if (!_certsApproved) {
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Not approved by faculty")));
                                                    return;
                                                  }
                                                  _generateCertificatesFromDocs([sortedDocs[dataIndex]], isWinner: false);
                                                } : null)),
                                              
                                              // Winner Cert for winners
                                              if (rank != null)
                                                Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), icon: const Icon(Icons.emoji_events), label: const Text("Winner Cert"), onPressed: isCompleted ? () {
                                                  if (!_certsApproved) {
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Not approved by faculty")));
                                                    return;
                                                  }
                                                  _generateCertificatesFromDocs([sortedDocs[dataIndex]], isWinner: true);
                                                } : null)),
                                            ]
                                          ]),
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
           if (isCompleted) _buildVerificationFooter(),
        ],
      ),
    );
  }

  Widget _buildVerificationFooter() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('events').doc(widget.eventId).snapshots(),
      builder: (context, eventSnap) {
        final bool isApproved = (eventSnap.data?.data() as Map<String, dynamic>?)?['certsApproved'] == true;
        
        if (isApproved) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(top: BorderSide(color: Colors.green.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text("CERTIFICATES VERIFIED BY FACULTY", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('certificate_approvals')
              .where('eventId', isEqualTo: widget.eventId)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            bool isPending = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPending)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
                          SizedBox(width: 12),
                          Text("Verification Request Sent. Waiting for Faculty...", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _requestUnifiedApproval(),
                        icon: const Icon(Icons.verified_user_rounded),
                        label: const Text("REQUEST FACULTY VERIFICATION"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Text("Verification is required before certificates can be issued", style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                ],
              ),
            );
          },
        );
      }
    );
  }

  void _showAssignTaskDialog(String registrationId, String studentName, String currentTask) {
    final taskController = TextEditingController(text: currentTask);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Assign Task to $studentName"),
        content: TextField(
          controller: taskController,
          decoration: const InputDecoration(
            labelText: "Task Description",
            hintText: "Enter the task for this volunteer",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('registrations')
                  .doc(registrationId)
                  .update({'assignedTask': taskController.text.trim()});
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Task assigned seamlessly")));
            },
            child: const Text("Save"),
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
            TextField(controller: w1, decoration: const InputDecoration(labelText: "1st Place Name", prefixIcon: Icon(Icons.workspace_premium, color: Colors.amber))),
            TextField(controller: w2, decoration: const InputDecoration(labelText: "2nd Place Name", prefixIcon: Icon(Icons.workspace_premium, color: Colors.grey))),
            TextField(controller: w3, decoration: const InputDecoration(labelText: "3rd Place Name", prefixIcon: Icon(Icons.workspace_premium, color: Colors.brown))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
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
          content: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TabBar(
                  tabs: [Tab(text: "Participant"), Tab(text: "Winners")],
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                ),
                const SizedBox(height: 10),
                Flexible(
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
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
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

  Widget _buildTemplateForm(Map<String, dynamic> settings, Function(Map<String, dynamic>) onUpdate) {
    final titleCtrl = TextEditingController(text: settings['title']);
    final subtitleCtrl = TextEditingController(text: settings['subtitle']);
    final bodyCtrl = TextEditingController(text: settings['body']);
    final sig1NameCtrl = TextEditingController(text: settings['signatory1Name']);
    final sig1TitleCtrl = TextEditingController(text: settings['signatory1Title']);
    final sig2NameCtrl = TextEditingController(text: settings['signatory2Name']);
    final sig2TitleCtrl = TextEditingController(text: settings['signatory2Title']);
    final bgUrlCtrl = TextEditingController(text: settings['bgUrl']);
    bool useLogo = settings['useLogo'] ?? true;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          const Card(
            color: Color(0xFFE3F2FD),
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                "Use {event}, {date}, and {rank} placeholders to dynamically insert details.",
                style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildDesignField(titleCtrl, "Main Title", Icons.title, (v) => settings['title'] = v),
          _buildDesignField(subtitleCtrl, "Certify Text", Icons.subtitles, (v) => settings['subtitle'] = v),
          _buildDesignField(bodyCtrl, "Body Template", Icons.text_fields, (v) => settings['body'] = v, maxLines: 3),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("Signatories", style: TextStyle(color: Colors.grey, fontSize: 12))), Expanded(child: Divider())]),
          ),
          Row(children: [
            Expanded(child: _buildDesignField(sig1NameCtrl, "Sig 1 Name", Icons.person, (v) => settings['signatory1Name'] = v)),
            const SizedBox(width: 10),
            Expanded(child: _buildDesignField(sig1TitleCtrl, "Title", Icons.work, (v) => settings['signatory1Title'] = v)),
          ]),
          Row(children: [
            Expanded(child: _buildDesignField(sig2NameCtrl, "Sig 2 Name", Icons.person, (v) => settings['signatory2Name'] = v)),
            const SizedBox(width: 10),
            Expanded(child: _buildDesignField(sig2TitleCtrl, "Title", Icons.work, (v) => settings['signatory2Title'] = v)),
          ]),
          const SizedBox(height: 10),
          _buildDesignField(bgUrlCtrl, "Background Image URL", Icons.image, (v) => settings['bgUrl'] = v),
          Container(
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              title: const Text("Show Club Logo", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), 
              value: useLogo, 
              secondary: const Icon(Icons.account_balance_wallet_rounded, color: Colors.blue),
              onChanged: (v) {
                setState(() {
                  settings['useLogo'] = v;
                  useLogo = v;
                });
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignField(TextEditingController ctrl, String label, IconData icon, Function(String) onChange, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        onChanged: onChange,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No winners specified.")));
      return;
    }

    _generateCertificatesBase(winners, isWinner: true);
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: Card(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Generating Certificates...")] ))))
    );

    try {
      final pdf = pw.Document();
      final eventDoc = await FirebaseFirestore.instance.collection('events').doc(widget.eventId).get();
      final eventData = eventDoc.data() ?? {};
      final eventDate = eventData['date'] ?? "TBD";
      final clubId = eventData['clubId'];

      final activeSettings = isWinner ? _winnerSettings : _certSettings;

      pw.MemoryImage? logoImg;
      pw.MemoryImage? sig1Img;
      pw.MemoryImage? sig2Img;

      if (clubId != null) {
        final clubDoc = await FirebaseFirestore.instance.collection('clubs').doc(clubId).get();
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
        
        String rankPlaceholderText = isWinner ? rankValue : "participant";

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
                        pw.Text(activeSettings['title'], 
                          style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: bgImg == null ? (isWinner ? PdfColors.orange : PdfColors.indigo) : PdfColors.black)),
                        pw.SizedBox(height: 10),
                        pw.Text(activeSettings['subtitle'], style: const pw.TextStyle(fontSize: 16)),
                        pw.SizedBox(height: 15),
                        pw.Text(studentName, 
                          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                        pw.SizedBox(height: 15),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 40),
                          child: _buildBodyText(activeSettings['body'], widget.eventName, eventDate, rankPlaceholderText),
                        ),
                        pw.SizedBox(height: 30),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Column(children: [
                              if (sig1Img != null) pw.Container(height: 40, width: 100, child: pw.Image(sig1Img!)),
                              pw.Container(width: 140, height: 1, color: PdfColors.black),
                              pw.Text(activeSettings['signatory1Name'], style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                              pw.Text(activeSettings['signatory1Title'], style: const pw.TextStyle(fontSize: 10)),
                            ]),
                            pw.Column(children: [
                              if (sig2Img != null) pw.Container(height: 40, width: 100, child: pw.Image(sig2Img!)),
                              pw.Container(width: 140, height: 1, color: PdfColors.black),
                              pw.Text(activeSettings['signatory2Name'], style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                              pw.Text(activeSettings['signatory2Title'], style: const pw.TextStyle(fontSize: 10)),
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

      Navigator.pop(context); 
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/certs_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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
      final convertedUrl = _convertGoogleDriveLink(url);
      final response = await http.get(Uri.parse(convertedUrl));
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
}
