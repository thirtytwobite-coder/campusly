import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'event_registrations_list.dart';
import 'list_approval_screen.dart';
import 'vibrant_background.dart';

class AnalyticsScreen extends StatefulWidget {
  final String clubId;
  final String clubName;
  final String? coordinatorId;
  final bool isFaculty;

  const AnalyticsScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.coordinatorId,
    this.isFaculty = false,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Set<String> _myProgramIds = {};
  bool _isLoadingIds = true;

  @override
  void initState() {
    super.initState();
    _fetchMyProgramIds();
  }

  Future<void> _fetchMyProgramIds() async {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.clubName} Analytics"),
        actions: [
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
      body: Stack(
        children: [
          const VibrantBackground(),
          _isLoadingIds
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
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

              final events = allEvents.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (widget.coordinatorId != null && !widget.isFaculty) {
                  final pId = data['programId'];
                  return _myProgramIds.contains(pId);
                }
                return true;
              }).toList();

              events.sort((a, b) {
                final dateA = (a.data() as Map<String, dynamic>)['date'] ?? '';
                final dateB = (b.data() as Map<String, dynamic>)['date'] ?? '';
                return dateB.compareTo(dateA);
              });

              if (events.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No published events found.", style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  final data = event.data() as Map<String, dynamic>;

                  final title = data['title'] ?? 'Untitled Event';
                  final date = data['date'] ?? 'N/A';

                  return GlassCard(
                    borderRadius: 15,
                    child: Card(
                      elevation: 0,
                      color: Colors.transparent,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventRegistrationsListScreen(
                                eventId: event.id,
                                eventName: title,
                                isFacultyView: widget.isFaculty,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title, 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 18,
                                  color: isDark ? Colors.white : Colors.black,
                                )
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Date: $date",
                                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn().slideY(begin: 0.1, delay: (50 * index).ms);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
