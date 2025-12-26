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
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snap.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snap.data!.docs[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.stars, color: Colors.amber),
                  title: Text(doc['name'] ?? 'Club Name'),
                  trailing: isGuest ? null : IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => FirebaseFirestore.instance.collection('clubs').doc(doc.id).delete(),
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

  void _addClubDialog(BuildContext context) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Club"),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: "Enter Club Name")),
        actions: [
          ElevatedButton(onPressed: () {
            FirebaseFirestore.instance.collection('clubs').add({'name': c.text.trim()});
            Navigator.pop(ctx);
          }, child: const Text("Add"))
        ],
      ),
    );
  }
}