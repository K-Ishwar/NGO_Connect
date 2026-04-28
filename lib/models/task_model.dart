class TaskModel {
  final String? id;
  final String surveyId;
  final String volunteerId;
  final String status; // 'assigned' or 'completed'
  final String assignedBy; // 'self', 'manual', or 'auto'

  TaskModel({
    this.id,
    required this.surveyId,
    required this.volunteerId,
    required this.status,
    this.assignedBy = 'self',
  });

  Map<String, dynamic> toMap() {
    return {
      'survey_id': surveyId,
      'volunteer_id': volunteerId,
      'status': status,
      'assigned_by': assignedBy,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TaskModel(
      id: documentId,
      surveyId: map['survey_id'] ?? '',
      volunteerId: map['volunteer_id'] ?? '',
      status: map['status'] ?? 'assigned',
      assignedBy: map['assigned_by'] ?? 'self',
    );
  }
}
