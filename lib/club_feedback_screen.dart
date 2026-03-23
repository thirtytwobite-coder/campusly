import 'dart:ui';
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
        title: Text(
          widget.clubName.toLowerCase().contains("mulearn") ? "µLearn Feedback" : "${widget.clubName} Feedback",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -1),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: theme.brightness == Brightness.dark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.2),
            ),
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
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

    return Column(
      children: [
        _buildSummaryHeader(theme),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _eventsWithFeedback.length,
            itemBuilder: (context, index) {
              final event = _eventsWithFeedback[index];
              return _buildEventFeedbackCard(event, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader(ThemeData theme) {
    if (_eventsWithFeedback.isEmpty) return const SizedBox.shrink();

    double totalWeightedRating = 0;
    int totalReviews = 0;
    for (var event in _eventsWithFeedback) {
      totalWeightedRating += (event['avgRating'] as double) * (event['feedbackCount'] as int);
      totalReviews += (event['feedbackCount'] as int);
    }
    final overallAvg = totalReviews > 0 ? (totalWeightedRating / totalReviews) : 0.0;
    final isDark = theme.brightness == Brightness.dark;
    final isMuLearn = widget.clubName.toLowerCase().contains("mulearn");
    final accentColor = isMuLearn ? const Color(0xFFFFB200) : theme.primaryColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
      child: GlassCard(
        borderRadius: 24,
        blur: 20,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Overall Performance",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white70 : Colors.black54,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.clubName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 50,
                width: 1,
                color: isDark ? Colors.white10 : Colors.black12,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                      const SizedBox(width: 4),
                      Text(
                        overallAvg.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "$totalReviews Reviews",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accentColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  Color _getSentimentColor(double rating) {
    if (rating >= 4.0) return Colors.greenAccent;
    if (rating >= 3.0) return Colors.amberAccent;
    return Colors.redAccent;
  }

  Widget _buildEventFeedbackCard(Map<String, dynamic> event, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final String eventTitle = event['eventTitle'];
    final double avgRating = event['avgRating'];
    final int feedbackCount = event['feedbackCount'];
    final sentimentColor = _getSentimentColor(avgRating);
    final isMuLearn = widget.clubName.toLowerCase().contains("mulearn");
    final accentColor = isMuLearn ? const Color(0xFFFFB200) : theme.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderRadius: 24,
        blur: 15,
        child: InkWell(
          onTap: () => _showFeedbackDetails(event),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 54,
                      width: 54,
                      child: CircularProgressIndicator(
                        value: avgRating / 5,
                        strokeWidth: 5,
                        backgroundColor: sentimentColor.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(sentimentColor.withOpacity(0.8)),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "$feedbackCount Reviews",
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (avgRating >= 4.5)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "Top Rated",
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.greenAccent),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.black12, size: 28),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (40 * index).ms, duration: 400.ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }

  void _showFeedbackDetails(Map<String, dynamic> event) {
    final theme = Theme.of(context);
    final List<Map<String, dynamic>> feedbacks = event['feedbacks'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event['eventTitle'], 
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5)
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${event['feedbackCount']} Student Reviews", 
                            style: TextStyle(color: isDark ? Colors.white38 : Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w600)
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            event['avgRating'].toStringAsFixed(1), 
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Colors.white10),
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
        );
      },
    );
  }

  Widget _buildFeedbackItem(Map<String, dynamic> feedback, ThemeData theme) {
    final int rating = feedback['rating'].toInt();
    final String text = feedback['feedback'];
    final Timestamp? timestamp = feedback['feedbackAt'] as Timestamp?;
    final isDark = theme.brightness == Brightness.dark;
    final sentimentColor = _getSentimentColor(feedback['rating'].toDouble());
    
    String dateStr = 'Unknown date';
    if (timestamp != null) {
      dateStr = DateFormat('MMM d, yyyy').format(timestamp.toDate());
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: sentimentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: sentimentColor.withOpacity(0.2)),
                ),
                alignment: Alignment.center,
                child: Text(
                  (feedback['studentName'][0] as String).toUpperCase(),
                  style: TextStyle(color: sentimentColor, fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feedback['studentName'], 
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isDark ? Colors.white : Colors.black87)
                    ),
                    Text(dateStr, style: TextStyle(color: isDark ? Colors.white38 : Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: List.generate(5, (i) => Icon(
                      Icons.star_rounded, 
                      size: 14, 
                      color: i < rating ? Colors.amber : (isDark ? Colors.white12 : Colors.grey[300])
                    )),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rating == 5 ? "Excellent" : rating >= 4 ? "Great" : rating >= 3 ? "Good" : "Needs Work",
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: sentimentColor.withOpacity(0.8)),
                  ),
                ],
              ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              text,
              style: TextStyle(
                fontSize: 14, 
                color: isDark ? Colors.white70 : Colors.black87, 
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
