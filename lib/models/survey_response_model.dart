import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single respondent's answers during a field survey.
/// One SurveyResponseModel = one person/household interviewed.
/// Multiple can exist per survey per volunteer.
class SurveyResponseModel {
  final String? id;
  final String surveyId;
  final String volunteerId;
  final String taskId;

  // Respondent demographics (optional — for privacy can be left anonymous)
  final String respondentName;
  final int respondentAge;
  final String respondentGender; // 'Male' | 'Female' | 'Other' | 'Prefer not to say'
  final String respondentAddress;

  // All custom field answers: { 'question label': answer }
  final Map<String, dynamic> answers;

  final DateTime timestamp;

  SurveyResponseModel({
    this.id,
    required this.surveyId,
    required this.volunteerId,
    required this.taskId,
    this.respondentName = 'Anonymous',
    this.respondentAge = 0,
    this.respondentGender = 'Prefer not to say',
    this.respondentAddress = '',
    required this.answers,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'survey_id': surveyId,
      'volunteer_id': volunteerId,
      'task_id': taskId,
      'respondent_name': respondentName,
      'respondent_age': respondentAge,
      'respondent_gender': respondentGender,
      'respondent_address': respondentAddress,
      'answers': answers,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory SurveyResponseModel.fromMap(Map<String, dynamic> map, String docId) {
    final ts = map['timestamp'];
    return SurveyResponseModel(
      id: docId,
      surveyId: map['survey_id'] ?? '',
      volunteerId: map['volunteer_id'] ?? '',
      taskId: map['task_id'] ?? '',
      respondentName: map['respondent_name'] ?? 'Anonymous',
      respondentAge: (map['respondent_age'] as num?)?.toInt() ?? 0,
      respondentGender: map['respondent_gender'] ?? 'Prefer not to say',
      respondentAddress: map['respondent_address'] ?? '',
      answers: Map<String, dynamic>.from(map['answers'] ?? {}),
      timestamp: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}
