import 'package:flutter/foundation.dart';
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
    } catch (e) { debugPrint('Error accepting task: $e');
      return false;
    }
  }

  Future<bool> completeTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'status': 'completed',
      });
      return true;
    } catch (e) { debugPrint('Error completing task: $e');
      return false;
    }
  }

  // Auto Assignment logic
  Future<String> autoAssign(SurveyModel survey) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'volunteer')
          .get();
      final volunteers = snapshot.docs;

      if (volunteers.isEmpty) return 'No volunteers registered yet.';

      for (var vol in volunteers) {
        final data = vol.data();

        // 1. Location match (fuzzy)
        final volLocation = (data['location'] ?? '').toString().toLowerCase();
        final surveyAreaLower = survey.area.toLowerCase();
        bool locationMatches = volLocation.isNotEmpty &&
            (volLocation.contains(surveyAreaLower) || surveyAreaLower.contains(volLocation));

        // 2. Skills match — handle both List<String> and String storage
        final rawSkills = data['skills'];
        String skillsStr = '';
        if (rawSkills is List) {
          skillsStr = rawSkills.join(' ').toLowerCase();
        } else if (rawSkills is String) {
          skillsStr = rawSkills.toLowerCase();
        }
        bool skillsMatch = skillsStr.isNotEmpty &&
            (skillsStr.contains(survey.problemType.toLowerCase()) ||
             survey.problemType.toLowerCase().contains(skillsStr));

        // 3. Availability
        final availability = (data['availability'] ?? 'Part-time').toString();
        bool available = availability == 'Full-time' || availability == 'Part-time';

        // Loosen: match if location OR skills match (not strict AND)
        if ((locationMatches || skillsMatch) && available) {
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

      // Last resort: assign the first available volunteer regardless of match
      for (var vol in volunteers) {
        final data = vol.data();
        final existingTask = await _firestore
            .collection('tasks')
            .where('survey_id', isEqualTo: survey.id)
            .where('volunteer_id', isEqualTo: vol.id)
            .get();
        if (existingTask.docs.isEmpty) {
          await acceptTask(surveyId: survey.id!, volunteerId: vol.id, assignedBy: 'auto');
          return 'Assigned to ${data['name']} (nearest available).';
        }
      }

      return 'All volunteers are already assigned to this survey.';
    } catch (e) {
      return 'Error in auto-assignment: $e';
    }
  }
}
