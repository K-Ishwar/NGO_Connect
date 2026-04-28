import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/feedback_model.dart';
import 'task_service.dart';

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TaskService _taskService = TaskService();

  Future<bool> submitFeedbackAndCompleteTask(FeedbackModel feedback) async {
    try {
      // Create feedback record
      await _firestore.collection('feedback').add(feedback.toMap());

      // Skip task completion for NGO manual backfill uploads
      if (feedback.taskId == 'manual_upload') return true;

      // Update the underlying task status to 'completed'
      final taskSuccess = await _taskService.completeTask(feedback.taskId);
      return taskSuccess;
    } catch (e) {
      print('Error submitting feedback: $e');
      return false;
    }
  }
}
