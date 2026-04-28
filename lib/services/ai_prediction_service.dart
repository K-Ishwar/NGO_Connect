import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/survey_model.dart';
import '../models/survey_response_model.dart';

class AiPredictionService {
  static const String _apiKey = 'AIzaSyCt7iHZRNAWljryV6B8YBciJpQh4NoW-Ng';

  /// General weekly intelligence report for NGO dashboard
  Future<String> generatePrediction(List<SurveyModel> surveys) async {
    if (surveys.isEmpty) {
      return 'No survey data available yet. Create surveys and collect field data to enable AI predictions.';
    }

    final buffer = StringBuffer();
    for (final s in surveys.take(20)) {
      buffer.writeln(
          '- Area: ${s.area} | Problem: ${s.problemType} | People Affected: ${s.peopleCount} | Urgency: ${s.urgency} | Date: ${s.date.toIso8601String().split('T').first} | Notes: ${s.description}');
    }

    final prompt = '''
You are an expert AI analyst for an NGO field operations platform. 
Based on the following real survey data collected from the field in the last 30 days, provide a concise, actionable intelligence report.

SURVEY DATA:
${buffer.toString()}

Your response MUST follow this EXACT format (use the emoji headers exactly as shown):

🔴 HIGH RISK AREAS
List 2-3 areas or problem types most likely to worsen in the next 7 days, with a short reason.

📊 TREND ANALYSIS
Briefly explain 2-3 key patterns you see in the data (what is increasing, what is concentrated where).

✅ RECOMMENDATIONS
Give 3 specific, actionable steps the NGO should take this week based on the data.

⚠️ EARLY WARNING
Mention 1-2 situations that could become critical if not addressed now.

Keep each section to 2-4 bullet points. Be direct and specific to the data provided.
''';

    try {
      final model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: _apiKey);
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'AI analysis could not be generated. Please try again.';
    } catch (e) {
      return 'Error connecting to AI service: $e\n\nPlease check your internet connection.';
    }
  }

  /// Camp-specific recommendation based on aggregated survey responses
  Future<CampRecommendation> generateCampRecommendation({
    required SurveyModel survey,
    required List<SurveyResponseModel> responses,
  }) async {
    if (responses.isEmpty) {
      return CampRecommendation.empty(
        'No field data collected yet. Assign volunteers to conduct the survey first, then generate a camp recommendation.',
      );
    }

    // Build aggregated stats per question
    final statsBuffer = StringBuffer();
    for (final def in survey.customFieldDefs) {
      final values = responses.map((r) => r.answers[def.label]).where((v) => v != null).toList();
      if (values.isEmpty) continue;

      if (def.type == 'yesno') {
        final yesCount = values.where((v) => v == 'Yes').length;
        statsBuffer.writeln('Q: "${def.label}" → Yes: ${(yesCount / values.length * 100).toStringAsFixed(0)}% (${values.length} respondents)');
      } else if (def.type == 'select') {
        final counts = <String, int>{};
        for (final v in values) { counts[v.toString()] = (counts[v.toString()] ?? 0) + 1; }
        final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        statsBuffer.writeln('Q: "${def.label}" → ${sorted.map((e) => '${e.key}: ${e.value}').join(', ')}');
      } else if (def.type == 'number' || def.type == 'scale') {
        final nums = values.map((v) => (v as num).toDouble()).toList();
        final avg = nums.reduce((a, b) => a + b) / nums.length;
        statsBuffer.writeln('Q: "${def.label}" → Average: ${avg.toStringAsFixed(1)} (${values.length} respondents)');
      } else if (def.type == 'text') {
        statsBuffer.writeln('Q: "${def.label}" → ${values.length} text responses collected');
      }
    }

    // Demographics
    final ages = responses.map((r) => r.respondentAge).where((a) => a > 0).toList();
    final avgAge = ages.isNotEmpty ? (ages.reduce((a, b) => a + b) / ages.length).toStringAsFixed(1) : 'N/A';
    final maleCount = responses.where((r) => r.respondentGender == 'Male').length;
    final femaleCount = responses.where((r) => r.respondentGender == 'Female').length;

    final prompt = '''
You are an expert NGO operations planner. Based on the following community survey data, generate a structured camp/event recommendation.

SURVEY CONTEXT:
- Area: ${survey.area}
- Problem Type: ${survey.problemType}  
- Urgency: ${survey.urgency}
- Description: ${survey.description}
- Total Respondents: ${responses.length}
- Average Age: $avgAge | Male: $maleCount | Female: $femaleCount

AGGREGATED QUESTION DATA:
${statsBuffer.toString()}

Respond ONLY in this EXACT JSON format (no markdown, no extra text):
{
  "camp_name": "Name of the recommended camp/event",
  "camp_type": "Type (e.g. Medical Camp, Food Distribution, Health Awareness, Water & Sanitation Drive)",
  "target_beneficiaries": 150,
  "volunteers_required": 10,
  "urgency_days": 7,
  "resources_needed": ["Resource 1", "Resource 2", "Resource 3", "Resource 4", "Resource 5"],
  "skills_needed": ["Skill 1", "Skill 2", "Skill 3"],
  "key_decisions": ["Decision 1 the NGO must make", "Decision 2", "Decision 3"],
  "summary": "2-3 sentence plain English explanation of why this camp is needed and what it will achieve."
}
''';

    try {
      final model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: _apiKey);
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      return CampRecommendation.fromJson(text, survey.area);
    } catch (e) {
      return CampRecommendation.empty('Error generating recommendation: $e');
    }
  }
}

