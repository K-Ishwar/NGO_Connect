import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/survey_model.dart';

class SurveyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> addSurvey(SurveyModel survey) async {
    try {
      await _firestore.collection('surveys').add(survey.toMap());
      return true;
    } catch (e) {
      print('Error saving survey: $e');
      return false;
    }
  }

  // We could add more methods here later to retrieve surveys
}
