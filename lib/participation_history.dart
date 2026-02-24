import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

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
        // Querying registrations where userId matches the current student
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
            itemBuilder: (context, index) {
              final reg = registrations[index];
              // show registration time if available
              final timestamp = reg['registeredAt'] as Timestamp?;
              String timeText = '';
              if (timestamp != null) {
                timeText = DateFormat('yyyy-MM-dd hh:mm a').format(timestamp.toDate());
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: ListTile(
                  leading: Icon(Icons.event_available, color: Theme.of(context).primaryColor),
                  title: Text(reg['eventTitle'] ?? 'Event Name'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Status: Confirmed"),
                      if (timeText.isNotEmpty) Text("Registered: $timeText", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  trailing: const Icon(Icons.info_outline),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: (100 * index).ms).slideX();
            },
          );
        },
      ),
    );
  }
}
