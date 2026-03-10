import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'event_details.dart';
import 'feedback_screen.dart';

class ParticipationHistoryScreen extends StatelessWidget {
  const ParticipationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Participation"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('registrations')
            .where('userId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("You haven't registered for any events yet."),
            ).animate().fadeIn(duration: 500.ms);
          }

          final registrations = snapshot.data!.docs;

          return ListView.builder(
            itemCount: registrations.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final reg = registrations[index];
              final data = reg.data() as Map<String, dynamic>;
              final timestamp = data['registeredAt'] as Timestamp?;
              String timeText = '';
              if (timestamp != null) {
                timeText = DateFormat('yyyy-MM-dd hh:mm a').format(timestamp.toDate());
              }

              final String? existingFeedback = data['feedback'];
              final int? rating = data['rating'];
              final String eventId = data['eventId'] ?? '';
              final bool isTeamEvent = (data['isTeamEvent'] ?? false) == true;
              final String? teamId = data['teamId'];
              final String regType = (data['registrationType'] ?? 'participant').toString();
              final bool isVolunteer = regType.toLowerCase() == 'volunteer';
              final String? assignedTask = data['assignedTask'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Icon(Icons.event_available, color: Theme.of(context).primaryColor),
                  ),
                  title: Text(data['eventTitle'] ?? 'Event Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(timeText.isNotEmpty ? "Registered: $timeText" : "Confirmed"),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const SizedBox(height: 8),
                          
                          if (isVolunteer) ...[
                            const Row(
                              children: [
                                Icon(Icons.assignment, size: 18, color: Colors.green),
                                SizedBox(width: 8),
                                Text("Volunteer Task", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green.shade100),
                              ),
                              child: Text(
                                assignedTask?.isNotEmpty == true ? assignedTask! : "Waiting for task assignment...",
                                style: TextStyle(
                                  fontStyle: assignedTask?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
                                  color: assignedTask?.isNotEmpty == true ? Colors.black87 : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                          ],

                          if (isTeamEvent && teamId != null) ...[
                            const Row(
                              children: [
                                Icon(Icons.groups_rounded, size: 18, color: Colors.indigo),
                                SizedBox(width: 8),
                                Text("Team Participation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('registrations')
                                  .where('teamId', isEqualTo: teamId)
                                  .snapshots(),
                              builder: (context, teamSnap) {
                                if (!teamSnap.hasData) return const LinearProgressIndicator();
                                final members = teamSnap.data!.docs;
                                return Column(
                                  children: members.map((memberDoc) {
                                    final mData = memberDoc.data() as Map<String, dynamic>;
                                    final String name = mData['studentName'] ?? 'Unknown';
                                    final String status = mData['status'] ?? 'confirmed';
                                    final bool isLeader = mData['isTeamLeader'] ?? false;

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        children: [
                                          Icon(
                                            status == 'confirmed' ? Icons.check_circle : Icons.pending,
                                            size: 16,
                                            color: status == 'confirmed' ? Colors.green : Colors.orange,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
                                          if (isLeader)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(4)),
                                              child: const Text("LEADER", style: TextStyle(fontSize: 9, color: Colors.indigo, fontWeight: FontWeight.bold)),
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                          ],

                          const Row(
                            children: [
                              Icon(Icons.rate_review_outlined, size: 18, color: Colors.blue),
                              SizedBox(width: 8),
                              Text("Your Experience", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (existingFeedback != null && existingFeedback.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (rating != null)
                                    Row(
                                      children: List.generate(5, (i) => Icon(
                                        i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                        color: Colors.amber,
                                        size: 18,
                                      )),
                                    ),
                                  if (rating != null) const SizedBox(height: 8),
                                  Text(
                                    existingFeedback,
                                    style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
                                  ),
                                ],
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FeedbackScreen(
                                        registrationRef: reg.reference,
                                        eventTitle: data['eventTitle'] ?? 'Event',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add_comment_outlined, size: 18),
                                label: const Text("Rate & Review Event"),
                              ),
                            ),
                          
                          const SizedBox(height: 16),
                          
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final eventDoc = await FirebaseFirestore.instance.collection('events').doc(eventId).get();
                                    if (eventDoc.exists && context.mounted) {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(event: eventDoc)));
                                    }
                                  },
                                  icon: const Icon(Icons.info_outline, size: 18),
                                  label: const Text("Event Details"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms, delay: (100 * index).ms).slideX();
            },
          );
        },
      ),
    );
  }
}
