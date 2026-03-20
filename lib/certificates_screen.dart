import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'event_registrations_list.dart';
import 'list_approval_screen.dart';

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
    this.isFaculty = false, // Added isFaculty parameter
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
    // If it's a faculty member, they don't need to filter by their own programs
    if (widget.isFaculty || widget.coordinatorId == null) {
      setState(() => _isLoadingIds = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.clubName} Certificates & Winners"),
        actions: [
          // Show approval button only for faculty
          if (widget.isFaculty)
            IconButton(
              icon: const Icon(Icons.playlist_add_check),
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
      body: _isLoadingIds
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search event by name...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.1),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('events')
                        .where('clubId', isEqualTo: widget.clubId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allEvents = snapshot.data?.docs ?? [];

                      var events = allEvents.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        // If it's a coordinator, filter by their programs. Faculty sees all.
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
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isEmpty ? Icons.analytics_outlined : Icons.search_off,
                                size: 80, 
                                color: Colors.grey
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty ? "No published events found." : "No events match your search.",
                                style: const TextStyle(fontSize: 18, color: Colors.grey)
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          final data = event.data() as Map<String, dynamic>;

                          final title = data['title'] ?? 'Untitled Event';
                          final date = data['date'] ?? 'N/A';

                          return Card(
                            elevation: 3,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            margin: const EdgeInsets.only(bottom: 16),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EventRegistrationsListScreen(
                                      eventId: event.id,
                                      eventName: title,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                    const SizedBox(height: 6),
                                    Text("Date: $date"),
                                  ],
                                ),
                              ),
                            ),
                          ).animate().fadeIn().slideY(begin: 0.1, delay: (50 * index).ms);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}