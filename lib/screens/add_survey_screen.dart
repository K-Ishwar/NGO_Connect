import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/survey_model.dart';
import '../services/survey_service.dart';

class AddSurveyScreen extends StatefulWidget {
  const AddSurveyScreen({super.key});

  @override
  State<AddSurveyScreen> createState() => _AddSurveyScreenState();
}

class _AddSurveyScreenState extends State<AddSurveyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _areaController = TextEditingController();
  final _peopleCountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedProblemType = 'Health';
  String _selectedUrgency = 'Medium';
  bool _isLoading = false;
  bool _isScanning = false;
  final Color baseColor = const Color(0xFFF2F2F2);

  final List<String> _problemTypes = [
    'Health', 'Food', 'Water & Sanitation', 'Education',
    'Shelter', 'Employment', 'Disaster Relief', 'Other',
  ];
  final List<String> _urgencyLevels = ['Low', 'Medium', 'High'];

  // Typed custom field definitions
  final List<Map<String, dynamic>> _fieldDefs = [];
  // For select-type options editing
  final List<TextEditingController> _labelControllers = [];
  final List<TextEditingController> _optionsControllers = []; // comma-sep for 'select'

  void _addField(String type) {
    setState(() {
      _fieldDefs.add({'type': type, 'label': '', 'options': ''});
      _labelControllers.add(TextEditingController());
      _optionsControllers.add(TextEditingController());
    });
  }

  Future<void> _scanPaperSurvey() async {
    try {
      setState(() => _isScanning = true);
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo == null) {
        setState(() => _isScanning = false);
        return;
      }

      final inputImage = InputImage.fromFilePath(photo.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognized = await recognizer.processImage(inputImage);
      await recognizer.close();

      if (recognized.text.isNotEmpty && mounted) {
        // Auto-fill description with scanned text
        _descriptionController.text = recognized.text.trim();
        // Try to auto-detect keywords
        final lower = recognized.text.toLowerCase();
        if (lower.contains('health') || lower.contains('medical')) {
          setState(() => _selectedProblemType = 'Health');
        } else if (lower.contains('food') || lower.contains('hunger')) {
          setState(() => _selectedProblemType = 'Food');
        } else if (lower.contains('education') || lower.contains('school')) {
          setState(() => _selectedProblemType = 'Education');
        } else if (lower.contains('water') || lower.contains('sanitation')) {
          setState(() => _selectedProblemType = 'Water & Sanitation');
        } else if (lower.contains('shelter') || lower.contains('housing')) {
          setState(() => _selectedProblemType = 'Shelter');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scanned ${recognized.blocks.length} text blocks. Description auto-filled!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text detected. Try in better lighting.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scanner error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _removeField(int index) {
    setState(() {
      _labelControllers[index].dispose();
      _optionsControllers[index].dispose();
      _fieldDefs.removeAt(index);
      _labelControllers.removeAt(index);
      _optionsControllers.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Fetch NGO display name for Community Hub display
    String ngoName = 'NGO';
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) ngoName = (userDoc.data()?['name'] ?? 'NGO') as String;
    } catch (_) {}

    // Build typed field definitions
    final defs = <CustomFieldDef>[];
    for (int i = 0; i < _fieldDefs.length; i++) {
      final label = _labelControllers[i].text.trim();
      if (label.isEmpty) continue;
      final type = _fieldDefs[i]['type'] as String;
      final optionsRaw = _optionsControllers[i].text.trim();
      final options = type == 'select'
          ? optionsRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : <String>[];
      defs.add(CustomFieldDef(label: label, type: type, options: options));
    }

    // Also keep flat list for backwards compat with existing analytics
    final flatFields = defs.map((d) => d.label).toList();

    final survey = SurveyModel(
      ngoId: uid,
      ngoName: ngoName,
      area: _areaController.text.trim(),
      problemType: _selectedProblemType,
      peopleCount: int.parse(_peopleCountController.text.trim()),
      urgency: _selectedUrgency,
      description: _descriptionController.text.trim(),
      date: DateTime.now(),
      customFields: flatFields,
      customFieldDefs: defs,
      phase: 'survey_phase',
    );

    final ok = await SurveyService().addSurvey(survey);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Survey campaign created!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create survey. Try again.')),
      );
    }
  }

  @override
  void dispose() {
    _areaController.dispose();
    _peopleCountController.dispose();
    _descriptionController.dispose();
    for (var c in _labelControllers) { c.dispose(); }
    for (var c in _optionsControllers) { c.dispose(); }
    super.dispose();
  }

  Widget _clayInput(
    TextEditingController ctrl,
    String label, {
    bool isNumber = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 14,
        depth: -20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextFormField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            validator: validator,
            decoration: InputDecoration(border: InputBorder.none, labelText: label),
          ),
        ),
      ),
    );
  }

  Widget _dropdownField(String label, String value, List<String> items, void Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 14,
        depth: -20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(border: InputBorder.none, labelText: label),
            items: items.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => onChanged(v!),
          ),
        ),
      ),
    );
  }

  Widget _fieldTypeChip(String type, IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () => _addField(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'text': return 'Text';
      case 'number': return 'Number';
      case 'yesno': return 'Yes/No';
      case 'select': return 'Multiple Choice';
      case 'scale': return 'Scale 1-5';
      default: return type;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'text': return Icons.short_text;
      case 'number': return Icons.pin;
      case 'yesno': return Icons.toggle_on;
      case 'select': return Icons.list;
      case 'scale': return Icons.star_half;
      default: return Icons.help_outline;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'text': return Colors.blueAccent;
      case 'number': return Colors.green;
      case 'yesno': return Colors.orange;
      case 'select': return Colors.purple;
      case 'scale': return Colors.amber;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        title: const Text('New Survey Campaign', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF8A2387)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF2F2F2),
              const Color(0xFFE6E6FA).withValues(alpha: 0.5),
              const Color(0xFFF2F2F2),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                  ).createShader(bounds),
                  child: const Text(
                    'Survey Campaign',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Define the survey area, assign it to volunteers, then collect data per respondent.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // ── OCR Scan Button ────────────────────────────────
                GestureDetector(
                  onTap: _isScanning ? null : _scanPaperSurvey,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: _isScanning
                          ? const LinearGradient(colors: [Colors.grey, Colors.grey])
                          : const LinearGradient(
                              colors: [Color(0xFF6A0DAD), Color(0xFF8A2387)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8A2387).withValues(alpha: 0.3),
                          blurRadius: 10, offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isScanning
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.document_scanner, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          _isScanning ? 'Scanning...' : '📄 Scan Paper Survey (OCR)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Basic Details ─────────────────────────────────
                _sectionLabel('📍 Survey Details'),
                _clayInput(_areaController, 'Area / Location',
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                _dropdownField('Problem Type', _selectedProblemType, _problemTypes,
                    (v) => setState(() => _selectedProblemType = v)),
                _clayInput(_peopleCountController, 'Estimated People Affected', isNumber: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (int.tryParse(v) == null) return 'Must be a number';
                      return null;
                    }),
                _dropdownField('Urgency Level', _selectedUrgency, _urgencyLevels,
                    (v) => setState(() => _selectedUrgency = v)),
                _clayInput(_descriptionController, 'Description / Context', maxLines: 3,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null),

                const SizedBox(height: 20),

                // ── Custom Questions ──────────────────────────────
                _sectionLabel('📝 Custom Survey Questions'),
                const Text(
                  'Add questions that volunteers will ask each respondent. Choose the answer type:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),

                // Field type buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _fieldTypeChip('text', Icons.short_text, '+ Text', Colors.blueAccent),
                    _fieldTypeChip('number', Icons.pin, '+ Number', Colors.green),
                    _fieldTypeChip('yesno', Icons.toggle_on, '+ Yes/No', Colors.orange),
                    _fieldTypeChip('select', Icons.list, '+ Multi-choice', Colors.purple),
                    _fieldTypeChip('scale', Icons.star_half, '+ Scale 1-5', Colors.amber),
                  ],
                ),
                const SizedBox(height: 12),

                // Existing field definitions
                ..._fieldDefs.asMap().entries.map((entry) {
                  final i = entry.key;
                  final def = entry.value;
                  final type = def['type'] as String;
                  final color = _typeColor(type);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ClayContainer(
                      color: baseColor,
                      borderRadius: 14,
                      depth: 15,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_typeIcon(type), size: 16, color: color),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _typeLabel(type),
                                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                  onPressed: () => _removeField(i),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _labelControllers[i],
                              decoration: InputDecoration(
                                hintText: 'Question ${i + 1} (e.g. Do you have clean water access?)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Enter question text' : null,
                            ),
                            if (type == 'select') ...[
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _optionsControllers[i],
                                decoration: InputDecoration(
                                  hintText: 'Options (comma-separated): Malaria, Dengue, TB, Other',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.purple.withValues(alpha: 0.3)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                if (_fieldDefs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                    ),
                    child: const Text(
                      'No questions added yet. Tap a question type above to start building your survey form.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13),
                    ),
                  ),

                const SizedBox(height: 32),

                // Submit
                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFE94057)))
                    : GestureDetector(
                        onTap: _submit,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE94057).withValues(alpha: 0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'CREATE SURVEY CAMPAIGN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 40),
              ],
            ),
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
          Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        ],
      ),
    );
  }
}
