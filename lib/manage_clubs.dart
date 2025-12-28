import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageClubsScreen extends StatelessWidget {
  final bool isGuest;
  const ManageClubsScreen({super.key, required this.isGuest});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isGuest ? "Available Clubs" : "Manage Clubs"),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snap.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snap.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>?;

              // Safe check for clubName
              String clubTitle = (data != null && data.containsKey('clubName'))
                  ? data['clubName'] : 'Unnamed Club';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.stars, color: Colors.amber),
                  title: Text(clubTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  // Removed college subtitle display
                  trailing: isGuest ? null : IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(context, doc.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: isGuest ? null : FloatingActionButton(
        backgroundColor: const Color(0xFF1A237E),
        onPressed: () => _addClubDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Club?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
              onPressed: () {
                FirebaseFirestore.instance.collection('clubs').doc(docId).delete();
                Navigator.pop(ctx);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  void _addClubDialog(BuildContext context) {
    final clubController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create New Club"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: clubController,
              decoration: const InputDecoration(
                  labelText: "Club Name",
                  hintText: "e.g. Coding Club"
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white
              ),
              onPressed: () {
                // Now only checks if Club Name is not empty
                if (clubController.text.trim().isNotEmpty) {
                  FirebaseFirestore.instance.collection('clubs').add({
                    'clubName': clubController.text.trim(),
                    'facultyEmail': "", // Still initialized for dashboard compatibility
                    'coordinatorName': null,
                    'coordinatorEmail': null,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(ctx);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please enter a club name"))
                  );
                }
              },
              child: const Text("Add")
          )
        ],
      ),
    );
  }
}