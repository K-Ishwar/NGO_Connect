import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackModel {
  final String? id;
  final String taskId;
  final String surveyId;
  final String volunteerId;
  final int peopleHelped;
  final String remainingNeed;
  final String comments;
  final DateTime date;
  final Map<String, String> customAnswers;

  FeedbackModel({
    this.id,
    required this.taskId,
    required this.surveyId,
    required this.volunteerId,
    required this.peopleHelped,
    required this.remainingNeed,
    required this.comments,
    required this.date,
    this.customAnswers = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'task_id': taskId,
      'survey_id': surveyId,
      'volunteer_id': volunteerId,
      'people_helped': peopleHelped,
      'remaining_need': remainingNeed,
      'comments': comments,
      'date': Timestamp.fromDate(date),
      'custom_answers': customAnswers,
    };
  }

  factory FeedbackModel.fromMap(Map<String, dynamic> map, String documentId) {
    return FeedbackModel(
      id: documentId,
      taskId: map['task_id'] ?? '',
      surveyId: map['survey_id'] ?? '',
      volunteerId: map['volunteer_id'] ?? '',
      peopleHelped: map['people_helped']?.toInt() ?? 0,
      remainingNeed: map['remaining_need'] ?? '',
      comments: map['comments'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      customAnswers: Map<String, String>.from(map['custom_answers'] ?? {}),
    );
  }
}
