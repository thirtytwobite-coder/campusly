import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'vibrant_background.dart';
import 'event_registrations_list.dart';
import 'notification_sync_service.dart';

class CertificateApprovalScreen extends StatefulWidget {
  final String clubId;
  final String clubName;

  const CertificateApprovalScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<CertificateApprovalScreen> createState() => _CertificateApprovalScreenState();
}

class _CertificateApprovalScreenState extends State<CertificateApprovalScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              "CERTIFICATE REQUESTS",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              widget.clubName.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ),
            ),
          ],
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
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('certificate_approvals')
                    .where('clubId', isEqualTo: widget.clubId)
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: Center(child: Text("Error: ${snapshot.error}")),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.verified_rounded,
                                size: 80,
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                              ),
                            ).animate(onPlay: (c) => c.repeat(reverse: true))
                             .scale(duration: 2.seconds, curve: Curves.easeInOut),
                            const SizedBox(height: 24),
                            Text(
                              "All Verified!",
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "No pending certificate requests.",
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final eventName = data['eventName'] ?? 'Unknown Event';
                          final eventId = data['eventId'];
                          final requestedBy = data['requestedBy'] ?? 'Coordinator';
                          final timestamp = data['timestamp'] as Timestamp?;

                          return _buildVibrantRequestCard(
                            context,
                            index,
                            eventName,
                            eventId,
                            requestedBy,
                            timestamp,
                          );
                        },
                        childCount: docs.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVibrantRequestCard(
    BuildContext context,
    int index,
    String eventName,
    String? eventId,
    String requestedBy,
    Timestamp? timestamp,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GlassCard(
        borderRadius: 32,
        child: InkWell(
          onTap: () => _navigateToDetails(context, eventId, eventName),
          borderRadius: BorderRadius.circular(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eventName.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: -0.5,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFF59E0B).withOpacity(0.15),
                                  const Color(0xFFF59E0B).withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                            ),
                            child: const Text(
                              "PENDING VERIFICATION",
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildModernMetaItem(Icons.person_outline_rounded, "Coordinator", requestedBy),
                        const SizedBox(width: 16),
                        if (timestamp != null)
                          _buildModernMetaItem(
                            Icons.calendar_today_rounded,
                            "Requested On",
                            _formatDate(timestamp.toDate()),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF312E81).withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => _navigateToDetails(context, eventId, eventName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "REVIEW REQUEST",
                              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 13),
                            ),
                            SizedBox(width: 12),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ).animate().scale(delay: 200.ms),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (100 * index).ms).slideY(begin: 0.1);
  }

  Widget _buildModernMetaItem(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: isDark ? Colors.white38 : Colors.black38),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _navigateToDetails(BuildContext context, String? eventId, String eventName) {
    if (eventId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EventRegistrationsListScreen(
            eventId: eventId,
            eventName: eventName,
            isFacultyView: true,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Event details not found"))
      );
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}