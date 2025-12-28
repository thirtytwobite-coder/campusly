import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_details.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart'; // To navigate back to RoleSelection
import 'participation_history.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  String selectedCategory = "All";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upcoming Events"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: "Participation History",
            icon: const Icon(Icons.history_edu),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const ParticipationHistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (c) => RoleSelectionScreen())
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // CATEGORY FILTER (User Story 2)
          _buildCategoryFilter(),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Sorting by date (User Story 1, Task 3)
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .orderBy('date', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs;

                // Filtering Logic (User Story 2, Task 3)
                if (selectedCategory != "All") {
                  docs = docs.where((d) => d['category'] == selectedCategory).toList();
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var event = docs[index];
                    return _eventCard(event);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    List<String> categories = ["All", "Technical", "Cultural", "Sports"];
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: categories.map((cat) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ChoiceChip(
            label: Text(cat),
            selected: selectedCategory == cat,
            onSelected: (s) => setState(() => selectedCategory = cat),
          ),
        )).toList(),
      ),
    );
  }

  Widget _eventCard(DocumentSnapshot doc) {
    return Card(
      margin: const EdgeInsets.all(10),
      child: ListTile(
        title: Text(doc['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${doc['venue']} • ${doc['category']}"),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => EventDetailsScreen(event: doc))
        ),
      ),
    );
  }
}