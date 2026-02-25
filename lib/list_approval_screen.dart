import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ListApprovalScreen extends StatelessWidget {
  final String clubId;
  final String clubName;

  const ListApprovalScreen({super.key, required this.clubId, required this.clubName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Approve Lists for $clubName'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .where('clubId', isEqualTo: clubId)
            .where('listsSubmitted', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No lists submitted for approval.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final eventDoc = snapshot.data!.docs[index];
              final eventData = eventDoc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(eventData['title'] ?? 'Event'),
                  subtitle: const Text('Awaiting Approval'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ListApprovalDetailScreen(eventDoc: eventDoc),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ListApprovalDetailScreen extends StatelessWidget {
  final DocumentSnapshot eventDoc;

  const ListApprovalDetailScreen({super.key, required this.eventDoc});

  @override
  Widget build(BuildContext context) {
    final eventData = eventDoc.data() as Map<String, dynamic>;
    final participants = List<Map<String, dynamic>>.from(eventData['participants'] ?? []);
    final winners = List<Map<String, dynamic>>.from(eventData['winners'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text('Approve: ${eventData['title']}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Winners', style: Theme.of(context).textTheme.headlineSmall),
            if (winners.isEmpty)
              const Text('No winners submitted.')
            else
              ...winners.map((winner) => ListTile(
                    leading: const Icon(Icons.emoji_events, color: Colors.amber),
                    title: Text(winner['name'] ?? ''),
                    subtitle: Text('Rank: ${winner['rank']}'),
                  )),
            const Divider(height: 30),
            Text('Participants', style: Theme.of(context).textTheme.headlineSmall),
            if (participants.isEmpty)
              const Text('No participants submitted.')
            else
              ...participants.map((participant) => ListTile(
                    leading: const Icon(Icons.person, color: Colors.grey),
                    title: Text(participant['name'] ?? ''),
                  )),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveLists(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _rejectLists(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _approveLists(BuildContext context) async {
    await eventDoc.reference.update({
      'listsApproved': true,
      'listsSubmitted': false,
    });
    Navigator.pop(context);
  }

  Future<void> _rejectLists(BuildContext context) async {
    await eventDoc.reference.update({
      'listsApproved': false,
      'listsSubmitted': false,
    });
    Navigator.pop(context);
  }
}
