import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'vibrant_background.dart';

class ClubFeedbackScreen extends StatefulWidget {
  final String clubId;
  final String clubName;

  const ClubFeedbackScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<ClubFeedbackScreen> createState() => _ClubFeedbackScreenState();
}

class _ClubFeedbackScreenState extends State<ClubFeedbackScreen> {
  List<Map<String, dynamic>> _eventsWithFeedback = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchFeedbacks();
  }

  Future<void> _fetchFeedbacks() async {
    try {
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('clubId', isEqualTo: widget.clubId)
          .get();

      if (eventsSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _eventsWithFeedback = [];
            _isLoading = false;
          });
        }
        return;
      }
      
      final docs = eventsSnapshot.docs.toList();
      docs.sort((a, b) {
        final Map<String, dynamic> dataA = a.data();
        final Map<String, dynamic> dataB = b.data();
        final Timestamp? timeA = dataA['createdAt'] as Timestamp?;
        final Timestamp? timeB = dataB['createdAt'] as Timestamp?;
        
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        return timeB.compareTo(timeA);
      });

      // Fetch all event data in parallel
      final eventsListResults = await Future.wait(docs.map((eventDoc) async {
        final eventData = eventDoc.data();
        final eventId = eventDoc.id;
        final eventTitle = eventData['title'] ?? 'Unknown Event';
        final Timestamp? eventDate = eventData['createdAt'] as Timestamp?;

        // Optimization: query only for registrations that have a rating or feedback
        final regSnapshot = await FirebaseFirestore.instance
            .collection('registrations')
            .where('eventId', isEqualTo: eventId)
            .get();

        List<Map<String, dynamic>> feedbacksForEvent = [];
        double totalRating = 0;
        int ratingCount = 0;

        for (var doc in regSnapshot.docs) {
          final data = doc.data();
          if (data['feedback'] != null || (data['rating'] != null && data['rating'] > 0)) {
            final rating = (data['rating'] ?? 0).toDouble();
            if (rating > 0) {
              totalRating += rating;
              ratingCount++;
            }
            
            feedbacksForEvent.add({
              'id': doc.id,
              'studentName': data['studentName'] ?? 'Anonymous',
              'feedback': data['feedback'] ?? '',
              'rating': rating,
              'feedbackAt': data['feedbackAt'],
            });
          }
        }

        if (feedbacksForEvent.isNotEmpty) {
          feedbacksForEvent.sort((a, b) {
            final Timestamp? timeA = a['feedbackAt'] as Timestamp?;
            final Timestamp? timeB = b['feedbackAt'] as Timestamp?;
            if (timeA == null && timeB == null) return 0;
            if (timeA == null) return 1;
            if (timeB == null) return -1;
            return timeB.compareTo(timeA);
          });

          return {
            'eventId': eventId,
            'eventTitle': eventTitle,
            'eventDate': eventDate,
            'feedbacks': feedbacksForEvent,
            'avgRating': ratingCount > 0 ? (totalRating / ratingCount) : 0.0,
            'feedbackCount': feedbacksForEvent.length,
          };
        }
        return null;
      }));

      final List<Map<String, dynamic>> finalEventsList = eventsListResults.whereType<Map<String, dynamic>>().toList();

      if (mounted) {
        setState(() {
          _eventsWithFeedback = finalEventsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching feedback: $e");
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.clubName} Feedback'),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          const VibrantBackground(),
          _buildBody(theme),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Failed to load feedback',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() { _isLoading = true; _errorMessage = ''; });
                  _fetchFeedbacks();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_eventsWithFeedback.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text("No Feedback Yet", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                "Students haven't submitted any feedback for your club's events recently.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _eventsWithFeedback.length,
      itemBuilder: (context, index) {
        final event = _eventsWithFeedback[index];
        return _buildEventFeedbackCard(event, index);
      },
    );
  }

  Widget _buildEventFeedbackCard(Map<String, dynamic> event, int index) {
    final theme = Theme.of(context);
    final String eventTitle = event['eventTitle'];
    final double avgRating = event['avgRating'];
    final int feedbackCount = event['feedbackCount'];

    return InkWell(
      onTap: () => _showFeedbackDetails(event),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5)),
          ],
          border: Border.all(color: theme.primaryColor.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 60,
                  width: 60,
                  child: CircularProgressIndicator(
                    value: avgRating / 5,
                    strokeWidth: 6,
                    backgroundColor: Colors.amber.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              eventTitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              "$feedbackCount Reviews",
              style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (50 * index).ms).scale(begin: const Offset(0.9, 0.9));
  }

  void _showFeedbackDetails(Map<String, dynamic> event) {
    final theme = Theme.of(context);
    final List<Map<String, dynamic>> feedbacks = event['feedbacks'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event['eventTitle'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text("${event['feedbackCount']} Student Reviews", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(event['avgRating'].toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: feedbacks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  final feedback = feedbacks[index];
                  return _buildFeedbackItem(feedback, theme);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackItem(Map<String, dynamic> feedback, ThemeData theme) {
    final int rating = feedback['rating'].toInt();
    final String text = feedback['feedback'];
    final Timestamp? timestamp = feedback['feedbackAt'] as Timestamp?;
    
    String dateStr = 'Unknown date';
    if (timestamp != null) {
      dateStr = DateFormat('MMM d, yyyy').format(timestamp.toDate());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              child: Text(
                (feedback['studentName'][0] as String).toUpperCase(),
                style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(feedback['studentName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(dateStr, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ],
              ),
            ),
            Row(
              children: List.generate(5, (i) => Icon(
                Icons.star_rounded, 
                size: 16, 
                color: i < rating ? Colors.amber : Colors.grey[200]
              )),
            ),
          ],
        ),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[100]!),
            ),
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
            ),
          ),
        ],
      ],
    );
  }
}
