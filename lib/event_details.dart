/// This screen displays detailed information about a specific event.
/// It shows event title, date, time, venue, description, and organizer details.
/// The screen allows users to register for the event, share event details with others,
/// and view event images. It also provides navigation to the event registration screen
/// and handles deep linking for event sharing.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'event_registration_screen.dart';
import 'vibrant_background.dart';
import 'profile_screen.dart';

class EventDetailsScreen extends StatelessWidget {
  final DocumentSnapshot event;

  const EventDetailsScreen({super.key, required this.event});

  Future<void> _shareEvent(BuildContext context, String title, String date, String time, String venue, String mode, String clubName, String description, String? imageUrl) async {
    final String deepLink = 'https://campusly.app/event?id=${event.id}';
    final String shareText = '''
Check out this event on Campusly! 🚀

Event: $title
📅 Date: $date
⏰ Time: $time
📍 Venue: $venue
🎥 Mode: $mode
🏢 Organized by: $clubName

Description:
$description

View event details here: $deepLink
''';

    try {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        final String finalImageUrl = _convertGoogleDriveLink(imageUrl);
        final response = await http.get(Uri.parse(finalImageUrl));
        
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final tempDir = await getTemporaryDirectory();
          final path = '${tempDir.path}/event_poster_${DateTime.now().millisecondsSinceEpoch}.png';
          final file = File(path);
          await file.writeAsBytes(bytes);

          if (context.mounted) Navigator.pop(context); // Remove loading indicator

          await Share.shareXFiles(
            [XFile(file.path)],
            text: shareText,
            subject: 'Event: $title',
          );
        } else {
          throw Exception('Failed to load image');
        }
      } else {
        await Share.share(shareText, subject: 'Event: $title');
      }
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      debugPrint("Error sharing event: $e");
      // Fallback to text only if image sharing fails
      await Share.share(shareText, subject: 'Event: $title');
    }
  }

  void _showFullImage(BuildContext context, String? url) {
    if (url == null || url.isEmpty) return;
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.9),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) => FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: anim1.drive(Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic))),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Scaffold(
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
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 10))],
                          ),
                          child: url.startsWith('data:image')
                              ? Image.memory(base64Decode(url.split(',').last), fit: BoxFit.contain)
                              : Image.network(url, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 50,
                    right: 25,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
              
              // CAPACITY LOGIC
              final int filledSeats = data['filledSeats'] is int ? data['filledSeats'] : int.tryParse(data['filledSeats']?.toString() ?? '') ?? 0;
              final dynamic tsData = data['totalSeats'] ?? data['capacity'] ?? data['maxSeats'];
              final String totalSeatsStr = tsData?.toString() ?? '';
              final int totalSeats = int.tryParse(totalSeatsStr) ?? 0;
              final bool isUnlimited = totalSeatsStr.isEmpty || totalSeatsStr.toLowerCase() == 'unlimited' || totalSeats <= 0;
              final int remainingSeats = isUnlimited ? -1 : (totalSeats - filledSeats > 0 ? totalSeats - filledSeats : 0);
              final String volunteerRole = data['volunteerRole']?.toString() ?? '';
              final Map<String, dynamic>? manualWinners = data['manualWinners'] as Map<String, dynamic>?;

              final bool hasHeader = imageUrl != null && imageUrl.trim().isNotEmpty;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    expandedHeight: hasHeader ? 420 : kToolbarHeight + 32,
                    pinned: true,
                    stretch: true,
                    backgroundColor: Colors.transparent,
                    centerTitle: !hasHeader,
                    title: !hasHeader
                      ? Text(title, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.0, fontSize: 24))
                      : null,
                    leading: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), width: 1),
                            ),
                            child: BackButton(color: isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                    flexibleSpace: hasHeader ? FlexibleSpaceBar(
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
                    ) : null,
                  ),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: Offset(0, hasHeader ? -32 : 0),
                      child: GlassCard(
                        borderRadius: 32,
                        blur: 20,
                        color: theme.colorScheme.surface.withOpacity(0.1),
                        border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), width: 1.5),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isTeamEvent) _coloredBadge("TEAM", Colors.deepPurple),
                                  if (requiresVolunteers) _coloredBadge("VOLUNTEER", Colors.orange.shade800),
                                  const Spacer(),
                                  IconButton(
                                    icon: Icon(Icons.share_rounded, color: theme.colorScheme.primary.withOpacity(0.6), size: 22),
                                    onPressed: () => _shareEvent(context, title, date, time, venue, eventMode, clubName, description, imageUrl),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _metricsGridDecorated(theme, date, time, venue, eventMode, isUnlimited, remainingSeats, totalSeats, data['registrationDeadlineDate'], data['registrationDeadlineTime']),
                              
                              if (manualWinners != null && manualWinners.values.any((v) => v.toString().isNotEmpty)) ...[
                                const SizedBox(height: 32),
                                _sectionHeader(theme, "Winners", Colors.orange.shade700),
                                const SizedBox(height: 12),
                                _buildWinnersSection(manualWinners, theme),
                              ],

                              const SizedBox(height: 32),
                              _sectionHeader(theme, "About", Colors.blue),
                              const SizedBox(height: 12),
                              Text(description,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                                      height: 1.7,
                                      fontSize: 15)),
                              const SizedBox(height: 32),
                              _sectionHeader(theme, "Organizer", Colors.indigo),
                              const SizedBox(height: 12),
                              
                              // 🔹 Display Club Logo here
                              _buildClubInfoRow(clubId, clubName, theme),
                              const SizedBox(height: 8),
                              _infoCardDecorated(theme, null, Icons.person_rounded, "Coordinator", coordinatorName, Colors.indigo),
                              
                              if (requiresVolunteers) ...[
                                const SizedBox(height: 32),
                                _sectionHeader(theme, "Volunteering Opportunities", Colors.green),
                                const SizedBox(height: 12),
                                _volunteerSectionVibrant(theme, volunteerCount, volunteerRole),
                              ],
                              
                              const SizedBox(height: 32),
                              _buildParticipantsRow(event.id, theme, context),

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
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          logo = data != null && data.containsKey('profilePic') ? data['profilePic'] : null;
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.5,
        )
      ),
    );
  }

  Widget _metricsGridDecorated(ThemeData theme, String date, String time, String venue, String mode, bool isUnlimited, int remainingSeats, int totalSeats, String? deadlineDate, String? deadlineTime) {
    bool hasDeadline = deadlineDate != null && deadlineDate.isNotEmpty;
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
        const SizedBox(height: 12),
        Row(
          children: [
            _metricItemVibrant(theme, Icons.chair_alt_rounded, "SEATS AVAILABLE", isUnlimited ? "Unlimited" : "$remainingSeats / $totalSeats", Colors.purple.shade400),
            const SizedBox(width: 12),
            if (hasDeadline)
              _metricItemVibrant(theme, Icons.timer_off_rounded, "DEADLINE", "$deadlineDate ${deadlineTime ?? ''}".trim(), Colors.teal)
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _metricItemVibrant(ThemeData theme, IconData icon, String label, String value, Color color) {
    final isDark = theme.brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.08), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCardDecorated(ThemeData theme, String? imageUrl, IconData fallbackIcon, String label, String value, Color color) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.06), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.2), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? (imageUrl.startsWith('data:image')
                      ? Image.memory(base64Decode(imageUrl.split(',').last), fit: BoxFit.cover)
                      : Image.network(_convertGoogleDriveLink(imageUrl), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(fallbackIcon, size: 24, color: color)))
                  : Icon(fallbackIcon, size: 24, color: color),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.2)),
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
    return GlassCard(
      borderRadius: 24,
      blur: 15,
      color: Colors.green.withOpacity(0.1),
      border: Border.all(color: Colors.green.withOpacity(0.2), width: 1.5),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.volunteer_activism_rounded, size: 22, color: Colors.green),
                ),
                const SizedBox(width: 14),
                Text("$count Open Positions",
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 17)),
              ],
            ),
            if (role.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.1)),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    color: (theme.brightness == Brightness.dark ? theme.focusColor : Colors.black).withOpacity(0.8),
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w600
                  )
                ),
              ),
            ]
          ],
        ),
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
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (theme.brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: (theme.brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.primaryColor.withOpacity(0.2), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(color: theme.primaryColor, fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
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

        bool isRegistrationClosed = false;
        final deadlineDateStr = data['registrationDeadlineDate'];
        final deadlineTimeStr = data['registrationDeadlineTime'];
        if (deadlineDateStr != null && deadlineDateStr.isNotEmpty && deadlineTimeStr != null && deadlineTimeStr.isNotEmpty) {
          try {
            final deadline = DateTime.parse('$deadlineDateStr $deadlineTimeStr:00');
            if (DateTime.now().isAfter(deadline)) {
              isRegistrationClosed = true;
            }
          } catch (e) {
            debugPrint("Error parsing deadline: $e");
          }
        }

        final int filledSeats = data['filledSeats'] is int ? data['filledSeats'] : int.tryParse(data['filledSeats']?.toString() ?? '') ?? 0;
        final dynamic tsData = data['totalSeats'] ?? data['capacity'] ?? data['maxSeats'];
        final String totalSeatsStr = tsData?.toString() ?? '';
        final int totalSeats = int.tryParse(totalSeatsStr) ?? 0;
        final bool isUnlimited = totalSeatsStr.isEmpty || totalSeatsStr.toLowerCase() == 'unlimited' || totalSeats <= 0;
        final bool isEventFull = !isUnlimited && filledSeats >= totalSeats;

        final bool isDisabled = isRegistered || isRegistrationClosed || isEventFull;


        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: GlassCard(
            borderRadius: 32,
            blur: 20,
            color: theme.colorScheme.surface.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: isDisabled ? [] : [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 70),
                          backgroundColor: isDisabled ? Colors.grey.withOpacity(0.2) : theme.primaryColor,
                          foregroundColor: isDisabled ? Colors.grey : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          elevation: 0,
                        ),
                        onPressed: isDisabled ? null : () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => EventRegistrationScreen(event: eventDoc)));
                        },
                        child: Text(
                          isRegistered
                            ? "ALREADY REGISTERED"
                            : (isEventFull ? "EVENT FULL" : (isRegistrationClosed ? "REGISTRATION CLOSED" : (isTeamEvent ? "REGISTER YOUR TEAM" : "CLAIM MY SPOT"))),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticipantsRow(String eventId, ThemeData theme, BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, "Registered Students", Colors.orange),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('registrations')
              .where('eventId', isEqualTo: eventId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()));
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return Text("No registrations yet. Be the first one!",
                  style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), fontSize: 13, fontStyle: FontStyle.italic));
            }

            return SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final regData = docs[index].data() as Map<String, dynamic>;
                  final String userId = regData['userId'] ?? '';
                  final String name = regData['studentName'] ?? 'Student';

                  return Padding(
                    padding: const EdgeInsets.only(right: 20.0),
                    child: Column(
                      children: [
                        _participantAvatar(userId, theme),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 60,
                          child: Text(
                            name.split(' ')[0],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _participantAvatar(String userId, ThemeData theme) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('student').doc(userId).get(),
      builder: (context, snapshot) {
        String profilePic = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          profilePic = data?['profilePic'] ?? '';
        }

        return Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.primaryColor.withOpacity(0.2), width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: ClipOval(
            child: profilePic.isNotEmpty
                ? (profilePic.startsWith('data:image')
                    ? Image.memory(base64Decode(profilePic.split(',').last), fit: BoxFit.cover)
                    : Image.network(profilePic, fit: BoxFit.cover))
                : Container(
                    color: theme.primaryColor.withOpacity(0.1),
                    child: Icon(Icons.person_rounded, color: theme.primaryColor, size: 28),
                  ),
          ),
        );
      },
    );
  }

  void _showStudentProfilePopup(BuildContext context, String userId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('student').doc(userId).get(),
          builder: (context, snapshot) {
            String name = "Loading...";
            String photo = "";
            String college = "N/A";
            String year = "N/A";
            String department = "N/A";
            String semester = "N/A";
            String ktuId = "N/A";
            bool isReady = false;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              name = data['name'] ?? 'Unknown Student';
              photo = data['profilePic'] ?? '';
              college = data['college'] ?? 'N/A';
              year = data['year']?.toString() ?? 'N/A';
              department = data['department'] ?? 'N/A';
              semester = data['semester']?.toString() ?? 'N/A';
              ktuId = data['ktuId'] ?? 'N/A';
              isReady = true;
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryColor = Theme.of(context).primaryColor;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Background
                      Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor.withOpacity(0.8),
                                  primaryColor.withOpacity(0.4),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 60,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: primaryColor.withOpacity(0.2),
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: photo.isNotEmpty
                                          ? (photo.startsWith('data:image')
                                              ? Image.memory(base64Decode(photo.split(',').last), fit: BoxFit.cover)
                                              : Image.network(photo, fit: BoxFit.cover))
                                          : Container(
                                              color: primaryColor.withOpacity(0.1),
                                              child: Icon(Icons.person_rounded, color: primaryColor, size: 60),
                                            ),
                                    ),
                                  ),
                                  if (!isReady)
                                    const SizedBox(
                                      width: 120,
                                      height: 120,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 65),
                      
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                        child: Column(
                          children: [
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildBadge(department, Colors.blue),
                                const SizedBox(width: 8),
                                _buildBadge("Year $year", Colors.orange),
                              ],
                            ),
                            const SizedBox(height: 28),
                            
                            _buildInfoRow(Icons.school_rounded, "College", college, isDark),
                            const SizedBox(height: 16),
                            _buildInfoRow(Icons.history_rounded, "Semester", "Semester $semester", isDark),
                            
                            const SizedBox(height: 36),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  "CLOSE",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: anim1.drive(CurveTween(curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlight 
            ? (isDark ? Colors.blueAccent.withOpacity(0.1) : Colors.blue.withOpacity(0.05))
            : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlight 
              ? (isDark ? Colors.blueAccent.withOpacity(0.2) : Colors.blue.withOpacity(0.1))
              : (isDark ? Colors.white10 : Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHighlight ? Colors.blue.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: isHighlight ? Colors.blue : Colors.grey[400]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    color: isHighlight ? Colors.blue.withOpacity(0.7) : Colors.grey,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? (isHighlight ? Colors.blueAccent : Colors.white) : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
