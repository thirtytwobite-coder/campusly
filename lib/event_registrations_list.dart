import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EventRegistrationsListScreen extends StatelessWidget {
  final String eventId;
  final String eventName;

  const EventRegistrationsListScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(eventName),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
           Container(
             width: double.infinity,
             padding: const EdgeInsets.all(16.0),
             color: Theme.of(context).primaryColor,
             child: const Text(
               "Registered Students", 
               style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
             ),
           ),
           Expanded(
             child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('registrations')
                  .where('eventId', isEqualTo: eventId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                   return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                
                // Sort in memory to avoid Firestore index requirement
                docs.sort((a, b) {
                  final tA = (a.data() as Map<String, dynamic>)['registeredAt'];
                  final tB = (b.data() as Map<String, dynamic>)['registeredAt'];
                  if (tA is Timestamp && tB is Timestamp) {
                    return tB.compareTo(tA);
                  }
                  return 0;
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                         const SizedBox(height: 16),
                         Text("No registrations yet for $eventName", style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                     Padding(
                       padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text(
                             "Total: ${docs.length} Students", 
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                           ),
                         ],
                       ),
                     ),
                     Expanded(
                       child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: docs.length,
                          separatorBuilder: (c, i) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                  child: Text(
                                      (data['studentName']?[0] ?? '?').toUpperCase(),
                                      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)
                                  ),
                                ),
                                title: Text(data['studentName'] ?? 'Unknown Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  "${data['department'] ?? 'N/A'} - S${data['semester'] ?? '?'}",
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    child: Column(
                                      children: [
                                        _buildDetailRow(Icons.badge_outlined, "KTU ID", data['ktuId'] ?? 'N/A'),
                                        const SizedBox(height: 8),
                                        _buildDetailRow(Icons.phone_outlined, "Phone", data['studentPhone'] ?? 'N/A'),
                                        const SizedBox(height: 8),
                                        _buildDetailRow(Icons.email_outlined, "Email", data['studentEmail'] ?? 'N/A'),
                                        const SizedBox(height: 8),
                                        _buildDetailRow(Icons.calendar_today, "Registered At", 
                                          _formatTimestamp(data['registeredAt'])
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ).animate().fadeIn().slideX(delay: (30 * index).ms);
                          },
                       ),
                     ),
                  ],
                );
              },
                     ),
           ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.grey)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      ],
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      return "${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return timestamp.toString();
  }
}
