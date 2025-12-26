import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CollegeListView extends StatelessWidget {
  const CollegeListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Faculty Status")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('faculty').where('role', isEqualTo: 'Main Faculty').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snap.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snap.data!.docs[index];
              bool isActive = doc.data().toString().contains('isActive') ? doc['isActive'] : true;
              return ListTile(
                title: Text(doc['college'] ?? 'N/A'),
                subtitle: Text(doc['name'] ?? 'N/A'),
                trailing: Switch(value: isActive, onChanged: (v) => FirebaseFirestore.instance.collection('faculty').doc(doc.id).update({'isActive': v})),
              );
            },
          );
        },
      ),
    );
  }
}