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
  final String? coordinatorId;

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
  int _lowParticipationCount = 0;
  int _maxEventCount = 0;
  String _filter = 'All';

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

        final regsSnap = await FirebaseFirestore.instance
            .collection('registrations')
            .where('eventId', isEqualTo: eventId)
            .get();

        int count = regsSnap.docs.length;
        totalRegs += count;

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
      if (mounted) setState(() => _isLoading = false);
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
        _maxEventCount = _allEventStats.map((e) => e['count'] as int).reduce(max);
      } else {
        _maxEventCount = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == ThemeMode.dark || theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.clubName != null ? '${widget.clubName} Analytics' : '${widget.collegeName} Analytics',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allEventStats.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 100, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text("No insights available yet", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500)),
          ],
        ),
      )
          : CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummarySection(),
                  const SizedBox(height: 32),
                  const Text("Filter by Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildFilterSection(),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("$_filter Events", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Count: ${_filteredEventStats.length}",
                          style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (_filteredEventStats.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text("No $_filter events match", style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildEventListItem(_filteredEventStats[index], index),
                  childCount: _filteredEventStats.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildModernSummaryCard(
                "Total Events",
                _totalEvents.toString(),
                Icons.event_note_rounded,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModernSummaryCard(
                "Registrations",
                _totalRegistrations.toString(),
                Icons.people_alt_rounded,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildModernSummaryCard(
          "Low Participation Events (<5)",
          _lowParticipationCount.toString(),
          Icons.trending_down_rounded,
          Colors.orange,
          fullWidth: true,
          onTap: () {
            setState(() {
              _filter = 'Low';
              _applyFilter();
            });
          },
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1);
  }

  Widget _buildModernSummaryCard(String title, String value, IconData icon, Color color, {bool fullWidth = false, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
          ],
          border: Border.all(color: color.withOpacity(0.1), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                  Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildModernFilterChip('All', Icons.grid_view_rounded),
          _buildModernFilterChip('Upcoming', Icons.upcoming_rounded),
          _buildModernFilterChip('Completed', Icons.task_alt_rounded),
          _buildModernFilterChip('Low', Icons.warning_amber_rounded),
        ],
      ),
    );
  }

  Widget _buildModernFilterChip(String label, IconData icon) {
    bool isSelected = _filter == label;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _filter = label;
            _applyFilter();
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? theme.primaryColor : Colors.grey.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: isSelected ? [
              BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
            ] : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventListItem(Map<String, dynamic> stat, int index) {
    double progress = _maxEventCount > 0 ? (stat['count'] as int) / _maxEventCount : 0;
    bool isUpcoming = stat['isUpcoming'];
    DateTime? date = stat['date'];
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
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
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: (isUpcoming ? Colors.blue : Colors.green).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        stat['count'].toString(),
                        style: TextStyle(
                            color: isUpcoming ? Colors.blue : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 18
                        ),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              date != null ? DateFormat('MMM dd, yyyy').format(date) : "Date TBD",
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isUpcoming ? Colors.blue : Colors.grey).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isUpcoming ? "UPCOMING" : "COMPLETED",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isUpcoming ? Colors.blue : Colors.grey[600]
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.withOpacity(0.1),
                        color: isUpcoming ? Colors.blue : Colors.green,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "${(progress * 100).toInt()}%",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    bool showCollege = visibility.toLowerCase() != 'college' && visibility.toLowerCase() != 'college only';

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        title: Column(
          children: [
            Text(eventTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Text("Participants List", style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline_rounded, size: 80, color: Colors.grey.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text("No registrations found", style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          final regs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            itemCount: regs.length,
            itemBuilder: (context, index) {
              final data = regs[index].data() as Map<String, dynamic>;
              final name = data['userName'] ?? data['studentName'] ?? 'Unknown User';
              final college = data['college'] ?? data['collegeName'] ?? 'Unknown College';
              final dept = data['department'] ?? data['branch'] ?? 'N/A';
              final ktuId = data['ktuId'] ?? 'N/A';
              final email = data['studentEmail'] ?? data['email'] ?? 'N/A';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: ExpansionTile(
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    child: Text(
                      name[0].toUpperCase(),
                      style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(
                    dept,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  childrenPadding: const EdgeInsets.all(16),
                  expandedAlignment: Alignment.topLeft,
                  children: [
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildDetailRow(Icons.school_rounded, "College", showCollege ? college : "Your College"),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.badge_rounded, "KTU ID", ktuId),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.email_rounded, "Email", email),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.account_tree_rounded, "Department", dept),
                  ],
                ),
              ).animate().fadeIn(delay: (30 * index).ms).slideY(begin: 0.1);
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: Colors.grey[600]),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}
