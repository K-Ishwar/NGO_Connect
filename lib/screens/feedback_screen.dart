import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/feedback_model.dart';
import '../models/survey_model.dart';
import '../services/feedback_service.dart';
import '../services/offline_sync_service.dart';

class FeedbackScreen extends StatefulWidget {
  final String taskId;
  final String surveyId;
  const FeedbackScreen({
    super.key,
    required this.taskId,
    required this.surveyId,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();

  final _peopleHelpedController = TextEditingController();
  final _remainingNeedController = TextEditingController();
  final _commentsController = TextEditingController();

  bool _isLoading = false;
  final Color baseColor = const Color(0xFFF2F2F2);

  SurveyModel? _surveyModel;
  final Map<String, TextEditingController> _customControllers = {};

  @override
  void initState() {
    super.initState();
    _loadSurvey();
  }

  Future<void> _loadSurvey() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('surveys')
          .doc(widget.surveyId)
          .get();
      if (doc.exists) {
        setState(() {
          _surveyModel = SurveyModel.fromMap(doc.data()!, doc.id);
          for (var field in _surveyModel!.customFields) {
            _customControllers[field] = TextEditingController();
          }
        });
      }
    } catch (e) {
      print('Error loading survey custom fields: $e');
    }
  }

  bool _isScanning = false;

  Future<void> _scanPaperSurvey() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'OCR Scanning is only supported on Android/iOS. Please type manually on Web.',
          ),
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isScanning = true);

    try {
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      String scannedText = recognizedText.text;

      // Simple auto-fill logic for standard fields
      final RegExp numRegex = RegExp(r'\b\d{1,4}\b');
      final match = numRegex.firstMatch(scannedText);
      if (match != null) {
        _peopleHelpedController.text = match.group(0)!;
      }

      // Very simple custom field filler: just append all text to the first custom field, or comments
      if (_surveyModel != null && _surveyModel!.customFields.isNotEmpty) {
        String firstKey = _surveyModel!.customFields.first;
        _customControllers[firstKey]!.text = "Scanned: $scannedText";
      } else {
        _commentsController.text =
            "Scanned Form Data:\n$scannedText\n\n${_commentsController.text}";
      }

      textRecognizer.close();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OCR Scan Complete! Form auto-filled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to scan: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final customAnswers = <String, String>{};
    _customControllers.forEach((key, controller) {
      if (controller.text.trim().isNotEmpty) {
        customAnswers[key] = controller.text.trim();
      }
    });

    final feedbackModel = FeedbackModel(
      taskId: widget.taskId,
      surveyId: widget.surveyId,
      volunteerId: FirebaseAuth.instance.currentUser!.uid,
      peopleHelped: int.tryParse(_peopleHelpedController.text) ?? 0,
      remainingNeed: _remainingNeedController.text.trim(),
      comments: _commentsController.text.trim(),
      date: DateTime.now(),
      customAnswers: customAnswers,
    );

    final feedbackMap = feedbackModel.toMap();
    // Store date as ISO string for Hive compatibility
    feedbackMap['date'] = DateTime.now().toIso8601String();

    final isOnline = await OfflineSyncService.isConnected();

    if (!isOnline) {
      // Save offline
      await OfflineSyncService.savePendingFeedback(feedbackMap);
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange.shade700,
          content: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Saved Offline! Will auto-sync when connected.'),
              ),
            ],
          ),
        ),
      );
      Navigator.pop(context);
      return;
    }

    final success = await FeedbackService().submitFeedbackAndCompleteTask(
      feedbackModel,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task completed & feedback submitted!')),
      );
      Navigator.pop(context); // Return to Dashboard
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit feedback.')),
      );
    }
  }

  @override
  void dispose() {
    _peopleHelpedController.dispose();
    _remainingNeedController.dispose();
    _commentsController.dispose();
    for (var controller in _customControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildInput(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 15,
        depth: -20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            validator:
                validator ??
                (val) => val == null || val.isEmpty ? 'Required' : null,
            decoration: InputDecoration(
              border: InputBorder.none,
              labelText: label,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        title: const Text(
          'Complete Task',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
              const Color(0xFFE6E6FA).withOpacity(0.5),
              const Color(0xFFF2F2F2),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ClayContainer(
            color: baseColor,
            borderRadius: 30,
            depth: 20,
            spread: 5,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mission Report',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            foreground: Paint()
                              ..shader =
                                  const LinearGradient(
                                    colors: [
                                      Color(0xFF8A2387),
                                      Color(0xFFE94057),
                                    ],
                                  ).createShader(
                                    const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                                  ),
                          ),
                        ),
                        _isScanning
                            ? const CircularProgressIndicator(
                                color: Color(0xFF8A2387),
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.document_scanner,
                                  color: Color(0xFF8A2387),
                                  size: 36,
                                ),
                                onPressed: _scanPaperSurvey,
                                tooltip: 'Scan Paper Survey (OCR)',
                              ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildInput(
                      _peopleHelpedController,
                      'Number of People Helped',
                      isNumber: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (int.tryParse(value) == null) {
                          return 'Must be a valid number';
                        }
                        return null;
                      },
                    ),

                    _buildInput(
                      _remainingNeedController,
                      'Remaining Needs (e.g. Needs more blankets)',
                      maxLines: 2,
                    ),
                    _buildInput(
                      _commentsController,
                      'Comments / Notes',
                      maxLines: 3,
                      validator: (val) => null,
                    ),

                    if (_surveyModel != null &&
                        _surveyModel!.customFields.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text(
                        'Custom Survey Questions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._surveyModel!.customFields.map((field) {
                        return _buildInput(
                          _customControllers[field]!,
                          field,
                          validator: (val) => null, // Optional by default
                        );
                      }),
                    ],

                    const SizedBox(height: 32),

                    _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFE94057),
                            ),
                          )
                        : GestureDetector(
                            onTap: _submitFeedback,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8A2387),
                                    Color(0xFFE94057),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFE94057,
                                    ).withOpacity(0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Text(
                                    'SUBMIT & COMPLETE TASK',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
