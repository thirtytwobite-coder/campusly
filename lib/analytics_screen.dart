import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'event_registrations_list.dart';

class AnalyticsScreen extends StatefulWidget {
  final String clubId;
  final String clubName;
  final String? coordinatorId;

  const AnalyticsScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.coordinatorId,
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
    if (widget.coordinatorId == null) {
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
        title: const Text("Analytics & Registrations"),
      ),
      body: _isLoadingIds
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

                // Filter events: 
                // 1. Must belong to the club (handled by query)
                // 2. Must be created by this coordinator (handled by checking programId)
                final allEvents = snapshot.data?.docs ?? [];
                
                final events = allEvents.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  // If we have a coordinatorId filter, ensure the event's programId is in our allowed list
                  if (widget.coordinatorId != null) {
                    final pId = data['programId'];
                    return _myProgramIds.contains(pId);
                  }
                  return true;
                }).toList();

          // Sort by date manually if string
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
                   const Icon(Icons.analytics_outlined, size: 80, color: Colors.grey),
                   const SizedBox(height: 16),
                   const Text("No published events found.", style: TextStyle(fontSize: 18, color: Colors.grey)),
                   const Text("Once events are approved, they will appear here.", style: TextStyle(color: Colors.grey)),
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
              
              // Note: 'events' collection uses 'title' instead of 'name'
              final title = data['title'] ?? 'Untitled Event';
              final date = data['date'] ?? 'N/A';
              final time = data['time'] ?? 'N/A';

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
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade400, Colors.blue.shade800],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.people_alt_outlined, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Text(
                                 title,
                                 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                               ),
                               const SizedBox(height: 6),
                               Row(
                                 children: [
                                   Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                   const SizedBox(width: 4),
                                   Text(date, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                   const SizedBox(width: 12),
                                   Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                   const SizedBox(width: 4),
                                   Text(time, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                 ],
                               ),
                               const SizedBox(height: 6),
                               Row(
                                 children: [
                                   Text(
                                     "Tap to view participants", 
                                     style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 12)
                                   ),
                                   const SizedBox(width: 4),
                                   Icon(Icons.arrow_forward, size: 12, color: Theme.of(context).primaryColor),
                                 ],
                               )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 0.1, delay: (50 * index).ms);
            },
          );
        },
      ),
    );
  }
}
