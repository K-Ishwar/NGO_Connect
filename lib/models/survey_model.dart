import 'package:cloud_firestore/cloud_firestore.dart';

class SurveyModel {
  final String? id;
  final String ngoId;
  final String area;
  final String problemType;
  final int peopleCount;
  final String urgency;
  final String description;
  final DateTime date;

  SurveyModel({
    this.id,
    required this.ngoId,
    required this.area,
    required this.problemType,
    required this.peopleCount,
    required this.urgency,
    required this.description,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'ngo_id': ngoId,
      'area': area,
      'problem_type': problemType,
      'people_count': peopleCount,
      'urgency': urgency,
      'description': description,
      'date': Timestamp.fromDate(date),
    };
  }

  factory SurveyModel.fromMap(Map<String, dynamic> map, String documentId) {
    return SurveyModel(
      id: documentId,
      ngoId: map['ngo_id'] ?? '',
      area: map['area'] ?? '',
      problemType: map['problem_type'] ?? '',
      peopleCount: map['people_count']?.toInt() ?? 0,
      urgency: map['urgency'] ?? '',
      description: map['description'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
    );
  }
}
