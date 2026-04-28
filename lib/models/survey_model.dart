import 'package:cloud_firestore/cloud_firestore.dart';

/// Defines a single custom question with a type and optional choices.
class CustomFieldDef {
  final String label;
  final String type;      // 'text' | 'number' | 'yesno' | 'select' | 'scale'
  final List<String> options; // For 'select' type only

  const CustomFieldDef({
    required this.label,
    required this.type,
    this.options = const [],
  });

  Map<String, dynamic> toMap() => {
    'label': label,
    'type': type,
    'options': options,
  };

  factory CustomFieldDef.fromMap(Map<String, dynamic> map) => CustomFieldDef(
    label: map['label'] ?? '',
    type: map['type'] ?? 'text',
    options: List<String>.from(map['options'] ?? []),
  );
}

class SurveyModel {
  final String? id;
  final String ngoId;
  final String ngoName;        // Display name of the NGO (for Community Hub)
  final String area;
  final String problemType;
  final int peopleCount;
  final String urgency;
  final String description;
  final DateTime date;

  // Legacy flat list (kept for backwards compat)
  final List<String> customFields;

  // NEW: typed field definitions (replaces customFields going forward)
  final List<CustomFieldDef> customFieldDefs;

  // NEW: survey lifecycle phase
  final String phase; // 'survey_phase' | 'completed'

  SurveyModel({
    this.id,
    required this.ngoId,
    this.ngoName = '',
    required this.area,
    required this.problemType,
    required this.peopleCount,
    required this.urgency,
    required this.description,
    required this.date,
    this.customFields = const [],
    this.customFieldDefs = const [],
    this.phase = 'survey_phase',
  });

  Map<String, dynamic> toMap() {
    return {
      'ngo_id': ngoId,
      'ngo_name': ngoName,
      'area': area,
      'problem_type': problemType,
      'people_count': peopleCount,
      'urgency': urgency,
      'description': description,
      'date': Timestamp.fromDate(date),
      'custom_fields': customFields,
      'custom_field_defs': customFieldDefs.map((f) => f.toMap()).toList(),
      'phase': phase,
    };
  }

  factory SurveyModel.fromMap(Map<String, dynamic> map, String documentId) {
    // Parse typed defs if they exist, else build from flat list for old docs
    final rawDefs = map['custom_field_defs'];
    List<CustomFieldDef> defs = [];
    if (rawDefs != null && rawDefs is List && rawDefs.isNotEmpty) {
      defs = rawDefs
          .map((e) => CustomFieldDef.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      // Backwards compat: treat old flat string fields as text type
      final flat = List<String>.from(map['custom_fields'] ?? []);
      defs = flat.map((f) => CustomFieldDef(label: f, type: 'text')).toList();
    }

    return SurveyModel(
      id: documentId,
      ngoId: map['ngo_id'] ?? '',
      ngoName: map['ngo_name'] ?? '',
      area: map['area'] ?? '',
      problemType: map['problem_type'] ?? '',
      peopleCount: (map['people_count'] as num?)?.toInt() ?? 0,
      urgency: map['urgency'] ?? '',
      description: map['description'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      customFields: List<String>.from(map['custom_fields'] ?? []),
      customFieldDefs: defs,
      phase: map['phase'] ?? 'survey_phase',
    );
  }
}
