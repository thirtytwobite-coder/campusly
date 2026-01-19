import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'event_registration_screen.dart';

class EventDetailsScreen extends StatelessWidget {
  final DocumentSnapshot event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    // 1. Extracting data from Firestore
    final data = event.data() as Map<String, dynamic>;

    // 2. Handling the "College Only" vs "Public" logic
    final bool isCollegeOnly = data['isCollegeOnly'] ?? false;
    final String collegeName = data['college'] ?? "Unknown College";

    // 3. Smart Prize detection
    final dynamic rawPrize = data['prizePool'] ?? data['pricePool'] ?? data['prize'];
    final String prizeText = rawPrize?.toString() ?? "";
    final bool hasPrize = prizeText.trim().isNotEmpty;

    // 4. General Details
    final String title = data['title'] ?? 'Untitled Event';
    final String description = data['description'] ?? 'No description provided by the coordinator.';
    final String date = data['date'] ?? 'TBD';
    final String venue = data['venue'] ?? 'TBD';
    final String? imageUrl = data['imageUrl'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Event Information"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- EVENT IMAGE ---
            _buildHeaderImage(imageUrl),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- VISIBILITY BADGE (College Only vs Public) ---
                  _buildVisibilityBadge(isCollegeOnly, collegeName),

                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 20),

                  // --- PRIZE BANNER ---
                  if (hasPrize) _buildPrizeBanner(prizeText),

                  const Divider(height: 40),

                  // --- LOGISTICS INFO ---
                  _buildInfoRow(Icons.calendar_today, "DATE & TIME", date),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.location_on_outlined, "VENUE", venue),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.school_outlined, "ORGANIZING COLLEGE", collegeName),

                  const Divider(height: 40),

                  // --- DESCRIPTION ---
                  const Text(
                    "EVENT DESCRIPTION",
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
                  ),

                  const SizedBox(height: 120), // Padding for the bottom button
                ],
              ),
            ),
          ],
        ),
      ),
      // --- REGISTRATION BUTTON ---
      bottomSheet: _buildBottomAction(context),
    );
  }

  Widget _buildHeaderImage(String? url) {
    return Container(
      height: 240,
      width: double.infinity,
      color: Colors.grey[200],
      child: url != null && url.isNotEmpty
          ? Image.network(url, fit: BoxFit.cover)
          : const Icon(Icons.image_outlined, size: 80, color: Colors.grey),
    );
  }

  Widget _buildVisibilityBadge(bool isCollegeOnly, String college) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCollegeOnly ? Colors.indigo.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isCollegeOnly ? Colors.indigo : Colors.green, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCollegeOnly ? Icons.lock_outline : Icons.public,
            size: 16,
            color: isCollegeOnly ? Colors.indigo : Colors.green,
          ),
          const SizedBox(width: 8),
          Text(
            isCollegeOnly ? "COLLEGE ONLY: $college" : "PUBLIC EVENT (OPEN TO ALL)",
            style: TextStyle(
              color: isCollegeOnly ? Colors.indigo[900] : Colors.green[900],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: -0.2);
  }

  Widget _buildPrizeBanner(String amount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: Colors.amber[900], size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("PRIZE POOL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber)),
              Text(
                amount,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    ).animate().shimmer(duration: 1200.ms);
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Colors.blueGrey[600]),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 55),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventRegistrationScreen(event: event),
            ),
          );
        },
        child: const Text("Register Now", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}