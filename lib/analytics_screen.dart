import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'event_registrations_list.dart';
import 'list_approval_screen.dart';

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
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMyProgramIds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          "${widget.clubName} Analytics",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        actions: [
          if (widget.isFaculty)
            IconButton(
              icon: const Icon(Icons.playlist_add_check_circle_rounded),
              tooltip: 'Verification',
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
      body: Column(
        children: [
          // 🔹 Modern Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: "Search events by name...",
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.blue),
                  suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() { _searchQuery = ""; });
                        },
                      )
                    : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoadingIds
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('events')
                        .where('clubId', isEqualTo: widget.clubId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                      final allEvents = snapshot.data?.docs ?? [];
                      
                      // 🔹 Apply filters: (Coordinator access) AND (Search query)
                      final events = allEvents.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final title = (data['title'] ?? data['name'] ?? '').toString().toLowerCase();
                        
                        // Filter 1: Access Control
                        bool hasAccess = true;
                        if (widget.coordinatorId != null && !widget.isFaculty) {
                          hasAccess = _myProgramIds.contains(data['programId']);
                        }
                        
                        // Filter 2: Search Match
                        bool matchesSearch = title.contains(_searchQuery);
                        
                        return hasAccess && matchesSearch;
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
                               Icon(_searchQuery.isEmpty ? Icons.analytics_outlined : Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
                               const SizedBox(height: 16),
                               Text(
                                 _searchQuery.isEmpty ? "No published events found." : "No events match '$_searchQuery'", 
                                 style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500)
                               ),
                             ],
                           ),
                         ).animate().fadeIn();
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          final data = event.data() as Map<String, dynamic>;
                          
                          final title = data['title'] ?? data['name'] ?? 'Untitled Event';
                          final date = data['date'] ?? 'N/A';
                          final filled = data['filledSeats'] ?? 0;
                          final total = data['maxSeats'] ?? 100;
                          final String? poster = data['posterLink'];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900] : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                )
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (poster != null && poster.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                      child: Image.network(
                                        poster,
                                        height: 140,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                          height: 140,
                                          width: double.infinity,
                                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                                          child: Icon(Icons.event, color: Theme.of(context).primaryColor),
                                        ),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title, 
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            _infoBadge(Icons.calendar_today_rounded, date, Colors.blue),
                                            const SizedBox(width: 12),
                                            _infoBadge(Icons.people_alt_rounded, "$filled Registered", Colors.orange),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: LinearProgressIndicator(
                                            value: total > 0 ? filled / total : 0,
                                            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                                            color: Theme.of(context).primaryColor,
                                            minHeight: 8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: 0.1);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label, 
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
