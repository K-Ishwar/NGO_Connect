import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/survey_model.dart';
import '../services/ai_prediction_service.dart';

class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  final Color baseColor = const Color(0xFFF2F2F2);
  String? _report;
  bool _isLoading = false;
  DateTime? _lastGenerated;

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
      _report = null;
    });

    // Fetch last 30 days of surveys
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final snap = await FirebaseFirestore.instance
        .collection('surveys')
        .where('date', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('date', descending: true)
        .get();

    final surveys = snap.docs
        .map((d) => SurveyModel.fromMap(d.data(), d.id))
        .toList();

    final report = await AiPredictionService().generatePrediction(surveys);

    if (mounted) {
      setState(() {
        _report = report;
        _isLoading = false;
        _lastGenerated = DateTime.now();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        title: const Text('🤖 AI Insights'),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF8A2387)),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF8A2387)),
              onPressed: _generateReport,
              tooltip: 'Regenerate',
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF2F2F2),
              const Color(0xFFE6E6FA).withOpacity(0.6),
              const Color(0xFFF2F2F2),
            ],
          ),
        ),
        child: _isLoading
            ? _buildLoadingState()
            : _buildReportView(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF8A2387),
                  strokeWidth: 3,
                ),
                const Icon(Icons.psychology, color: Color(0xFF8A2387), size: 36),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Gemini AI is analyzing\nyour field data...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Processing surveys from the last 30 days',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildReportView() {
    if (_report == null) return const SizedBox();

    // Parse sections from the AI report
    final sections = _parseSections(_report!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header card
          ClayContainer(
            color: baseColor,
            borderRadius: 20,
            depth: 20,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.psychology, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'AI Field Intelligence Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Powered by Gemini 1.5 Flash  •  ${_lastGenerated != null ? "Generated at ${_lastGenerated!.hour.toString().padLeft(2, '0')}:${_lastGenerated!.minute.toString().padLeft(2, '0')}" : ""}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Render sections
          ...sections.map((section) => _buildSectionCard(section)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  List<_ReportSection> _parseSections(String report) {
    final sectionHeaders = {
      '🔴': ('High Risk Areas', Colors.red.shade400),
      '📊': ('Trend Analysis', Colors.blueAccent),
      '✅': ('Recommendations', Colors.green),
      '⚠️': ('Early Warning', Colors.orange),
    };

    List<_ReportSection> sections = [];

    // Split by emoji headers
    final lines = report.split('\n');
    String? currentEmoji;
    String? currentTitle;
    Color? currentColor;
    List<String> currentLines = [];

    for (final line in lines) {
      String? foundEmoji;
      for (final emoji in sectionHeaders.keys) {
        if (line.startsWith(emoji)) {
          foundEmoji = emoji;
          break;
        }
      }

      if (foundEmoji != null) {
        if (currentEmoji != null && currentLines.isNotEmpty) {
          sections.add(_ReportSection(
            emoji: currentEmoji,
            title: currentTitle!,
            color: currentColor!,
            content: currentLines.where((l) => l.trim().isNotEmpty).join('\n'),
          ));
          currentLines = [];
        }
        currentEmoji = foundEmoji;
        currentTitle = sectionHeaders[foundEmoji]!.$1;
        currentColor = sectionHeaders[foundEmoji]!.$2;
      } else if (currentEmoji != null) {
        currentLines.add(line);
      }
    }

    if (currentEmoji != null && currentLines.isNotEmpty) {
      sections.add(_ReportSection(
        emoji: currentEmoji,
        title: currentTitle!,
        color: currentColor!,
        content: currentLines.where((l) => l.trim().isNotEmpty).join('\n'),
      ));
    }

    // If parsing failed (format different), just show the whole thing
    if (sections.isEmpty) {
      sections.add(_ReportSection(
        emoji: '🤖',
        title: 'AI Analysis',
        color: Colors.deepPurple,
        content: report,
      ));
    }

    return sections;
  }

  Widget _buildSectionCard(_ReportSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 16,
        depth: 20,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 28,
                    decoration: BoxDecoration(
                      color: section.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${section.emoji} ${section.title}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: section.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                section.content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportSection {
  final String emoji;
  final String title;
  final Color color;
  final String content;

  const _ReportSection({
    required this.emoji,
    required this.title,
    required this.color,
    required this.content,
  });
}
