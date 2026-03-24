import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'vibrant_background.dart';

class ListApprovalScreen extends StatelessWidget {
  final String clubId;
  final String clubName;

  const ListApprovalScreen({super.key, required this.clubId, required this.clubName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'PENDING LISTS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: (isDark ? Colors.black : Colors.white).withOpacity(isDark ? 0.4 : 0.6),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const VibrantBackground(),
          StreamBuilder<QuerySnapshot>(
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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.checklist_rtl_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No lists for approval.',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final events = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 120, 24, 100),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final eventDoc = events[index];
                  final eventData = eventDoc.data() as Map<String, dynamic>;
                  final eventId = eventDoc.id;
                  final eventName = eventData['title'] ?? 'Untitled Event';
                  final date = eventData['date'] ?? 'N/A';

                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                eventName.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -0.5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Date: $date',
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ListApprovalDetailScreen(
                                  eventId: eventId,
                                  eventName: eventName,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('VIEW LISTS', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class ListApprovalDetailScreen extends StatelessWidget {
  final String eventId;
  final String eventName;

  const ListApprovalDetailScreen({super.key, required this.eventId, required this.eventName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          eventName.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: (isDark ? Colors.black : Colors.white).withOpacity(isDark ? 0.4 : 0.6),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const VibrantBackground(),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('events').doc(eventId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text('Event not found.'));
              }

              final eventData = snapshot.data!.data() as Map<String, dynamic>;
              final participants = eventData['participantList'] as List? ?? [];
              final winners = eventData['winnerList'] as List? ?? [];
              final isApproved = eventData['listsApproved'] ?? false;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildListSection(context, 'PARTICIPANTS', participants, isDark),
                          const SizedBox(height: 24),
                          _buildListSection(context, 'WINNERS', winners, isDark),
                          const SizedBox(height: 40),
                          if (!isApproved)
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: () => _approveLists(context),
                                icon: const Icon(Icons.check_circle_outline_rounded),
                                label: const Text('APPROVE BOTH LISTS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 8,
                                  shadowColor: Colors.green.withOpacity(0.4),
                                ),
                              ),
                            ).animate().scale(delay: 400.ms),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(BuildContext context, String title, List items, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${items.length} ITEMS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (items.isEmpty)
            const Text('No items in this list.', style: TextStyle(color: Colors.white38, fontSize: 13))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(color: isDark ? Colors.white10 : Colors.black12, height: 24),
              itemBuilder: (context, index) {
                final item = items[index];
                return Text(
                  item.toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _approveLists(BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('events').doc(eventId).update({
        'listsApproved': true,
        'listsSubmitted': false, // Once approved, it's no longer in the pending submission queue
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lists approved successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}