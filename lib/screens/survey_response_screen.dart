import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/survey_model.dart';
import '../models/survey_response_model.dart';
import '../services/survey_response_service.dart';
import '../services/task_service.dart';

/// Screen for field volunteers to interview respondents one by one.
/// Each "Save & Next" saves ONE respondent's answers and resets the form.
class SurveyResponseScreen extends StatefulWidget {
  final SurveyModel survey;
  final String taskId;

  const SurveyResponseScreen({
    super.key,
    required this.survey,
    required this.taskId,
  });

  @override
  State<SurveyResponseScreen> createState() => _SurveyResponseScreenState();
}

class _SurveyResponseScreenState extends State<SurveyResponseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _responseService = SurveyResponseService();
  final _taskService = TaskService();

  final Color baseColor = const Color(0xFFF2F2F2);

  // Respondent basic info
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = 'Prefer not to say';
  final _addressController = TextEditingController();

  // Dynamic answer controllers per field
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String> _yesNoValues = {};
  final Map<String, String> _selectValues = {};
  final Map<String, double> _scaleValues = {};

  bool _isLoading = false;
  bool _isSurveyDone = false;
  int _responseCount = 0;

  final List<String> _genderOptions = [
    'Male', 'Female', 'Other', 'Prefer not to say'
  ];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadCount();
  }

  void _initControllers() {
    _textControllers.clear();
    for (final def in widget.survey.customFieldDefs) {
      if (def.type == 'text' || def.type == 'number') {
        _textControllers[def.label] = TextEditingController();
      } else if (def.type == 'yesno') {
        _yesNoValues[def.label] = 'Yes';
      } else if (def.type == 'select') {
        _selectValues[def.label] = def.options.isNotEmpty ? def.options.first : '';
      } else if (def.type == 'scale') {
        _scaleValues[def.label] = 3.0;
      }
    }
  }

  Future<void> _loadCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final count = await _responseService.getResponseCountForVolunteer(widget.survey.id!, uid);
    if (mounted) setState(() => _responseCount = count);
  }

  void _resetForm() {
    _nameController.clear();
    _ageController.clear();
    _addressController.clear();
    setState(() => _selectedGender = 'Prefer not to say');
    for (final ctrl in _textControllers.values) { ctrl.clear(); }
    for (final def in widget.survey.customFieldDefs) {
      if (def.type == 'yesno') _yesNoValues[def.label] = 'Yes';
      if (def.type == 'select' && def.options.isNotEmpty) _selectValues[def.label] = def.options.first;
      if (def.type == 'scale') _scaleValues[def.label] = 3.0;
    }
  }

  Future<void> _saveAndNext({bool isDone = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Build answers map
    final Map<String, dynamic> answers = {};
    for (final def in widget.survey.customFieldDefs) {
      if (def.type == 'text' || def.type == 'number') {
        answers[def.label] = def.type == 'number'
            ? (double.tryParse(_textControllers[def.label]?.text ?? '') ?? 0)
            : (_textControllers[def.label]?.text.trim() ?? '');
      } else if (def.type == 'yesno') {
        answers[def.label] = _yesNoValues[def.label] ?? 'Yes';
      } else if (def.type == 'select') {
        answers[def.label] = _selectValues[def.label] ?? '';
      } else if (def.type == 'scale') {
        answers[def.label] = _scaleValues[def.label]?.round() ?? 3;
      }
    }

    final response = SurveyResponseModel(
      surveyId: widget.survey.id!,
      volunteerId: uid,
      taskId: widget.taskId,
      respondentName: _nameController.text.trim().isEmpty ? 'Anonymous' : _nameController.text.trim(),
      respondentAge: int.tryParse(_ageController.text) ?? 0,
      respondentGender: _selectedGender,
      respondentAddress: _addressController.text.trim(),
      answers: answers,
      timestamp: DateTime.now(),
    );

    final ok = await _responseService.submitResponse(response);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) _responseCount++;
    });

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save. Check connection.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (isDone) {
      // Mark task as completed
      await _taskService.completeTask(widget.taskId);
      if (!mounted) return;
      setState(() => _isSurveyDone = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade600,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Entry #$_responseCount saved! Ready for next respondent.'),
            ],
          ),
        ),
      );
      _resetForm();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    for (final c in _textControllers.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSurveyDone) return _buildDoneScreen();

    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        title: Text(
          '${widget.survey.problemType} Survey',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF8A2387)),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8A2387),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_responseCount collected',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [const Color(0xFFF2F2F2), const Color(0xFFE6E6FA).withOpacity(0.5), const Color(0xFFF2F2F2)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Survey context card
                ClayContainer(
                  color: baseColor,
                  borderRadius: 16,
                  depth: 15,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                      ),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${widget.survey.area}  •  🚨 ${widget.survey.urgency} Urgency',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        Text(
                          'Entry #${_responseCount + 1}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Respondent Info ───────────────────────────────
                _sectionLabel('👤 Respondent Info (Optional)'),
                Row(
                  children: [
                    Expanded(child: _clayInput(_nameController, 'Name (or leave blank)')),
                    const SizedBox(width: 12),
                    Expanded(child: _clayInput(_ageController, 'Age', isNumber: true)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ClayContainer(
                    color: baseColor,
                    borderRadius: 14,
                    depth: -18,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: const InputDecoration(border: InputBorder.none, labelText: 'Gender'),
                        items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (v) => setState(() => _selectedGender = v!),
                      ),
                    ),
                  ),
                ),
                _clayInput(_addressController, 'Address / House No. (optional)'),

                const SizedBox(height: 16),

                // ── Custom Questions ──────────────────────────────
                if (widget.survey.customFieldDefs.isNotEmpty) ...[
                  _sectionLabel('📋 Survey Questions'),
                  ...widget.survey.customFieldDefs.asMap().entries.map((e) =>
                      _buildFieldInput(e.key, e.value)),
                ] else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Text(
                      '⚠️ This survey has no custom questions defined. The NGO needs to add questions when creating the survey.',
                      style: TextStyle(color: Colors.black87, fontSize: 13),
                    ),
                  ),

                const SizedBox(height: 24),

                // ── Action Buttons ────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _isLoading ? null : () => _saveAndNext(isDone: false),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE94057).withOpacity(0.35),
                                blurRadius: 12, offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: _isLoading
                              ? const Center(child: SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                              : const Column(
                                  children: [
                                    Text('Save & Next',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text('Respondent', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isLoading ? null : () => _saveAndNext(isDone: true),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 12, offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: const Column(
                            children: [
                              Text('Save & Finish',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('End survey session', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldInput(int index, CustomFieldDef def) {
    final color = _fieldColor(def.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 14,
        depth: 15,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _typeLabel(def.type),
                      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Q${index + 1}: ${def.label}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Render input based on type
              if (def.type == 'text')
                TextFormField(
                  controller: _textControllers[def.label],
                  maxLines: 2,
                  decoration: _inputDecor('Your answer...'),
                )
              else if (def.type == 'number')
                TextFormField(
                  controller: _textControllers[def.label],
                  keyboardType: TextInputType.number,
                  decoration: _inputDecor('Enter number'),
                  validator: (v) {
                    if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                      return 'Must be a number';
                    }
                    return null;
                  },
                )
              else if (def.type == 'yesno')
                Row(
                  children: ['Yes', 'No'].map((opt) {
                    final selected = (_yesNoValues[def.label] ?? 'Yes') == opt;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: opt == 'Yes' ? 6 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _yesNoValues[def.label] = opt),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? (opt == 'Yes' ? Colors.green : Colors.red)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? (opt == 'Yes' ? Colors.green : Colors.red)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                opt,
                                style: TextStyle(
                                  color: selected ? Colors.white : Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                )
              else if (def.type == 'select' && def.options.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: def.options.map((opt) {
                    final selected = (_selectValues[def.label] ?? '') == opt;
                    return GestureDetector(
                      onTap: () => setState(() => _selectValues[def.label] = opt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? color : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? color : Colors.grey.shade300),
                        ),
                        child: Text(
                          opt,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                )
              else if (def.type == 'scale')
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('1\nVery Low', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('5\nVery High', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    Slider(
                      value: _scaleValues[def.label] ?? 3.0,
                      min: 1, max: 5, divisions: 4,
                      activeColor: color,
                      label: (_scaleValues[def.label] ?? 3.0).round().toString(),
                      onChanged: (v) => setState(() => _scaleValues[def.label] = v),
                    ),
                    Center(
                      child: Text(
                        'Selected: ${(_scaleValues[def.label] ?? 3.0).round()}/5',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoneScreen() {
    return Scaffold(
      backgroundColor: baseColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]),
                  boxShadow: [BoxShadow(color: const Color(0xFFE94057).withOpacity(0.4), blurRadius: 20)],
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 24),
              const Text('Survey Session Complete!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              const SizedBox(height: 12),
              Text(
                'You collected $_responseCount respondent entries for this survey.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'The NGO will now analyze this data and decide on next steps.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text('Back to Dashboard',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _clayInput(TextEditingController ctrl, String label,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 12,
        depth: -18,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextFormField(
            controller: ctrl,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(border: InputBorder.none, labelText: label),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(width: 4, height: 20,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'text': return 'Text';
      case 'number': return 'Number';
      case 'yesno': return 'Yes / No';
      case 'select': return 'Multi-choice';
      case 'scale': return 'Scale 1-5';
      default: return type;
    }
  }

  Color _fieldColor(String type) {
    switch (type) {
      case 'text': return Colors.blueAccent;
      case 'number': return Colors.green;
      case 'yesno': return Colors.orange;
      case 'select': return Colors.purple;
      case 'scale': return Colors.amber.shade700;
      default: return Colors.grey;
    }
  }
}
