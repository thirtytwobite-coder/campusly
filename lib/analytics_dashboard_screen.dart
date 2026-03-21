import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'vibrant_background.dart';

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

      final now = DateTime.now();
      final filteredDocs = eventsSnap.docs.where((doc) {
        if (widget.coordinatorId != null) {
          final pId = doc.data()['programId'];
          return _myProgramIds.contains(pId);
        }
        return true;
      }).toList();

      // Process events in parallel to significantly improve loading speed
      final results = await Future.wait(filteredDocs.map((doc) async {
        final data = doc.data();
        final eventId = doc.id;
        final title = data['title'] ?? 'Unknown';
        final clubId = data['clubId'];
        final programId = data['programId'];

        // Use count aggregation for faster and cheaper counting
        final regsCountQuery = await FirebaseFirestore.instance
            .collection('registrations')
            .where('eventId', isEqualTo: eventId)
            .count()
            .get();

        int count = regsCountQuery.count ?? 0;

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

        return {
          'id': eventId,
          'title': title,
          'count': count,
          'date': eventDate,
          'isUpcoming': isUpcoming,
          'visibility': data['visibility'] ?? 'college',
        };
      }));

      int totalRegs = 0;
      for (var r in results) {
        totalRegs += (r['count'] as int);
      }

      int lowPartCount = results.where((s) => (s['count'] as int) < 5).length;
      results.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      if (mounted) {
        setState(() {
          _allEventStats = results;
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
        backgroundColor: isDark ? Colors.black : theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          const VibrantBackground(),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _allEventStats.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart_rounded, size: 100, color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  "No insights available yet", 
                  style: TextStyle(fontSize: 18, color: isDark ? Colors.white54 : Colors.grey, fontWeight: FontWeight.w500)
                ),
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
                      _buildSummarySection(isDark),
                      const SizedBox(height: 32),
                      Text(
                        "Filter by Status", 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)
                      ),
                      const SizedBox(height: 16),
                      _buildFilterSection(isDark),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "$_filter Events", 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : Colors.black)
                          ),
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
                        Icon(Icons.event_busy_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text("No $_filter events match", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.9,
                    ),
                    delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildModernGridItem(_filteredEventStats[index], index, isDark),
                      childCount: _filteredEventStats.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: ['All', 'Upcoming', 'Past', 'Low'].map((f) {
          final isSelected = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _filter = f;
                    _applyFilter();
                  });
                }
              },
              selectedColor: Theme.of(context).primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummarySection(bool isDark) {
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
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModernSummaryCard(
                "Registrations",
                _totalRegistrations.toString(),
                Icons.people_alt_rounded,
                Colors.green,
                isDark,
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
          isDark,
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

  Widget _buildModernSummaryCard(String title, String value, IconData icon, Color color, bool isDark, {bool fullWidth = false, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: color.withOpacity(isDark ? 0.05 : 0.1), blurRadius: 20, offset: const Offset(0, 10)),
          ],
          border: Border.all(color: color.withOpacity(isDark ? 0.2 : 0.1), width: 1.5),
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
                  Text(
                    value, 
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)
                  ),
                  Text(
                    title, 
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600], fontWeight: FontWeight.w500)
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernGridItem(Map<String, dynamic> stat, int index, bool isDark) {
    final theme = Theme.of(context);
    final count = stat['count'] as int;
    final color = count < 5 ? Colors.orange : theme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 5)),
        ],
        border: Border.all(color: color.withOpacity(isDark ? 0.2 : 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 70,
                width: 70,
                child: CircularProgressIndicator(
                  value: _maxEventCount > 0 ? count / _maxEventCount : 0,
                  strokeWidth: 8,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                count.toString(),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            stat['title'],
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 4),
          Text(
            stat['date'] != null ? DateFormat('MMM d, yyyy').format(stat['date']) : 'Date TBD',
            style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey[500]),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (50 * index).ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildEventListItem(Map<String, dynamic> stat, int index) {
    // Legacy list item fallback - but now we use Grid
    return const SizedBox.shrink();
  }
}
