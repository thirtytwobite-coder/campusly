import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import 'package:intl/intl.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  final String? clubId;
  final List<String>? clubIds;
  final String? clubName;
  final String? collegeName;
  final String? coordinatorId; // Added coordinatorId

  const AnalyticsDashboardScreen({
    super.key,
    this.clubId,
    this.clubIds,
    this.clubName,
    this.collegeName,
    this.coordinatorId,
  });

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allEventStats = [];
  List<Map<String, dynamic>> _filteredEventStats = [];
  int _totalRegistrations = 0;
  int _totalEvents = 0;
  int _lowParticipationCount = 0; // Added count for low participation
  int _maxEventCount = 0;
  String _filter = 'All'; // 'All', 'Upcoming', 'Completed', 'Low'

  Set<String> _myProgramIds = {};

  @override
  void initState() {
    super.initState();
    _fetchMyData();
  }

  Future<void> _fetchMyData() async {
    if (widget.coordinatorId != null && widget.clubId != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('programs')
          .where('coordinatorId', isEqualTo: widget.coordinatorId)
          .get();
      _myProgramIds = snapshot.docs.map((d) => d.id).toSet();
    }
    await _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    try {
      Query<Map<String, dynamic>> eventsQuery = FirebaseFirestore.instance.collection('events');

      if (widget.clubId != null) {
        eventsQuery = eventsQuery.where('clubId', isEqualTo: widget.clubId);
      } else if (widget.clubIds != null && widget.clubIds!.isNotEmpty) {
        eventsQuery = eventsQuery.where('clubId', whereIn: widget.clubIds);
      } else if (widget.collegeName != null) {
        final clubsSnap = await FirebaseFirestore.instance
            .collection('clubs')
            .where('college', isEqualTo: widget.collegeName)
            .get();
        
        List<String> clubIds = clubsSnap.docs.map((d) => d.id).toList();
        if (clubIds.isEmpty) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        eventsQuery = eventsQuery.where('clubId', whereIn: clubIds);
      }

      final eventsSnap = await eventsQuery.get();

      List<Map<String, dynamic>> stats = [];
      int totalRegs = 0;
      final now = DateTime.now();

      final filteredDocs = eventsSnap.docs.where((doc) {
        if (widget.coordinatorId != null) {
          final pId = doc.data()['programId'];
          return _myProgramIds.contains(pId);
        }
        return true;
      }).toList();

      for (var doc in filteredDocs) {
        final data = doc.data();
        final eventId = doc.id;
        final title = data['title'] ?? 'Unknown';
        final clubId = data['clubId'];
        final programId = data['programId'];

        // Get registrations count
        final regsSnap = await FirebaseFirestore.instance
            .collection('registrations')
            .where('eventId', isEqualTo: eventId)
            .get();

        int count = regsSnap.docs.length;
        totalRegs += count;

        // Fetch event date from programs subcollection
        DateTime? eventDate;
        if (clubId != null && programId != null) {
          final programDoc = await FirebaseFirestore.instance
              .collection('clubs')
              .doc(clubId)
              .collection('programs')
              .doc(programId)
              .get();
          
          if (programDoc.exists) {
            final pData = programDoc.data();
            final dateStr = pData?['date'];
            if (dateStr != null) {
              try {
                eventDate = DateFormat('yyyy-MM-dd').parse(dateStr);
              } catch (_) {}
            }
          }
        }

        bool isUpcoming = eventDate == null || eventDate.isAfter(now) || 
                         (eventDate.year == now.year && eventDate.month == now.month && eventDate.day == now.day);

        stats.add({
          'id': eventId,
          'title': title,
          'count': count,
          'date': eventDate,
          'isUpcoming': isUpcoming,
          'visibility': data['visibility'] ?? 'college',
        });
      }

      int lowPartCount = stats.where((s) => (s['count'] as int) < 5).length;

      stats.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      if (mounted) {
        setState(() {
          _allEventStats = stats;
          _applyFilter();
          _totalRegistrations = totalRegs;
          _totalEvents = filteredDocs.length;
          _lowParticipationCount = lowPartCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching analytics: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter() {
    setState(() {
      if (_filter == 'All') {
        _filteredEventStats = _allEventStats;
      } else if (_filter == 'Upcoming') {
        _filteredEventStats = _allEventStats.where((e) => e['isUpcoming'] == true).toList();
      } else if (_filter == 'Low') {
        _filteredEventStats = _allEventStats.where((e) => (e['count'] as int) < 5).toList();
      } else {
        _filteredEventStats = _allEventStats.where((e) => e['isUpcoming'] == false).toList();
      }
      
      if (_filteredEventStats.isNotEmpty) {
        _maxEventCount = _filteredEventStats.map((e) => e['count'] as int).reduce(max);
      } else {
        _maxEventCount = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.clubName != null ? '${widget.clubName} Analytics' : '${widget.collegeName} Analytics'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allEventStats.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No events or registrations data found.",
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildSummaryCards(),
                    const SizedBox(height: 32),
                    _buildFilterSection(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "$_filter Events",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        Text(
                          "Total: ${_filteredEventStats.length}",
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_filteredEventStats.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Icon(Icons.event_busy, size: 48, color: Colors.grey.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              Text("No $_filter events found.", style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._filteredEventStats.map((stat) => _buildEventListItem(stat)),
                  ],
                ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryItem(
            "Total Events",
            _totalEvents.toString(),
            Icons.event,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryItem(
            "Low Participation",
            _lowParticipationCount.toString(),
            Icons.trending_down,
            Colors.orange,
            onTap: () {
              setState(() {
                _filter = 'Low';
                _applyFilter();
              });
            },
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1);
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        elevation: 0,
        color: color.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withOpacity(0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          _buildFilterChip('All'),
          _buildFilterChip('Upcoming'),
          _buildFilterChip('Completed'),
          _buildFilterChip('Low'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = _filter == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _filter = label;
          _applyFilter();
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ] : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventListItem(Map<String, dynamic> stat) {
    double progress = _maxEventCount > 0 ? (stat['count'] as int) / _maxEventCount : 0;
    bool isUpcoming = stat['isUpcoming'];
    DateTime? date = stat['date'];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventParticipantsScreen(
                eventId: stat['id'],
                eventTitle: stat['title'],
                visibility: stat['visibility'],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isUpcoming ? Colors.blue : Colors.orange).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      stat['count'].toString(),
                      style: TextStyle(
                        color: isUpcoming ? Colors.blue : Colors.orange, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat['title'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (date != null)
                          Text(
                            DateFormat('MMM dd, yyyy').format(date),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isUpcoming ? Colors.blue : Colors.green).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isUpcoming ? "UPCOMING" : "COMPLETED",
                      style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold,
                        color: isUpcoming ? Colors.blue : Colors.green
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.withOpacity(0.1),
                  color: isUpcoming ? Colors.blue : Colors.green,
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideX();
  }
}

class EventParticipantsScreen extends StatelessWidget {
  final String eventId;
  final String eventTitle;
  final String visibility;

  const EventParticipantsScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.visibility,
  });

  @override
  Widget build(BuildContext context) {
    bool showCollege = visibility.toLowerCase() != 'college' && visibility.toLowerCase() != 'college only';

    return Scaffold(
      appBar: AppBar(
        title: Text(eventTitle),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('registrations')
            .where('eventId', isEqualTo: eventId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No registrations yet."));
          }

          final regs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: regs.length,
            itemBuilder: (context, index) {
              final data = regs[index].data() as Map<String, dynamic>;
              final name = data['userName'] ?? data['studentName'] ?? 'Unknown User';
              final college = data['college'] ?? data['collegeName'] ?? 'Unknown College';
              final dept = data['department'] ?? data['branch'] ?? '';

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    "${dept.isNotEmpty ? '$dept | ' : ''}${showCollege ? college : (data['college'] ?? data['collegeName'] ?? 'Your College')}",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
