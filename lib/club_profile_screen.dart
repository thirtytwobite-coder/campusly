import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'event_details.dart';

class ClubProfileScreen extends StatelessWidget {
  final String clubId;
  final String clubName;

  const ClubProfileScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('clubs').doc(clubId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Club not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final description = data['description'] ?? 'No description provided.';
          final committee = List<Map<String, dynamic>>.from(data['executiveCommittee'] ?? []);
          final gallery = List<String>.from(data['galleryUrls'] ?? []);
          final logo = data['profilePic'] as String?;

          return CustomScrollView(
            slivers: [
              _buildAppBar(context, logo),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("About Us"),
                      const SizedBox(height: 12),
                      Text(description, style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.grey)),
                      
                      if (committee.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        _buildSectionTitle("Executive Committee"),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: committee.length,
                            itemBuilder: (context, index) {
                              final member = committee[index];
                              return _buildCommitteeCard(member);
                            },
                          ),
                        ),
                      ],

                      if (gallery.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        _buildSectionTitle("Gallery"),
                        const SizedBox(height: 16),
                        GridView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.5,
                          ),
                          itemCount: gallery.length,
                          itemBuilder: (context, index) {
                            final imageUrl = gallery[index];
                            if (imageUrl.isEmpty) return const SizedBox.shrink();
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                color: Colors.grey[100],
                                child: imageUrl.startsWith('data:image') ? Image.memory(
                                  base64Decode(imageUrl.split(',').last),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 30),
                                      const SizedBox(height: 4),
                                      Text("No Image", style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                                    ],
                                  ),
                                ) : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 30),
                                      const SizedBox(height: 4),
                                      Text("No Image", style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 30),
                      _buildSectionTitle("Events"),
                      const SizedBox(height: 16),
                      _buildEventsTabs(context),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, String? logo) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(clubName, style: const TextStyle(fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)])),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (logo != null && logo.isNotEmpty && (logo.startsWith('http') || logo.startsWith('data:image')))
              logo.startsWith('data:image') ? Image.memory(
                base64Decode(logo.split(',').last),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultHeaderBackground(),
              ) : Image.network(
                logo,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultHeaderBackground(),
              )
            else
              _buildDefaultHeaderBackground(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultHeaderBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.indigo.shade800, Colors.blue.shade900],
        ),
      ),
      child: Center(
        child: Icon(Icons.stars, size: 80, color: Colors.white.withOpacity(0.2)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
  }

  Widget _buildCommitteeCard(Map<String, dynamic> member) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.indigo.withOpacity(0.1),
            backgroundImage: (member['image'] != null && 
                             member['image'].toString().isNotEmpty && 
                             (member['image'].toString().startsWith('http') || member['image'].toString().startsWith('data:image'))) 
                ? (member['image'].toString().startsWith('data:image')
                    ? MemoryImage(base64Decode(member['image'].toString().split(',').last)) as ImageProvider
                    : NetworkImage(member['image']))
                : null,
            child: (member['image'] == null || 
                    member['image'].toString().isEmpty || 
                    (!member['image'].toString().startsWith('http') && !member['image'].toString().startsWith('data:image'))) 
                ? const Icon(Icons.person, size: 40, color: Colors.indigo) 
                : null,
          ),
          const SizedBox(height: 8),
          Text(member['name'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(member['role'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildEventsTabs(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: "Upcoming"),
              Tab(text: "Conducted"),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: TabBarView(
              children: [
                _buildEventsList(context, ['approved', 'ongoing']),
                _buildEventsList(context, ['completed']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(BuildContext context, List<String> statuses) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('clubId', isEqualTo: clubId)
          .where('status', whereIn: statuses)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No events found"));

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String? poster = data['posterLink'];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (poster != null && poster.isNotEmpty && (poster.startsWith('http') || poster.startsWith('data:image')))
                    ? (poster.startsWith('data:image') ? Image.memory(
                        base64Decode(poster.split(',').last),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.indigo.withOpacity(0.1),
                          child: const Icon(Icons.event, color: Colors.indigo),
                        ),
                      ) : Image.network(
                        poster,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.indigo.withOpacity(0.1),
                          child: const Icon(Icons.event, color: Colors.indigo),
                        ),
                      ))
                    : Container(
                        width: 50,
                        height: 50,
                        color: Colors.indigo.withOpacity(0.1),
                        child: const Icon(Icons.event, color: Colors.indigo),
                      ),
              ),
              title: Text(data['title'] ?? 'Untitled'),
              subtitle: Text(data['date'] ?? 'TBD'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(event: docs[index])));
              },
            );
          },
        );
      },
    );
  }
}
