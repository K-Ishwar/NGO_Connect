import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/survey_response_model.dart';

class SurveyResponseService {
  final _db = FirebaseFirestore.instance;

  /// Save a single respondent's answers (called once per person in the field)
  Future<bool> submitResponse(SurveyResponseModel response) async {
    try {
      await _db.collection('survey_responses').add(response.toMap());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get all responses for a given survey (for analytics)
  Future<List<SurveyResponseModel>> getResponsesForSurvey(String surveyId) async {
    final snap = await _db
        .collection('survey_responses')
        .where('survey_id', isEqualTo: surveyId)
        .get();
    return snap.docs
        .map((d) => SurveyResponseModel.fromMap(d.data(), d.id))
        .toList();
  }

  /// Stream of responses for a survey (live updates for analytics screen)
  Stream<List<SurveyResponseModel>> streamResponsesForSurvey(String surveyId) {
    return _db
        .collection('survey_responses')
        .where('survey_id', isEqualTo: surveyId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SurveyResponseModel.fromMap(d.data(), d.id))
            .toList());
  }

  /// Count of responses for a volunteer in a specific survey session
  Future<int> getResponseCountForVolunteer(String surveyId, String volunteerId) async {
    final snap = await _db
        .collection('survey_responses')
        .where('survey_id', isEqualTo: surveyId)
        .where('volunteer_id', isEqualTo: volunteerId)
        .get();
    return snap.docs.length;
  }
}
