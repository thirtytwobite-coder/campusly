/// This screen displays analytics and statistics for a specific club.
/// It shows event registrations, program details, and approval lists for club coordinators.
/// The screen fetches program IDs associated with the coordinator and provides navigation
/// to detailed event registration lists and approval screens for better club management.

import 'dart:ui' as ui;
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "ANALYTICS",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 2.5,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.15),
            ),
          ),
        ),
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
                return Center(
                  child: GlassCard(
                    margin: const EdgeInsets.all(32),
                    borderRadius: 32,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.analytics_outlined, 
                            size: 80, 
                            color: isDark ? Colors.white12 : Colors.black12
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "No events found.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white38 : Colors.black38
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn().scale();
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 120, 16, 40),
                itemCount: events.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final event = events[index];
                  final data = event.data() as Map<String, dynamic>;
                  final title = data['title'] ?? 'Untitled Event';
                  final date = data['date'] ?? 'N/A';

                  return GlassCard(
                    borderRadius: 24,
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
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.withOpacity(0.08), 
                              Colors.cyan.withOpacity(0.04)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0EA5E9).withOpacity(0.25),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  )
                                ],
                              ),
                              child: const Icon(
                                Icons.bar_chart_rounded, 
                                color: Colors.white, 
                                size: 28
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : Colors.black87,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Event Date: $date",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: isDark ? Colors.white24 : Colors.black12,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: (60 * index).ms).slideX(begin: 0.05, duration: 400.ms);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
