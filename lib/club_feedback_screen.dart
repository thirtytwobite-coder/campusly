import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

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
  // Store events and their associated feedback
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
      // 1. Fetch all events associated with this club
      // Removed orderBy('createdAt') to prevent composite index errors, we will sort it locally
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
      
      // Sort events locally by createdAt descending
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

      final List<Map<String, dynamic>> eventsList = [];

      // Process each event fetching its feedback
      for (var eventDoc in docs) {
        final eventData = eventDoc.data();
        final eventId = eventDoc.id;
        final eventTitle = eventData['title'] ?? 'Unknown Event';
        final Timestamp? eventDate = eventData['createdAt'] as Timestamp?;

        // 2. Query registrations for this specific event to get feedback
        final regSnapshot = await FirebaseFirestore.instance
            .collection('registrations')
            .where('eventId', isEqualTo: eventId)
            .get();

        List<Map<String, dynamic>> feedbacksForEvent = [];
        double totalRating = 0;
        int ratingCount = 0;

        for (var doc in regSnapshot.docs) {
          final data = doc.data();
          // Only keep registrations that have feedback text or a rating > 0
          if (data['feedback'] != null || (data['rating'] != null && data['rating'] > 0)) {
            final rating = data['rating'] ?? 0;
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

        // Add event to list only if there's feedback, or add all (we'll filter out empty ones if we want)
        // Let's only include events that have some feedback to show
        if (feedbacksForEvent.isNotEmpty) {
          // Sort feedbacks newest first
          feedbacksForEvent.sort((a, b) {
            final Timestamp? timeA = a['feedbackAt'] as Timestamp?;
            final Timestamp? timeB = b['feedbackAt'] as Timestamp?;
            if (timeA == null && timeB == null) return 0;
            if (timeA == null) return 1;
            if (timeB == null) return -1;
            return timeB.compareTo(timeA);
          });

          eventsList.add({
            'eventId': eventId,
            'eventTitle': eventTitle,
            'eventDate': eventDate,
            'feedbacks': feedbacksForEvent,
            'avgRating': ratingCount > 0 ? (totalRating / ratingCount) : 0.0,
            'feedbackCount': feedbacksForEvent.length,
          });
        }
      }

      if (mounted) {
        setState(() {
          _eventsWithFeedback = eventsList;
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
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(theme),
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
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = '';
                  });
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
            const Text(
              "No Feedback Yet",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
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

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _eventsWithFeedback.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final event = _eventsWithFeedback[index];
        final String eventTitle = event['eventTitle'];
        final List<Map<String, dynamic>> feedbacks = event['feedbacks'];
        final double avgRating = event['avgRating'];
        final int feedbackCount = event['feedbackCount'];

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            title: Text(
              eventTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            subtitle: Row(
              children: [
                if (avgRating > 0) ...[
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    avgRating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(" • "),
                ],
                Text("$feedbackCount reviews"),
              ],
            ),
            childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
            backgroundColor: Colors.grey.withOpacity(0.02),
            children: [
              const Divider(),
              ...feedbacks.map((feedback) {
                return _buildFeedbackItem(feedback, theme);
              }).toList(),
            ],
          ),
        ).animate().fadeIn(delay: (20 * index).ms).slideX(begin: 0.1);
      },
    );
  }

  Widget _buildFeedbackItem(Map<String, dynamic> feedback, ThemeData theme) {
    final int rating = feedback['rating'];
    final String text = feedback['feedback'];
    final Timestamp? timestamp = feedback['feedbackAt'] as Timestamp?;
    
    String dateStr = 'Unknown date';
    if (timestamp != null) {
      dateStr = DateFormat('MMM d, yyyy').format(timestamp.toDate());
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: Text(
                  (feedback['studentName'][0] as String).toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feedback['studentName'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (rating > 0)
                Row(
                  children: [
                    Text(
                      rating.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 16,
                    ),
                  ],
                ),
            ],
          ),
          
          if (text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                '"$text"',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
