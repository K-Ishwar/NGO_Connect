import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class FeedbackHistoryScreen extends StatelessWidget {
  const FeedbackHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color baseColor = const Color(0xFFF2F2F2);
    final ngoId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        title: const Text('Feedback History'),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.deepPurpleAccent),
      ),
      body: ngoId == null
          ? const Center(child: Text('Not logged in.'))
          : _buildBody(context, baseColor, ngoId),
    );
  }

  Widget _buildBody(BuildContext context, Color baseColor, String ngoId) {
    // First get all surveys for THIS ngo
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('surveys')
          .where('ngo_id', isEqualTo: ngoId)
          .snapshots(),
      builder: (context, surveySnap) {
        if (!surveySnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final surveyIds = surveySnap.data!.docs.map((d) => d.id).toList();

        if (surveyIds.isEmpty) {
          return const Center(
            child: Text('No surveys found. Create surveys to see feedback.'),
          );
        }

        // Build map of surveyId → survey name for display
        final surveyNames = {
          for (var d in surveySnap.data!.docs)
            d.id: '${(d.data() as Map)['problem_type'] ?? ''} in ${(d.data() as Map)['area'] ?? ''}'
        };

        // Fetch feedback only for this NGO's surveys
        // Firestore 'whereIn' supports up to 30 items
        final chunk = surveyIds.take(30).toList();
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('feedback')
              .where('survey_id', whereIn: chunk)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text('No feedback submitted yet for your surveys.'),
              );
            }

            // Sort client-side by date descending (avoids composite index requirement)
            final feedbackDocs = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final aDate = (a.data() as Map)['date'];
                final bDate = (b.data() as Map)['date'];
                if (aDate is Timestamp && bDate is Timestamp) {
                  return bDate.compareTo(aDate);
                }
                return 0;
              });

            // Summary stats
            int totalHelped = 0;
            for (final doc in feedbackDocs) {
              final data = doc.data() as Map<String, dynamic>;
              totalHelped += (data['people_helped'] as int? ?? 0);
            }

            return Column(
              children: [
                // Summary banner
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statPill('Total Reports', feedbackDocs.length.toString()),
                      _statPill('People Helped', totalHelped.toString()),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: feedbackDocs.length,
                    itemBuilder: (context, index) {
                      final data = feedbackDocs[index].data() as Map<String, dynamic>;
                      final peopleHelped = data['people_helped'] ?? 0;
                      final remainingNeed = data['remaining_need'] ?? 'None';
                      final comments = data['comments'] ?? '';
                      final surveyId = data['survey_id'] ?? '';
                      final dateObj = data['date'];
                      final customAnswers = data['custom_answers'] as Map? ?? {};

                      String dateString = '';
                      if (dateObj is Timestamp) {
                        dateString = DateFormat.yMMMd().add_jm().format(dateObj.toDate());
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: ClayContainer(
                          color: baseColor,
                          borderRadius: 15,
                          depth: 20,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        surveyNames[surveyId] ?? 'Survey',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF8A2387),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      dateString,
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _chip(Icons.people, '${peopleHelped} helped', Colors.green),
                                    const SizedBox(width: 8),
                                    if (remainingNeed.isNotEmpty && remainingNeed != 'None')
                                      _chip(Icons.warning_amber, 'Gap: $remainingNeed', Colors.orange),
                                  ],
                                ),
                                if (comments.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    comments,
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (customAnswers.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  const Divider(height: 1),
                                  const SizedBox(height: 6),
                                  ...customAnswers.entries.take(2).map((e) => Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Text(
                                          '• ${e.key}: ${e.value}',
                                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _statPill(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
