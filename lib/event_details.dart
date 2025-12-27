import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventDetailsScreen extends StatelessWidget {
  final DocumentSnapshot event;
  const EventDetailsScreen({super.key, required this.event});

  Future<void> registerForEvent(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final eventRef = FirebaseFirestore.instance.collection('events').doc(event.id);

    int max = event['maxSeats'];
    int filled = event['filledSeats'];

    if (filled >= max) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event Full!")));
      return;
    }

    // User Story 6: Registration logic
    await FirebaseFirestore.instance.collection('registrations').add({
      'eventId': event.id,
      'userId': user!.uid,
      'eventTitle': event['title'],
      'timestamp': FieldValue.serverTimestamp(),
    });

    // User Story 5: Update seat count
    await eventRef.update({'filledSeats': FieldValue.increment(1)});

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registered Successfully!")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(event['title'])),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Venue: ${event['venue']}", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text("Rules: ${event['description']}"),
            const Spacer(),
            // User Story 5: Display available seats
            Text("Seats left: ${event['maxSeats'] - event['filledSeats']}"),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => registerForEvent(context),
                child: const Text("REGISTER NOW"),
              ),
            )
          ],
        ),
      ),
    );
  }
}