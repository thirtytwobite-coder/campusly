
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParticipationHistoryScreen extends StatelessWidget {
  const ParticipationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Participation"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
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
            );
          }

          final registrations = snapshot.data!.docs;

          return ListView.builder(
            itemCount: registrations.length,
            itemBuilder: (context, index) {
              final reg = registrations[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.event_available, color: Colors.green),
                  title: Text(reg['eventTitle'] ?? 'Event Name'),
                  subtitle: Text("Status: Confirmed"),
                  trailing: const Icon(Icons.info_outline),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
