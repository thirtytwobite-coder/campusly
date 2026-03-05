import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'event_registration_screen.dart';

class EventDetailsScreen extends StatelessWidget {
  final DocumentSnapshot event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Program Details"), elevation: 0),
      body: StreamBuilder<DocumentSnapshot>(
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
          final String clubId = data['clubId'] ?? '';
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
                      Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A))),
                      const SizedBox(height: 8),
                      Text(description, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 32),
                      _buildInfoRow(Icons.calendar_today_outlined, "Date: $date"),
                      const SizedBox(height: 16),
                      _buildInfoRow(Icons.access_time, "Time: $time"),
                      const SizedBox(height: 16),
                      _buildInfoRow(eventMode == 'Online' ? Icons.videocam_outlined : Icons.location_on_outlined, "Mode: $eventMode"),
                      const SizedBox(height: 16),
                      _buildInfoRow(Icons.place_outlined, venue),
                      const SizedBox(height: 16),
                      _buildInfoRow(Icons.person_outline, "Coordinator: $coordinatorName"),
                      
                      if (isTeamEvent) ...[
                        const SizedBox(height: 32),
                        const Divider(),
                        const SizedBox(height: 16),
                        _buildTeamSection(context, user?.uid, event.id),
                      ],

                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomSheet: _buildBottomAction(context, event),
    );
  }

  Widget _buildTeamSection(BuildContext context, String? userId, String eventId) {
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
        final List<dynamic> members = regData['teamMembers'] ?? [];
        final String? teamId = regData['teamId'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.groups_rounded, color: Colors.indigo),
                SizedBox(width: 10),
                Text("Your Team", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ],
            ),
            const SizedBox(height: 12),
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

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.withOpacity(0.1),
                          child: Text(name[0], style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(isLeader ? "Team Leader" : "Member"),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'confirmed' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: status == 'confirmed' ? Colors.green : Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              )
            else
              const Text("Loading team details..."),
          ],
        );
      },
    );
  }

  Widget _buildHeaderImage(String? url) {
    return Container(
      height: 240,
      width: double.infinity,
      color: Colors.grey[100],
      child: url != null && url.isNotEmpty
          ? Image.network(url, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 80, color: Colors.grey))
          : const Icon(Icons.image_outlined, size: 80, color: Colors.grey),
    );
  }

  Widget _buildInfoRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 15),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 15, color: Color(0xFF616161)))),
      ],
    );
  }

  Widget _buildBottomAction(BuildContext context, DocumentSnapshot eventDoc) {
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
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 55),
              backgroundColor: isRegistered ? Colors.grey : const Color(0xFF673AB7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: isRegistered ? null : () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => EventRegistrationScreen(event: eventDoc)));
            },
            child: Text(
              isRegistered ? "Already Registered" : (isTeamEvent ? "Register Team" : "Register Now"),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}
