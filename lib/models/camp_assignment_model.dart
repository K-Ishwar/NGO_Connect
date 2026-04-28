import 'package:cloud_firestore/cloud_firestore.dart';

class CampAssignmentModel {
  final String? id;
  final String campId;
  final String volunteerId;
  final String role;       // 'Doctor' | 'Coordinator' | 'Logistics' | 'General'
  final String status;     // 'assigned' | 'confirmed' | 'completed'
  final int matchScore;    // 0-100

  CampAssignmentModel({
    this.id,
    required this.campId,
    required this.volunteerId,
    required this.role,
    this.status = 'assigned',
    this.matchScore = 0,
  });

  Map<String, dynamic> toMap() => {
    'camp_id': campId,
    'volunteer_id': volunteerId,
    'role': role,
    'status': status,
    'match_score': matchScore,
    'assigned_at': Timestamp.now(),
  };

  factory CampAssignmentModel.fromMap(Map<String, dynamic> map, String docId) =>
      CampAssignmentModel(
        id: docId,
        campId: map['camp_id'] ?? '',
        volunteerId: map['volunteer_id'] ?? '',
        role: map['role'] ?? 'General',
        status: map['status'] ?? 'assigned',
        matchScore: (map['match_score'] as num?)?.toInt() ?? 0,
      );
}
