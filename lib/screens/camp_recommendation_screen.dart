import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/survey_model.dart';
import '../models/camp_model.dart';
import '../services/ai_prediction_service.dart';
import '../services/survey_response_service.dart';
import '../services/camp_service.dart';
import 'camp_detail_screen.dart';

class CampRecommendationScreen extends StatefulWidget {
  final SurveyModel survey;

  const CampRecommendationScreen({super.key, required this.survey});

  @override
  State<CampRecommendationScreen> createState() => _CampRecommendationScreenState();
}

class _CampRecommendationScreenState extends State<CampRecommendationScreen> {
  final Color baseColor = const Color(0xFFF2F2F2);

  CampRecommendation? _recommendation;
  bool _isLoading = false;
  bool _isCreating = false;
  String? _error;

  // Editable fields after AI fills them
  late TextEditingController _campNameCtrl;
  late TextEditingController _targetCtrl;
  late TextEditingController _volunteersCtrl;
  late TextEditingController _summaryCtrl;
  late TextEditingController _resourcesCtrl;
  late TextEditingController _skillsCtrl;
  String _campType = 'Medical Camp';
  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 7));

  final _campTypes = [
    'Medical Camp', 'Food Distribution', 'Health Awareness Drive',
    'Water & Sanitation', 'Education Camp', 'Disaster Relief', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _campNameCtrl = TextEditingController();
    _targetCtrl = TextEditingController();
    _volunteersCtrl = TextEditingController();
    _summaryCtrl = TextEditingController();
    _resourcesCtrl = TextEditingController();
    _skillsCtrl = TextEditingController();
    _generateRecommendation();
  }

  @override
  void dispose() {
    _campNameCtrl.dispose();
    _targetCtrl.dispose();
    _volunteersCtrl.dispose();
    _summaryCtrl.dispose();
    _resourcesCtrl.dispose();
    _skillsCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateRecommendation() async {
    setState(() { _isLoading = true; _error = null; });

    final responses = await SurveyResponseService()
        .getResponsesForSurvey(widget.survey.id!);

    final rec = await AiPredictionService().generateCampRecommendation(
      survey: widget.survey,
      responses: responses,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _recommendation = rec;
      if (rec.hasError) {
        _error = rec.errorMessage;
      } else {
        _campNameCtrl.text = rec.campName;
        _targetCtrl.text = rec.targetBeneficiaries.toString();
        _volunteersCtrl.text = rec.volunteersRequired.toString();
        _summaryCtrl.text = rec.summary;
        _resourcesCtrl.text = rec.resourcesNeeded.join('\n');
        _skillsCtrl.text = rec.skillsNeeded.join(', ');
        if (_campTypes.contains(rec.campType)) _campType = rec.campType;
        _scheduledDate = DateTime.now().add(Duration(days: rec.urgencyDays > 0 ? rec.urgencyDays : 7));
      }
    });
  }

  Future<void> _createCamp() async {
    setState(() => _isCreating = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final resources = _resourcesCtrl.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final skills = _skillsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final camp = CampModel(
      ngoId: uid,
      sourceSurveyId: widget.survey.id!,
      campName: _campNameCtrl.text.trim(),
      area: widget.survey.area,
      campType: _campType,
      scheduledDate: _scheduledDate,
      volunteersRequired: int.tryParse(_volunteersCtrl.text) ?? 5,
      targetBeneficiaries: int.tryParse(_targetCtrl.text) ?? 0,
      resourcesNeeded: resources,
      skillsNeeded: skills,
      status: 'planned',
      aiRecommendation: _summaryCtrl.text,
    );

    final campId = await CampService().createCamp(camp);
    if (!mounted) return;
    setState(() => _isCreating = false);

    if (campId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text('Camp created successfully!')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CampDetailScreen(camp: camp.copyWith(id: campId)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.red, content: Text('Failed to create camp.')),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        title: const Text('AI Camp Recommendation', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF8A2387)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _generateRecommendation,
            tooltip: 'Regenerate',
          ),
        ],
      ),
      body: _isLoading ? _buildLoading() : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Gemini AI is analysing survey data...', style: TextStyle(fontSize: 16, color: Colors.deepPurple, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Generating camp recommendation', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _generateRecommendation,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // AI banner
          ClayContainer(
            color: baseColor, borderRadius: 16, depth: 20,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.psychology, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text('Gemini AI Recommendation', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ]),
                  const SizedBox(height: 8),
                  Text(_summaryCtrl.text.isNotEmpty ? _summaryCtrl.text :
                      'AI has analysed ${widget.survey.area} survey data and generated the plan below.',
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Key decisions
          if (_recommendation != null && _recommendation!.keyDecisions.isNotEmpty) ...[
            _sectionLabel('🧠 Key Decisions for NGO', Colors.deepOrange),
            const SizedBox(height: 8),
            ClayContainer(
              color: baseColor, borderRadius: 14, depth: 15,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _recommendation!.keyDecisions.asMap().entries.map((e) =>
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: Colors.deepOrange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('${e.key + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(e.value, style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    )
                  ).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Editable camp form
          _sectionLabel('✏️ Review & Edit Camp Details', Colors.deepPurple),
          const SizedBox(height: 10),

          _clayTextField(_campNameCtrl, 'Camp Name', Icons.event),
          const SizedBox(height: 10),

          // Camp type dropdown
          ClayContainer(
            color: baseColor, borderRadius: 14, depth: -18,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: DropdownButtonFormField<String>(
                value: _campType,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: 'Camp Type',
                  prefixIcon: Icon(Icons.category, color: Color(0xFF8A2387)),
                ),
                items: _campTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _campType = v!),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(child: _clayTextField(_targetCtrl, 'Target Beneficiaries', Icons.people,
                  isNumber: true)),
              const SizedBox(width: 10),
              Expanded(child: _clayTextField(_volunteersCtrl, 'Volunteers Needed', Icons.group,
                  isNumber: true)),
            ],
          ),
          const SizedBox(height: 10),

          // Date picker
          GestureDetector(
            onTap: _pickDate,
            child: ClayContainer(
              color: baseColor, borderRadius: 14, depth: -18,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFF8A2387)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Scheduled Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          '${_scheduledDate.day}/${_scheduledDate.month}/${_scheduledDate.year}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text('Tap to change', style: TextStyle(fontSize: 11, color: Colors.deepPurple)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          _clayTextField(_resourcesCtrl, 'Resources Needed (one per line)', Icons.inventory_2,
              maxLines: 5),
          const SizedBox(height: 10),

          _clayTextField(_skillsCtrl, 'Skills Needed (comma-separated)', Icons.star,
              maxLines: 2),
          const SizedBox(height: 32),

          // Approve button
          _isCreating
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF8A2387)))
              : GestureDetector(
                  onTap: _createCamp,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE94057).withOpacity(0.4),
                          blurRadius: 15, offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 10),
                        Text('APPROVE & CREATE CAMP',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ],
                    ),
                  ),
                ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _clayTextField(TextEditingController ctrl, String label, IconData icon,
      {bool isNumber = false, int maxLines = 1}) {
    return ClayContainer(
      color: baseColor, borderRadius: 14, depth: -18,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            border: InputBorder.none,
            labelText: label,
            prefixIcon: Icon(icon, color: const Color(0xFF8A2387)),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 20,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

extension on CampModel {
  CampModel copyWith({String? id}) => CampModel(
    id: id ?? this.id,
    ngoId: ngoId, sourceSurveyId: sourceSurveyId,
    campName: campName, area: area, campType: campType,
    scheduledDate: scheduledDate, volunteersRequired: volunteersRequired,
    targetBeneficiaries: targetBeneficiaries, resourcesNeeded: resourcesNeeded,
    skillsNeeded: skillsNeeded, status: status, aiRecommendation: aiRecommendation,
    createdAt: createdAt,
  );
}
