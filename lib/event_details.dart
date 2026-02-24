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
    final String visibility = data['visibility'] ?? "public";
    final bool isCollegeOnly = visibility == "college";
    final String collegeName = data['college'] ?? "Unknown College";

    // 3. Smart Prize detection
    final dynamic rawPrize = data['prizeAmount'] ?? data['prizePool'] ?? data['pricePool'] ?? data['prize'];
    final String prizeText = rawPrize?.toString() ?? "";
    final bool hasPrize = prizeText.trim().isNotEmpty;

    // 4. General Details
    final String title = data['title'] ?? data['name'] ?? 'Untitled Event';
    final String description = data['description'] ?? 'No description provided by the coordinator.';
    final String date = data['date'] ?? 'TBD';
    final String venue = data['location'] ?? data['venue'] ?? 'TBD';
    final String time = data['time'] ?? 'TBD';
    final String initialClubName = data['clubName'] ?? 'Club';
    final String clubId = data['clubId'] ?? '';
    final String coordinatorName = data['coordinatorName'] ?? 'TBD';
    final String? imageUrl = data['posterLink'] ?? data['imageUrl'];
    final String eventMode = data['eventMode'] ?? 'TBD';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Program Details"),
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
                  Text(
                    title,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),

                  const SizedBox(height: 32),

                  // --- LOGISTICS INFO ---
                  _buildInfoRow(Icons.calendar_today_outlined, "Date: $date"),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.access_time, "Time: $time"),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    eventMode == 'Online' ? Icons.videocam_outlined : Icons.location_on_outlined,
                    "Mode: $eventMode",
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.place_outlined, venue),
                  const SizedBox(height: 16),
                  
                  // --- CLUB NAME WITH FETCH LOGIC ---
                  if (clubId.isNotEmpty && (initialClubName == 'Club' || initialClubName.isEmpty))
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('clubs').doc(clubId).get(),
                      builder: (context, snapshot) {
                        String nameToShow = initialClubName;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final clubData = snapshot.data!.data() as Map<String, dynamic>;
                          nameToShow = clubData['clubName'] ?? clubData['name'] ?? initialClubName;
                        }
                        return _buildInfoRow(Icons.groups_outlined, "Club: $nameToShow");
                      },
                    )
                  else
                    _buildInfoRow(Icons.groups_outlined, "Club: $initialClubName"),

                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.person_outline, "Coordinator: $coordinatorName"),
                  const SizedBox(height: 16),
                  _buildVisibilityBadge(isCollegeOnly, collegeName),

                  // --- VOLUNTEER INFO ---
                  if ((data['requiresVolunteers'] ?? false) == true) ...[
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.volunteer_activism_outlined, "Volunteers Needed: ${data['volunteerCount'] ?? 'N/A'}"),
                    const SizedBox(height: 8),
                    if ((data['volunteerRole'] ?? '').toString().isNotEmpty) _buildInfoRow(Icons.list_alt_outlined, "Role: ${data['volunteerRole']}")
                  ],

                  // --- PRIZE BANNER ---
                  if (hasPrize) ...[
                    const SizedBox(height: 24),
                    _buildPrizeBanner(prizeText),
                  ],

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
      color: Colors.grey[100],
      child: url != null && url.isNotEmpty
          ? Image.network(url, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 80, color: Colors.grey))
          : const Icon(Icons.image_outlined, size: 80, color: Colors.grey),
    );
  }

  Widget _buildVisibilityBadge(bool isCollegeOnly, String college) {
    return Row(
      children: [
        Icon(
          isCollegeOnly ? Icons.lock_outline : Icons.public,
          size: 20,
          color: Colors.blue,
        ),
        const SizedBox(width: 15),
        Text(
          isCollegeOnly ? "Visibility: College Only" : "Visibility: Public",
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ],
    ).animate().fadeIn();
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
                "₹ $amount",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    ).animate().shimmer(duration: 1200.ms);
  }

  Widget _buildInfoRow(IconData icon, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 15),
        Expanded(
          child: Text(
            value, 
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF616161)),
          ),
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
          backgroundColor: const Color(0xFF673AB7), // Purple color from the screenshot
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