/// Structured camp recommendation from AI
class CampRecommendation {
  final String campName;
  final String campType;
  final int targetBeneficiaries;
  final int volunteersRequired;
  final int urgencyDays;
  final List<String> resourcesNeeded;
  final List<String> skillsNeeded;
  final List<String> keyDecisions;
  final String summary;
  final bool hasError;
  final String errorMessage;

  CampRecommendation({
    required this.campName,
    required this.campType,
    required this.targetBeneficiaries,
    required this.volunteersRequired,
    required this.urgencyDays,
    required this.resourcesNeeded,
    required this.skillsNeeded,
    required this.keyDecisions,
    required this.summary,
    this.hasError = false,
    this.errorMessage = '',
  });

  factory CampRecommendation.empty(String error) => CampRecommendation(
    campName: '', campType: '', targetBeneficiaries: 0,
    volunteersRequired: 0, urgencyDays: 0,
    resourcesNeeded: [], skillsNeeded: [], keyDecisions: [],
    summary: '', hasError: true, errorMessage: error,
  );

  factory CampRecommendation.fromJson(String raw, String fallbackArea) {
    try {
      // Extract JSON from response (Gemini sometimes wraps in markdown)
      final jsonStr = raw
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      
      // Simple manual parse to avoid dart:convert import complexity
      String extract(String key) {
        final pattern = RegExp('"$key"\\s*:\\s*"([^"]*)"');
        return pattern.firstMatch(jsonStr)?.group(1) ?? '';
      }

      int extractInt(String key) {
        final pattern = RegExp('"$key"\\s*:\\s*(\\d+)');
        return int.tryParse(pattern.firstMatch(jsonStr)?.group(1) ?? '') ?? 0;
      }

      List<String> extractList(String key) {
        final pattern = RegExp('"$key"\\s*:\\s*\\[([^\\]]*)\\]', dotAll: true);
        final match = pattern.firstMatch(jsonStr);
        if (match == null) return [];
        final inner = match.group(1) ?? '';
        return RegExp('"([^"]+)"').allMatches(inner).map((m) => m.group(1)!).toList();
      }

      return CampRecommendation(
        campName: extract('camp_name'),
        campType: extract('camp_type'),
        targetBeneficiaries: extractInt('target_beneficiaries'),
        volunteersRequired: extractInt('volunteers_required'),
        urgencyDays: extractInt('urgency_days'),
        resourcesNeeded: extractList('resources_needed'),
        skillsNeeded: extractList('skills_needed'),
        keyDecisions: extractList('key_decisions'),
        summary: extract('summary'),
      );
    } catch (_) {
      return CampRecommendation.empty('Could not parse AI response. Please try again.');
    }
  }
}
