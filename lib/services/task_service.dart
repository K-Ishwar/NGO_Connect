import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../models/survey_model.dart';
import 'notification_service.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  Future<bool> acceptTask({
    required String surveyId,
    required String volunteerId,
    String assignedBy = 'self',
  }) async {
    try {
      final task = TaskModel(
        surveyId: surveyId,
        volunteerId: volunteerId,
        status: 'assigned',
        assignedBy: assignedBy,
      );
      await _firestore.collection('tasks').add(task.toMap());

      await _notificationService.logNotification(
        title: 'New task assigned!',
        body: 'New task assigned in your area.',
        targetUserId: volunteerId,
      );

      return true;
    } catch (e) {
      print('Error accepting task: $e');
      return false;
    }
  }

  Future<bool> completeTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'status': 'completed',
      });
      return true;
    } catch (e) {
      print('Error completing task: $e');
      return false;
    }
  }

  // Auto Assignment logic
  Future<String> autoAssign(SurveyModel survey) async {
    try {
      // Fetch Volunteers
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'volunteer')
          .get();
      final volunteers = snapshot.docs;

      for (var vol in volunteers) {
        final data = vol.data();

        // 1. Same area — use contains for fuzzy match
        final volLocation = (data['location'] ?? '').toLowerCase();
        final surveyAreaLower = survey.area.toLowerCase();
        bool locationMatches = volLocation.isNotEmpty &&
            (volLocation.contains(surveyAreaLower) || surveyAreaLower.contains(volLocation));

        // 2. Skills match problem type
        String skillsStr = (data['skills'] ?? '').toLowerCase();
        bool skillsMatch = skillsStr.isNotEmpty && (skillsStr.contains(survey.problemType.toLowerCase()) || survey.problemType.toLowerCase().contains(skillsStr));

        // 3. Availability
        String availability = data['availability'] ?? 'Part-time'; // Default
        bool available =
            availability == 'Full-time' || availability == 'Part-time';

        if (locationMatches && skillsMatch && available) {
          // Check if already assigned
          final existingTask = await _firestore
              .collection('tasks')
              .where('survey_id', isEqualTo: survey.id)
              .where('volunteer_id', isEqualTo: vol.id)
              .get();

          if (existingTask.docs.isEmpty) {
            await acceptTask(
              surveyId: survey.id!,
              volunteerId: vol.id,
              assignedBy: 'auto',
            );
            return 'Auto-assigned to ${data['name']}!';
          }
        }
      }
      return 'No matching volunteer found for auto-assignment.';
    } catch (e) {
      print('Error in auto assigning: $e');
      return 'Error in auto-assignment.';
    }
  }
}
