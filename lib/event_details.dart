import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'event_registration_screen.dart';

class EventDetailsScreen extends StatelessWidget {
  final DocumentSnapshot event;

  const EventDetailsScreen({super.key, required this.event});

  void _showFullImage(BuildContext context, String? url) {
    if (url == null || url.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF8F9FE),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black26,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: event.reference.snapshots(),
        initialData: event,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          // Extracting data
          final String visibility = data['visibility'] ?? "public";
          final bool isCollegeOnly = visibility == "college";
          final String collegeName = data['college'] ?? "Unknown College";
          final dynamic rawPrize = data['prizeAmount'] ?? data['prizePool'] ?? data['pricePool'] ?? data['prize'];
          final String prizeText = rawPrize?.toString() ?? "";
          final bool hasPrize = prizeText.trim().isNotEmpty;
          final String title = data['title'] ?? data['name'] ?? 'Untitled Event';
          final String description = data['description'] ?? 'No description provided.';
          final String date = data['date'] ?? 'TBD';
          final String venue = data['location'] ?? data['venue'] ?? 'TBD';
          final String time = data['time'] ?? 'TBD';
          final String initialClubName = data['clubName'] ?? 'Club';
          final String clubId = data['clubId'] ?? '';
          final String coordinatorName = data['coordinatorName'] ?? 'TBD';
          final String? imageUrl = data['posterLink'] ?? data['imageUrl'];
          final String eventMode = data['eventMode'] ?? 'TBD';
          final winners = data['manualWinners'] as Map<String, dynamic>? ?? {};
          final hasWinners = winners.values.any((v) => v.toString().trim().isNotEmpty);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- VIBRANT HEADER ---
                GestureDetector(
                  onTap: () => _showFullImage(context, imageUrl),
                  child: _buildHeader(imageUrl, hasPrize, prizeText),
                ),

                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161616) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- TITLE & VISIBILITY ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 28, 
                                  fontWeight: FontWeight.w900, 
                                  letterSpacing: -0.8,
                                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                ),
                              ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2),
                            ),
                            const SizedBox(width: 12),
                            _buildModernVisibilityBadge(isCollegeOnly),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // --- ORGANIZED BY (PILL STYLE) ---
                        _buildOrganizerPill(collegeName),
                        
                        const SizedBox(height: 32),
                        
                        // --- INFO TILES (FLOATING STYLE) ---
                        _buildFloatingInfoTiles(date, time, eventMode, venue, isDark),

                        const SizedBox(height: 40),

                        // --- ABOUT SECTION ---
                        _buildSectionHeader("About Event", Icons.info_outline, isDark),
                        const SizedBox(height: 12),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 16, 
                            color: isDark ? Colors.grey[400] : Colors.grey[700], 
                            height: 1.6,
                            letterSpacing: 0.2,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // --- WINNERS SECTION ---
                        if (hasWinners) ...[
                          _buildModernWinnersSection(winners, isDark),
                          const SizedBox(height: 40),
                        ],

                        // --- ORGANIZER INFO ---
                        _buildOrganizerCard(initialClubName, clubId, coordinatorName, isDark),

                        const SizedBox(height: 32),

                        // --- EXTRA INFO (TEAM/VOLUNTEER) ---
                        if ((data['requiresVolunteers'] ?? false) == true || (data['isTeamEvent'] ?? false) == true)
                          _buildExtraInfoSection(data),
                      ],
                    ),
                  ),
                ).animate().slideY(begin: 0.2, duration: 500.ms, curve: Curves.easeOut),
              ],
            ),
          );
        },
      ),
      bottomSheet: user != null 
        ? StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('registrations')
                .where('userId', isEqualTo: user.uid)
                .where('eventId', isEqualTo: event.id)
                .snapshots(),
            builder: (context, snapshot) {
              final isAlreadyRegistered = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
              return _buildBottomAction(context, event, isAlreadyRegistered);
            },
          )
        : _buildBottomAction(context, event, false),
    );
  }

  Widget _buildHeader(String? url, bool hasPrize, String prize) {
    return Stack(
      children: [
        Hero(
          tag: 'event_image_${event.id}',
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              child: url != null && url.isNotEmpty
                  ? Image.network(url, fit: BoxFit.fitWidth)
                  : Container(
                      height: 300, 
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_outlined, size: 80, color: Colors.grey),
                    ),
            ),
          ),
        ),
        Positioned(
          top: 40,
          right: 24,
          child: CircleAvatar(
            backgroundColor: Colors.black45,
            radius: 18,
            child: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
          ),
        ),
        if (hasPrize)
          Positioned(
            bottom: 30,
            left: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5722).withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    "₹ $prize Pool",
                    style: const TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.w900, 
                      fontSize: 20,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ).animate().shimmer(duration: 2.seconds).shake(hz: 2, offset: const Offset(2, 0)),
          ),
      ],
    );
  }

  Widget _buildOrganizerPill(String college) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF673AB7).withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF673AB7).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.school_rounded, size: 16, color: Color(0xFF673AB7)),
          const SizedBox(width: 8),
          Text(
            college,
            style: const TextStyle(
              color: Color(0xFF673AB7), 
              fontWeight: FontWeight.w800, 
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF673AB7)),
        const SizedBox(width: 10),
        Text(
          title, 
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingInfoTiles(String date, String time, String mode, String venue, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            _floatingTile(Icons.calendar_today_rounded, "Date", date, isDark),
            const SizedBox(width: 16),
            _floatingTile(Icons.schedule_rounded, "Time", time, isDark),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _floatingTile(mode == 'Online' ? Icons.videocam_rounded : Icons.sensors_rounded, "Mode", mode, isDark),
            const SizedBox(width: 16),
            _floatingTile(Icons.map_rounded, "Venue", venue, isDark),
          ],
        ),
      ],
    );
  }

  Widget _floatingTile(IconData icon, String label, String value, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
          ],
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFF0F0F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF673AB7).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF673AB7)),
            ),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Text(
              value, 
              style: TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF2D2D2D),
              ), 
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizerCard(String initialClubName, String clubId, String coordinator, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF1E1E1E), const Color(0xFF252525)] 
              : [const Color(0xFFF0EFFF), const Color(0xFFF9F8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF673AB7).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF673AB7).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.groups_3_rounded, color: Color(0xFF673AB7), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Organized By", 
                  style: TextStyle(
                    fontSize: 11, 
                    color: const Color(0xFF673AB7).withOpacity(0.8), 
                    fontWeight: FontWeight.w900, 
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                if (clubId.isNotEmpty && (initialClubName == 'Club' || initialClubName.isEmpty))
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('clubs').doc(clubId).get(),
                    builder: (context, snapshot) {
                      String name = initialClubName;
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final d = snapshot.data!.data() as Map<String, dynamic>;
                        name = d['clubName'] ?? d['name'] ?? initialClubName;
                      }
                      return Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1A1A1A)));
                    },
                  )
                else
                  Text(initialClubName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text(
                  "Coordinator: $coordinator", 
                  style: TextStyle(
                    fontSize: 13, 
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraInfoSection(Map<String, dynamic> data) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (data['isTeamEvent'] == true)
          _vibrantChip(Icons.diversity_3_rounded, "Team Event: ${data['teamSize'] ?? 'N/A'}", const Color(0xFF9C27B0)),
        if (data['requiresVolunteers'] == true)
          _vibrantChip(Icons.volunteer_activism_rounded, "Volunteers: ${data['volunteerCount'] ?? 'N/A'}", const Color(0xFFF44336)),
      ],
    );
  }

  Widget _vibrantChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label, 
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildModernWinnersSection(Map<String, dynamic> winners, bool isDark) {
    // Sort entries based on rank string (1st, 2nd, 3rd)
    final sortedEntries = winners.entries
        .where((e) => e.value.toString().trim().isNotEmpty)
        .toList();
    
    sortedEntries.sort((a, b) {
      final rankA = a.key.toLowerCase();
      final rankB = b.key.toLowerCase();
      
      int getRankValue(String r) {
        if (r.contains('1')) return 1;
        if (r.contains('2')) return 2;
        if (r.contains('3')) return 3;
        return 99;
      }
      return getRankValue(rankA).compareTo(getRankValue(rankB));
    });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFFEF7EE),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.orange.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Event Champions", Icons.emoji_events_outlined, isDark),
          const SizedBox(height: 24),
          ...sortedEntries.map((e) {
            final String rank = e.key.toLowerCase();
            Color rankColor;
            
            if (rank.contains('1')) {
              rankColor = const Color(0xFFFFD700); // Gold
            } else if (rank.contains('2')) {
              rankColor = const Color(0xFFC0C0C0); // Silver
            } else if (rank.contains('3')) {
              rankColor = const Color(0xFFCD7F32); // Bronze
            } else {
              rankColor = Colors.orange;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: rankColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: rankColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            rank.contains('1') ? "🥇" : rank.contains('2') ? "🥈" : rank.contains('3') ? "🥉" : "⭐",
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.value.toString().toUpperCase(),
                                style: TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                e.key.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11, 
                                  fontWeight: FontWeight.bold,
                                  color: rankColor,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (rank.contains('1'))
                          const Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 20)
                              .animate(onPlay: (controller) => controller.repeat())
                              .shimmer(duration: 2.seconds)
                              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildModernVisibilityBadge(bool isCollegeOnly) {
    final color = isCollegeOnly ? const Color(0xFFFF5252) : const Color(0xFF4CAF50);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Text(
        isCollegeOnly ? "COLLEGE ONLY" : "PUBLIC",
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context, DocumentSnapshot doc, bool isRegistered) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final isTeam = data['isTeamEvent'] == true;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), 
            blurRadius: 30, 
            offset: const Offset(0, -10),
          )
        ],
      ),
      child: Hero(
        tag: 'register_button_${event.id}',
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 64),
            backgroundColor: isRegistered ? const Color(0xFF4CAF50) : const Color(0xFF673AB7),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 12,
            shadowColor: (isRegistered ? const Color(0xFF4CAF50) : const Color(0xFF673AB7)).withOpacity(0.5),
          ),
          onPressed: isRegistered ? null : () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => EventRegistrationScreen(event: doc)));
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isRegistered ? Icons.task_alt_rounded : Icons.rocket_launch_rounded, size: 26),
              const SizedBox(width: 14),
              Text(
                isRegistered ? "READY TO GO!" : (isTeam ? "REGISTER TEAM" : "RESERVE MY SPOT"),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
