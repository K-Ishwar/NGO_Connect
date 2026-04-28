import 'package:cloud_firestore/cloud_firestore.dart';

class CampModel {
  final String? id;
  final String ngoId;
  final String sourceSurveyId;
  final String campName;
  final String area;
  final String campType;         // 'Medical Camp' | 'Food Distribution' | etc.
  final String location;         // Specific address/venue
  final DateTime scheduledDate;
  final int volunteersRequired;
  final int targetBeneficiaries;
  final List<String> resourcesNeeded;
  final List<String> skillsNeeded;
  final String status;           // 'planned' | 'active' | 'completed'
  final String aiRecommendation; // Full Gemini output stored for reference
  final DateTime createdAt;

  CampModel({
    this.id,
    required this.ngoId,
    required this.sourceSurveyId,
    required this.campName,
    required this.area,
    required this.campType,
    this.location = '',
    required this.scheduledDate,
    required this.volunteersRequired,
    required this.targetBeneficiaries,
    required this.resourcesNeeded,
    required this.skillsNeeded,
    this.status = 'planned',
    this.aiRecommendation = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'ngo_id': ngoId,
    'source_survey_id': sourceSurveyId,
    'camp_name': campName,
    'area': area,
    'camp_type': campType,
    'location': location,
    'scheduled_date': Timestamp.fromDate(scheduledDate),
    'volunteers_required': volunteersRequired,
    'target_beneficiaries': targetBeneficiaries,
    'resources_needed': resourcesNeeded,
    'skills_needed': skillsNeeded,
    'status': status,
    'ai_recommendation': aiRecommendation,
    'created_at': Timestamp.fromDate(createdAt),
  };

  factory CampModel.fromMap(Map<String, dynamic> map, String docId) {
    final scheduledTs = map['scheduled_date'];
    final createdTs = map['created_at'];
    return CampModel(
      id: docId,
      ngoId: map['ngo_id'] ?? '',
      sourceSurveyId: map['source_survey_id'] ?? '',
      campName: map['camp_name'] ?? '',
      area: map['area'] ?? '',
      campType: map['camp_type'] ?? '',
      location: map['location'] ?? '',
      scheduledDate: scheduledTs is Timestamp ? scheduledTs.toDate() : DateTime.now(),
      volunteersRequired: (map['volunteers_required'] as num?)?.toInt() ?? 1,
      targetBeneficiaries: (map['target_beneficiaries'] as num?)?.toInt() ?? 0,
      resourcesNeeded: List<String>.from(map['resources_needed'] ?? []),
      skillsNeeded: List<String>.from(map['skills_needed'] ?? []),
      status: map['status'] ?? 'planned',
      aiRecommendation: map['ai_recommendation'] ?? '',
      createdAt: createdTs is Timestamp ? createdTs.toDate() : DateTime.now(),
    );
  }
}
