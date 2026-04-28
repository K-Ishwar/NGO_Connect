import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/survey_model.dart';
import 'notification_service.dart';

class SurveyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  Future<bool> addSurvey(SurveyModel survey) async {
    try {
      await _firestore.collection('surveys').add(survey.toMap());

      if (survey.urgency == 'High') {
        // Smart Allocation: Find volunteers who match location or skills
        final volunteersSnapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'Volunteer')
            .get();

        for (var doc in volunteersSnapshot.docs) {
          final data = doc.data();
          final userLocation = (data['location'] ?? '').toString().toLowerCase();
          final userSkills = (data['skills'] ?? '').toString().toLowerCase();
          final surveyArea = survey.area.toLowerCase();
          final surveyProblem = survey.problemType.toLowerCase();

          bool matchLocation = userLocation.isNotEmpty && (userLocation.contains(surveyArea) || surveyArea.contains(userLocation));
          bool matchSkills = userSkills.isNotEmpty && (userSkills.contains(surveyProblem) || surveyProblem.contains(userSkills));

          if (matchLocation || matchSkills) {
             await _notificationService.logNotification(
               title: 'URGENT DISPATCH: Highly Matched Task!',
               body: 'A critical ${survey.problemType} incident was reported in ${survey.area}. Your skills/location match the requirements!',
               targetUserId: doc.id, 
             );
          }
        }
      }
      return true;
    } catch (e) { debugPrint('Error saving survey: $e');
      return false;
    }
  }

  // We could add more methods here later to retrieve surveys
}
