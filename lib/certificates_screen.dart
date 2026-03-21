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
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        title: Text("${widget.clubName} Certificates"),
        elevation: 0,
        backgroundColor: isDark ? Colors.black : theme.primaryColor,
        foregroundColor: Colors.white,
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
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: GlassCard(
                            borderRadius: 15,
                            child: TextField(
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value.toLowerCase();
                                });
                              },
                              decoration: InputDecoration(
                                hintText: "Search events...",
                                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                                prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.black54),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
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
                                      Icon(Icons.event_busy, size: 80, color: isDark ? Colors.white24 : Colors.grey[300]),
                                      const SizedBox(height: 16),
                                      Text("No events found", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 16)),
                                    ],
                                  ),
                                );
                              }

                              return GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.85,
                                ),
                                itemCount: events.length,
                                itemBuilder: (context, index) {
                                  final event = events[index];
                                  final data = event.data() as Map<String, dynamic>;
                                  final title = data['title'] ?? 'Untitled Event';
                                  final date = data['date'] ?? 'N/A';

                                  return _buildCertificateGridItem(event.id, title, date, index, isDark, clubLogo);
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

  Widget _buildCertificateGridItem(String eventId, String title, String date, int index, bool isDark, String? clubLogo) {
    final theme = Theme.of(context);
    return GlassCard(
      borderRadius: 24,
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
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                ),
                child: ClipOval(
                  child: (clubLogo != null && clubLogo.isNotEmpty)
                      ? (clubLogo.startsWith('data:image')
                          ? Image.memory(base64Decode(clubLogo.split(',').last), fit: BoxFit.cover)
                          : Image.network(
                              _convertGoogleDriveLink(clubLogo),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.workspace_premium_rounded, color: isDark ? Colors.blueAccent : theme.primaryColor, size: 28)
                            ))
                      : Icon(Icons.workspace_premium_rounded, color: isDark ? Colors.blueAccent : theme.primaryColor, size: 28),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (50 * index).ms).scale(begin: const Offset(0.9, 0.9));
  }
}
