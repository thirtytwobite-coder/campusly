import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'event_registration_screen.dart';
import 'vibrant_background.dart';

class EventDetailsScreen extends StatelessWidget {
  final DocumentSnapshot event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Program Details", style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
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
              final String coordinatorName = data['coordinatorName'] ?? 'TBD';
              final String? imageUrl = data['posterLink'] ?? data['imageUrl'];
              final String eventMode = data['eventMode'] ?? 'TBD';
              final bool isTeamEvent = (data['isTeamEvent'] ?? false) == true;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderImage(imageUrl),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  description,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn().slideY(begin: 0.1),
                          
                          const SizedBox(height: 24),
                          
                          _buildDetailsGrid(theme, date, time, eventMode, venue, coordinatorName),
                          
                          if (isTeamEvent) ...[
                            const SizedBox(height: 32),
                            _buildTeamSection(context, user?.uid, event.id, theme),
                          ],

                          const SizedBox(height: 140),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      bottomSheet: _buildBottomAction(context, event, theme),
    );
  }

  Widget _buildDetailsGrid(ThemeData theme, String date, String time, String mode, String venue, String coordinator) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        _buildDetailItem(theme, Icons.calendar_today_rounded, "Date", date),
        _buildDetailItem(theme, Icons.access_time_rounded, "Time", time),
        _buildDetailItem(theme, mode == 'Online' ? Icons.videocam_rounded : Icons.location_on_rounded, "Mode", mode),
        _buildDetailItem(theme, Icons.place_rounded, "Venue", venue),
        _buildDetailItem(theme, Icons.person_rounded, "Coordinator", coordinator),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildDetailItem(ThemeData theme, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSection(BuildContext context, String? userId, String eventId, ThemeData theme) {
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

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.groups_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text("Your Team", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              if (teamId != null)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('registrations')
                      .where('teamId', isEqualTo: teamId)
                      .snapshots(),
                  builder: (context, teamSnap) {
                    if (!teamSnap.hasData) return const CircularProgressIndicator();
                    
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: teamSnap.data!.docs.length,
                      itemBuilder: (context, index) {
                        final memberDoc = teamSnap.data!.docs[index].data() as Map<String, dynamic>;
                        final String name = memberDoc['studentName'] ?? 'Unknown';
                        final String status = memberDoc['status'] ?? 'confirmed';
                        final bool isLeader = memberDoc['isTeamLeader'] ?? false;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                                child: Text(name[0], style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(isLeader ? "Team Leader" : "Member", style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5))),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(status),
                            ],
                          ),
                        );
                      },
                    );
                  },
                )
              else
                const Center(child: Text("Loading team details...")),
            ],
          ),
        ).animate().fadeIn().slideX();
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    final bool confirmed = status.toLowerCase() == 'confirmed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: confirmed ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: confirmed ? Colors.green : Colors.orange,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHeaderImage(String? url) {
    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: url != null && url.isNotEmpty
            ? Image.network(url, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 80, color: Colors.grey))
            : const Icon(Icons.image_outlined, size: 80, color: Colors.grey),
      ),
    ).animate().fadeIn().scale(begin: const Offset(1.1, 1.1));
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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                  backgroundColor: isRegistered ? Colors.grey.shade300 : theme.colorScheme.primary,
                  foregroundColor: isRegistered ? Colors.grey : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: isRegistered ? 0 : 8,
                  shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                ),
                onPressed: isRegistered ? null : () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => EventRegistrationScreen(event: eventDoc)));
                },
                child: Text(
                  isRegistered ? "Already Registered" : (isTeamEvent ? "Register Your Team" : "Reserve My Spot"),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
