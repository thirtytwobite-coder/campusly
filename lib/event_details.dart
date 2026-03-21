import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'event_registration_screen.dart';
import 'vibrant_background.dart';

class EventDetailsScreen extends StatelessWidget {
  final DocumentSnapshot event;

  const EventDetailsScreen({super.key, required this.event});

  void _showFullImage(BuildContext context, String? url) {
    if (url == null || url.isEmpty) return;
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.95),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(color: Colors.transparent),
            ),
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Hero(
                tag: 'event_poster',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: url.startsWith('data:image')
                      ? Image.memory(base64Decode(url.split(',').last), fit: BoxFit.contain)
                      : Image.network(url, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: CircleAvatar(
                backgroundColor: Colors.white24,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const VibrantBackground(),
          StreamBuilder<DocumentSnapshot>(
            stream: event.reference.snapshots(),
            initialData: event,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

              final String title = data['title'] ?? data['name'] ?? 'Untitled Event';
              final String description = data['description'] ?? 'No description provided.';
              final String date = data['date'] ?? 'TBD';
              final String venue = data['location'] ?? data['venue'] ?? 'TBD';
              final String time = data['time'] ?? 'TBD';
              final String clubName = data['clubName'] ?? 'Organizing Club';
              final String clubId = data['clubId'] ?? '';
              final String coordinatorName = data['coordinatorName'] ?? 'TBD';
              final String? imageUrl = data['posterLink'] ?? data['imageUrl'];
              final String eventMode = data['eventMode'] ?? data['mode'] ?? 'Offline';
              final bool isTeamEvent = (data['isTeamEvent'] ?? false) == true;
              final bool requiresVolunteers = (data['requiresVolunteers'] ?? false) == true;
              final int volunteerCount = data['volunteerCount'] ?? 0;
              final String volunteerRole = data['volunteerRole']?.toString() ?? '';
              final Map<String, dynamic>? manualWinners = data['manualWinners'] as Map<String, dynamic>?;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    expandedHeight: 420, 
                    pinned: true,
                    stretch: true,
                    backgroundColor: theme.colorScheme.surface,
                    leading: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.black38,
                        child: const BackButton(color: Colors.white),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      stretchModes: const [StretchMode.zoomBackground],
                      background: GestureDetector(
                        onTap: () => _showFullImage(context, imageUrl),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Hero(
                              tag: 'event_poster',
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                                child: _buildHeaderImage(imageUrl),
                              ),
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black38,
                                    Colors.transparent,
                                    Colors.transparent,
                                    Colors.black87,
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 50,
                              left: 20,
                              right: 20,
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  shadows: [Shadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 2))],
                                ),
                              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -32),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -10))
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 32, 20, 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isTeamEvent) _coloredBadge("TEAM", Colors.deepPurple),
                                  if (requiresVolunteers) _coloredBadge("VOLUNTEER", Colors.orange.shade800),
                                  const Spacer(),
                                  Icon(Icons.share_rounded, color: theme.colorScheme.primary.withOpacity(0.6), size: 20),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _metricsGridDecorated(theme, date, time, venue, eventMode),
                              
                              if (manualWinners != null && manualWinners.values.any((v) => v.toString().isNotEmpty)) ...[
                                const SizedBox(height: 32),
                                _sectionHeader(theme, "Event Winners", Colors.orange.shade700),
                                const SizedBox(height: 12),
                                _buildWinnersSection(manualWinners, theme),
                              ],

                              const SizedBox(height: 32),
                              _sectionHeader(theme, "About Event", Colors.blue),
                              const SizedBox(height: 12),
                              Text(description,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                                      height: 1.7,
                                      fontSize: 15)),
                              const SizedBox(height: 32),
                              _sectionHeader(theme, "Organizer Information", Colors.indigo),
                              const SizedBox(height: 12),
                              
                              // 🔹 Display Club Logo here
                              _buildClubInfoRow(clubId, clubName, theme),
                              const SizedBox(height: 8),
                              _infoCardDecorated(theme, null, Icons.person_rounded, "Event Coordinator", coordinatorName, Colors.indigo),
                              
                              if (requiresVolunteers) ...[
                                const SizedBox(height: 32),
                                _sectionHeader(theme, "Volunteering Opportunities", Colors.green),
                                const SizedBox(height: 12),
                                _volunteerSectionVibrant(theme, volunteerCount, volunteerRole),
                              ],
                              
                              const SizedBox(height: 32),
                              _buildParticipationDetails(context, user?.uid, event.id, theme, isTeamEvent),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAction(context, event, theme),
    );
  }

  Widget _buildClubInfoRow(String clubId, String clubName, ThemeData theme) {
    if (clubId.isEmpty) return _infoCardDecorated(theme, null, Icons.hub_rounded, "Organizing Club", clubName, Colors.indigo);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('clubs').doc(clubId).snapshots(),
      builder: (context, snapshot) {
        String? logo;
        if (snapshot.hasData && snapshot.data!.exists) {
          logo = snapshot.data!.get('profilePic');
        }
        return _infoCardDecorated(theme, logo, Icons.hub_rounded, "Organizing Club", clubName, Colors.indigo);
      },
    );
  }

  Widget _buildWinnersSection(Map<String, dynamic> winners, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    List<Widget> winnerItems = [];
    
    final ranks = ['1st', '2nd', '3rd'];
    final colors = [Colors.amber.shade700, Colors.blueGrey.shade400, Colors.brown.shade400];
    final icons = [Icons.workspace_premium, Icons.military_tech, Icons.emoji_events];

    for (int i = 0; i < ranks.length; i++) {
      final name = winners[ranks[i]]?.toString() ?? '';
      if (name.isNotEmpty) {
        winnerItems.add(
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors[i].withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors[i].withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: colors[i].withOpacity(0.2), shape: BoxShape.circle),
                  child: Icon(icons[i], color: colors[i], size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ranks[i].toUpperCase() + " PLACE", 
                        style: TextStyle(color: colors[i], fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                      Text(name, 
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: (100 * i).ms).slideX(begin: 0.1),
        );
      }
    }

    return Column(children: winnerItems);
  }

  Widget _sectionHeader(ThemeData theme, String title, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.2)),
      ],
    );
  }

  Widget _coloredBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10)),
    );
  }

  Widget _metricsGridDecorated(ThemeData theme, String date, String time, String venue, String mode) {
    return Column(
      children: [
        Row(
          children: [
            _metricItemVibrant(theme, Icons.calendar_today_rounded, "DATE", date, Colors.blue),
            const SizedBox(width: 12),
            _metricItemVibrant(theme, Icons.access_time_filled_rounded, "TIME", time, Colors.amber.shade700),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _metricItemVibrant(theme, Icons.location_on_rounded, "VENUE", venue, Colors.teal),
            const SizedBox(width: 12),
            _metricItemVibrant(theme, mode == 'Online' ? Icons.videocam_rounded : Icons.business_center_rounded, "MODE", mode, Colors.pink.shade400),
          ],
        ),
      ],
    );
  }

  Widget _metricItemVibrant(ThemeData theme, IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color.withOpacity(0.7))),
                  Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCardDecorated(ThemeData theme, String? imageUrl, IconData fallbackIcon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? (imageUrl.startsWith('data:image')
                      ? Image.memory(base64Decode(imageUrl.split(',').last), fit: BoxFit.cover)
                      : Image.network(_convertGoogleDriveLink(imageUrl), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(fallbackIcon, size: 20, color: color)))
                  : Icon(fallbackIcon, size: 20, color: color),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w700)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _convertGoogleDriveLink(String link) {
    if (link.isEmpty) return '';
    if (link.contains('drive.google.com/uc?export=view')) return link;
    final regex = RegExp(r'(?:drive\.google\.com/file/d/|id=)([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(link);
    if (match != null) return 'https://drive.google.com/uc?export=view&id=${match.group(1)}';
    return link;
  }

  Widget _volunteerSectionVibrant(ThemeData theme, int count, String role) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volunteer_activism_rounded, size: 24, color: Colors.white),
              const SizedBox(width: 12),
              Text("$count Positions Open", 
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
            ],
          ),
          if (role.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(role, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500)),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildParticipationDetails(BuildContext context, String? userId, String eventId, ThemeData theme, bool isTeamEvent) {
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('registrations')
          .where('eventId', isEqualTo: eventId)
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        
        final regData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final String? teamId = regData['teamId'];
        final bool isVolunteer = regData['registrationType']?.toString().toLowerCase() == 'volunteer';
        final String? assignedTask = regData['assignedTask']?.toString();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isVolunteer) ...[
              _sectionHeader(theme, "Your Volunteer Assignment", Colors.indigo),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade600,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 12)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.task_alt_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(assignedTask?.isNotEmpty == true ? assignedTask! : "Coordinator will assign your task soon...",
                        style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ).animate().fadeIn(),
              const SizedBox(height: 32),
            ],
            if (isTeamEvent && teamId != null) ...[
              _sectionHeader(theme, "My Team Squad", theme.colorScheme.primary),
              const SizedBox(height: 12),
              _buildTeamSectionVibrant(teamId, theme),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTeamSectionVibrant(String teamId, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('registrations').where('teamId', isEqualTo: teamId).snapshots(),
        builder: (context, teamSnap) {
          if (!teamSnap.hasData) return const SizedBox.shrink();
          return ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: teamSnap.data!.docs.length,
            itemBuilder: (context, index) {
              final memberDoc = teamSnap.data!.docs[index].data() as Map<String, dynamic>;
              final String name = memberDoc['studentName'] ?? 'Unknown';
              final bool isLeader = memberDoc['isTeamLeader'] ?? false;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18, 
                      backgroundColor: theme.primaryColor.withOpacity(0.1), 
                      child: Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(color: theme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold))
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                    if (isLeader) _coloredBadge("LEADER", Colors.amber.shade900),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeaderImage(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_outlined, size: 80, color: Colors.grey),
      );
    }

    return url.startsWith('data:image') 
        ? Image.memory(base64Decode(url.split(',').last), fit: BoxFit.cover, 
            errorBuilder: (c, e, s) => Container(color: Colors.grey.shade100, child: const Icon(Icons.broken_image)))
        : Image.network(url, fit: BoxFit.cover, 
            errorBuilder: (c, e, s) => Container(color: Colors.grey.shade100, child: const Icon(Icons.broken_image)));
  }

  Widget _buildBottomAction(BuildContext context, DocumentSnapshot eventDoc, ThemeData theme) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('registrations')
          .where('eventId', isEqualTo: eventDoc.id)
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final bool isRegistered = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        final data = eventDoc.data() as Map<String, dynamic>? ?? {};
        final bool isTeamEvent = (data['isTeamEvent'] ?? false) == true;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5)),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 64),
              backgroundColor: isRegistered ? Colors.grey.shade200 : theme.primaryColor,
              foregroundColor: isRegistered ? Colors.grey : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: isRegistered ? 0 : 12,
              shadowColor: theme.primaryColor.withOpacity(0.5),
            ),
            onPressed: isRegistered ? null : () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => EventRegistrationScreen(event: eventDoc)));
            },
            child: Text(
              isRegistered ? "ALREADY REGISTERED" : (isTeamEvent ? "REGISTER YOUR TEAM" : "RESERVE MY SPOT"),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
          ),
        );
      },
    );
  }
}
