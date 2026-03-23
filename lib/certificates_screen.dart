import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'event_registrations_list.dart';
import 'list_approval_screen.dart';
import 'vibrant_background.dart';
import 'dart:convert';

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
    this.isFaculty = false,
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

  String _convertGoogleDriveLink(String link) {
    if (link.isEmpty) return '';
    if (link.contains('drive.google.com/uc?export=view')) return link;
    final regex = RegExp(r'(?:drive\.google\.com/file/d/|id=)([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(link);
    if (match != null) return 'https://drive.google.com/uc?export=view&id=${match.group(1)}';
    return link;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent, // Let the background show through
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.clubName.toLowerCase().contains("mulearn") ? "µLearn Certificates" : "${widget.clubName} Certificates",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -1),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.2),
            ),
          ),
        ),
        actions: [
          if (widget.isFaculty)
            IconButton(
              icon: const Icon(Icons.playlist_add_check_rounded),
              tooltip: 'Approve Lists',
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
              : StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).snapshots(),
                  builder: (context, clubSnap) {
                    if (clubSnap.connectionState == ConnectionState.waiting && !clubSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final clubData = clubSnap.data?.data() as Map<String, dynamic>?;
                    final String? clubLogo = clubData?['profilePic'];

                    return Column(
                      children: [
                        const SizedBox(height: 100), // Space for AppBar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
                          child: GlassCard(
                            borderRadius: 20,
                            blur: 10,
                            child: TextField(
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value.toLowerCase();
                                });
                              },
                              decoration: InputDecoration(
                                hintText: "Search events...",
                                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
                                prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.blueAccent : theme.primaryColor, size: 22),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                filled: true,
                                fillColor: Colors.transparent,
                              ),
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
                              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                              final allEvents = snapshot.data?.docs ?? [];
                              var events = allEvents.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
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
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: (isDark ? Colors.blueAccent : theme.primaryColor).withOpacity(0.05),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.event_busy_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        "No events found",
                                        style: TextStyle(
                                          color: isDark ? Colors.white54 : Colors.grey[600],
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: events.length,
                                itemBuilder: (context, index) {
                                  final event = events[index];
                                  final data = event.data() as Map<String, dynamic>;
                                  final title = data['title'] ?? 'Untitled Event';
                                  final date = data['date'] ?? 'N/A';

                                  return _buildCertificateListItem(event.id, title, date, index, isDark, clubLogo);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }
                ),
        ],
      ),
    );
  }

  Widget _buildCertificateListItem(String eventId, String title, String date, int index, bool isDark, String? clubLogo) {
    final muOrange = const Color(0xFFFFB200);
    final muBlue = const Color(0xFF00B2FF);
    final accentColor = isDark ? muOrange : muBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderRadius: 24,
        blur: 15,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventRegistrationsListScreen(
                  eventId: eventId,
                  eventName: title,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Hero(
                  tag: 'cert-logo-$eventId',
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.1),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(color: accentColor.withOpacity(0.2), width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: ClipOval(
                        child: (clubLogo != null && clubLogo.isNotEmpty)
                            ? (clubLogo.startsWith('data:image')
                                ? Image.memory(base64Decode(clubLogo.split(',').last), fit: BoxFit.cover)
                                : Image.network(
                                    _convertGoogleDriveLink(clubLogo),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(Icons.workspace_premium_rounded, color: accentColor, size: 30)
                                  ))
                            : Icon(Icons.workspace_premium_rounded, color: accentColor, size: 30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 10, color: accentColor),
                                const SizedBox(width: 5),
                                Text(
                                  date,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.clubName.toLowerCase().contains("mulearn"))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: muOrange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: muOrange.withOpacity(0.2)),
                              ),
                              child: const Text(
                                "µLearn",
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFFFB200)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.black12, size: 28),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (40 * index).ms, duration: 400.ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}
