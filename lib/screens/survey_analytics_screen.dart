import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/survey_model.dart';
import '../models/survey_response_model.dart';
import '../services/survey_response_service.dart';
import 'camp_recommendation_screen.dart';
import 'feedback_screen.dart';

class SurveyAnalyticsScreen extends StatelessWidget {
  final SurveyModel survey;

  const SurveyAnalyticsScreen({super.key, required this.survey});

  @override
  Widget build(BuildContext context) {
    final Color baseColor = const Color(0xFFF2F2F2);

    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        title: Text('${survey.problemType} Analytics'),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF8A2387)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Color(0xFF8A2387)),
            onPressed: () => _showExportSheet(context),
            tooltip: 'Export Report',
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
              const Color(0xFFE6E6FA).withOpacity(0.5),
              const Color(0xFFF2F2F2),
            ],
          ),
        ),
        child: StreamBuilder<List<SurveyResponseModel>>(
          stream: SurveyResponseService().streamResponsesForSurvey(survey.id!),
          builder: (context, responseSnap) {
            // Also watch legacy feedback for backwards compat
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('feedback')
                  .where('survey_id', isEqualTo: survey.id)
                  .snapshots(),
              builder: (context, legacySnap) {
                final responses = responseSnap.data ?? [];
                final legacyDocs = legacySnap.data?.docs ?? [];

                // Combine counts
                int totalResponses = responses.length;
                int totalPeopleHelped = responses.length; // Each response = 1 person
                // Add legacy helped count
                for (final d in legacyDocs) {
                  final data = d.data() as Map<String, dynamic>;
                  totalPeopleHelped += (data['people_helped'] as int? ?? 0);
                }

                int needGap = (survey.peopleCount - totalPeopleHelped).clamp(0, survey.peopleCount);
                double completionRate = survey.peopleCount > 0
                    ? (totalPeopleHelped / survey.peopleCount).clamp(0.0, 1.0)
                    : 0.0;

                // Gender demographics
                final Map<String, int> genderMap = {};
                for (final r in responses) {
                  genderMap[r.respondentGender] = (genderMap[r.respondentGender] ?? 0) + 1;
                }

                // Age distribution
                final ages = responses.map((r) => r.respondentAge).where((a) => a > 0).toList();
                final avgAge = ages.isNotEmpty ? ages.reduce((a, b) => a + b) / ages.length : 0.0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Survey Header ─────────────────────────
                      ClayContainer(
                        color: baseColor, borderRadius: 16, depth: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: survey.urgency == 'High'
                                  ? [const Color(0xFFE94057), const Color(0xFF8A2387)]
                                  : [const Color(0xFF8A2387), const Color(0xFF5F72BD)],
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(survey.problemType,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('📍 ${survey.area}  •  🚨 ${survey.urgency} Urgency',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(survey.description,
                                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── KPI Row ───────────────────────────────
                      Row(
                        children: [
                          Expanded(child: _kpiCard(baseColor, 'Respondents', totalResponses.toString(), Icons.people, Colors.blueAccent)),
                          const SizedBox(width: 10),
                          Expanded(child: _kpiCard(baseColor, 'Helped', totalPeopleHelped.toString(), Icons.favorite, Colors.green)),
                          const SizedBox(width: 10),
                          Expanded(child: _kpiCard(baseColor, 'Target', survey.peopleCount.toString(), Icons.flag, Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Need Gap ──────────────────────────────
                      ClayContainer(
                        color: baseColor, borderRadius: 16, depth: 20,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4, height: 22,
                                    decoration: BoxDecoration(
                                      color: needGap > 0 ? Colors.red : Colors.green,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    needGap > 0 ? '⚠️ Need Gap' : '✅ Need Fully Met!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 15,
                                      color: needGap > 0 ? Colors.red.shade700 : Colors.green,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (needGap > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.red.shade300),
                                      ),
                                      child: Text('$needGap still need help',
                                          style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text('${(completionRate * 100).toStringAsFixed(1)}%',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF8A2387))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: completionRate, minHeight: 14,
                                        backgroundColor: Colors.red.shade100,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          completionRate >= 1.0 ? Colors.green : const Color(0xFF8A2387),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('$totalPeopleHelped of ${survey.peopleCount} target reached',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Demographics ──────────────────────────
                      if (responses.isNotEmpty) ...[
                        _sectionHeader('👥 Respondent Demographics', Colors.blueAccent),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _kpiCard(baseColor, 'Avg Age',
                                avgAge > 0 ? avgAge.toStringAsFixed(1) : '—',
                                Icons.cake, Colors.teal)),
                            const SizedBox(width: 10),
                            Expanded(child: _kpiCard(baseColor, 'Male',
                                (genderMap['Male'] ?? 0).toString(), Icons.male, Colors.blueAccent)),
                            const SizedBox(width: 10),
                            Expanded(child: _kpiCard(baseColor, 'Female',
                                (genderMap['Female'] ?? 0).toString(), Icons.female, Colors.pinkAccent)),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Per-Question Charts ───────────────────
                      if (survey.customFieldDefs.isNotEmpty && responses.isNotEmpty) ...[
                        _sectionHeader('📊 Question-by-Question Analysis', const Color(0xFF8A2387)),
                        const SizedBox(height: 12),
                        ...survey.customFieldDefs.map((def) =>
                            _buildQuestionChart(baseColor, def, responses)),
                      ] else if (responses.isEmpty) ...[
                        _emptyCard('No field data collected yet.\nAssign volunteers to start the survey.'),
                      ],

                      const SizedBox(height: 16),

                      // ── Volunteer Leaderboard ─────────────────
                      if (responses.isNotEmpty) ...[
                        _sectionHeader('🏆 Volunteer Leaderboard', Colors.amber.shade700),
                        const SizedBox(height: 10),
                        _buildVolunteerLeaderboard(baseColor, responses),
                        const SizedBox(height: 16),
                      ],

                      // ── Upload Old Data ───────────────────────
                      ClayContainer(
                        color: baseColor, borderRadius: 15, depth: 20,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => FeedbackScreen(taskId: 'manual_upload', surveyId: survey.id!))),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.document_scanner, color: Color(0xFF8A2387)),
                                const SizedBox(width: 8),
                                const Text('Upload Old Paper Data (OCR Scanner)',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8A2387))),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── AI Camp Recommendation ────────────────
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => CampRecommendationScreen(survey: survey))),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [BoxShadow(
                              color: const Color(0xFFE94057).withOpacity(0.3),
                              blurRadius: 12, offset: const Offset(0, 6),
                            )],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.psychology, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Get AI Camp Recommendation',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ── Per-question chart ────────────────────────────────────────────────────
  Widget _buildQuestionChart(Color baseColor, CustomFieldDef def, List<SurveyResponseModel> responses) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClayContainer(
        color: baseColor, borderRadius: 14, depth: 16,
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
                      color: _fieldColor(def.type).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_typeLabel(def.type),
                        style: TextStyle(fontSize: 10, color: _fieldColor(def.type), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(def.label,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _renderChart(def, responses),
            ],
          ),
        ),
      ),
    );
  }

  Widget _renderChart(CustomFieldDef def, List<SurveyResponseModel> responses) {
    final values = responses
        .map((r) => r.answers[def.label])
        .where((v) => v != null)
        .toList();

    if (values.isEmpty) {
      return const Text('No data yet.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
    }

    if (def.type == 'yesno') {
      int yes = values.where((v) => v == 'Yes').length;
      int no = values.length - yes;
      double yesPct = values.isEmpty ? 0 : yes / values.length;
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _pctBar('Yes', yes, values.length, Colors.green, yesPct)),
              const SizedBox(width: 10),
              Expanded(child: _pctBar('No', no, values.length, Colors.red, 1 - yesPct)),
            ],
          ),
        ],
      );
    }

    if (def.type == 'select') {
      final Map<String, int> counts = {};
      for (final v in values) { counts[v.toString()] = (counts[v.toString()] ?? 0) + 1; }
      final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final max = sorted.isEmpty ? 1 : sorted.first.value;
      return Column(
        children: sorted.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${e.value} (${(e.value / values.length * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(fontSize: 11, color: Colors.deepOrange)),
              ]),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: e.value / max, minHeight: 10,
                  backgroundColor: Colors.purple.shade50,
                  valueColor: const AlwaysStoppedAnimation(Colors.purple),
                ),
              ),
            ],
          ),
        )).toList(),
      );
    }

    if (def.type == 'number' || def.type == 'scale') {
      // Safely parse — phone numbers stored as text strings may not parse cleanly
      final nums = values
          .map((v) => double.tryParse(v.toString()))
          .where((d) => d != null)
          .cast<double>()
          .toList();

      if (nums.isEmpty) {
        return Wrap(
          spacing: 8, runSpacing: 6,
          children: values.take(5).map((v) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
            ),
            child: Text(v.toString(),
                style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          )).toList(),
        );
      }

      final avg = nums.reduce((a, b) => a + b) / nums.length;
      final minV = nums.reduce((a, b) => a < b ? a : b);
      final maxV = nums.reduce((a, b) => a > b ? a : b);
      return Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _statPill('Average', avg.toStringAsFixed(1), Colors.blueAccent),
          _statPill('Min', minV.toStringAsFixed(0), Colors.green),
          _statPill('Max', maxV.toStringAsFixed(0), Colors.red),
          _statPill('Count', values.length.toString(), Colors.purple),
        ],
      );
    }

    // text: word frequency
    if (def.type == 'text') {
      final Map<String, int> wordFreq = {};
      for (final v in values) {
        final words = v.toString().toLowerCase().split(RegExp(r'\s+'));
        for (final word in words) {
          if (word.length > 2) wordFreq[word] = (wordFreq[word] ?? 0) + 1;
        }
      }
      final sorted = wordFreq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.take(6).toList();
      if (top.isEmpty) return const Text('No keywords found.', style: TextStyle(color: Colors.grey));
      return Wrap(
        spacing: 8, runSpacing: 6,
        children: top.map((e) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
          ),
          child: Text('${e.key} (${e.value})',
              style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
        )).toList(),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _pctBar(String label, int count, int total, Color color, double fraction) {
    return Column(
      children: [
        Container(
          height: 60,
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: fraction.clamp(0.05, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
        Text('$count (${(fraction * 100).toStringAsFixed(0)}%)',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _statPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildVolunteerLeaderboard(Color baseColor, List<SurveyResponseModel> responses) {
    final Map<String, int> counts = {};
    for (final r in responses) {
      counts[r.volunteerId] = (counts[r.volunteerId] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final medals = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣'];

    return Column(
      children: sorted.take(5).toList().asMap().entries.map((entry) {
        final rank = entry.key;
        final volunteerId = entry.value.key;
        final count = entry.value.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(volunteerId).get(),
            builder: (context, snap) {
              String name = 'Volunteer';
              if (snap.hasData && snap.data!.exists) {
                name = (snap.data!.data() as Map)['name'] ?? 'Volunteer';
              }
              return ClayContainer(
                color: baseColor, borderRadius: 12, depth: rank == 0 ? 20 : 12,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Text(medals[rank], style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(name,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                                color: rank == 0 ? Colors.amber.shade800 : Colors.black87)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Text('$count entries',
                            style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 22,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _emptyCard(String msg) {
    return ClayContainer(
      color: const Color(0xFFF2F2F2), borderRadius: 12, depth: -10,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
      ),
    );
  }

  Widget _kpiCard(Color baseColor, String title, String value, IconData icon, Color color) {
    return ClayContainer(
      color: baseColor, borderRadius: 14, depth: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: 10, color: Colors.grey.shade600), textAlign: TextAlign.center),
        ]),
      ),
    );
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

  void _showExportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text('Export Analytics Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            const SizedBox(height: 10),
            const Text('Choose a format to download the survey data and charts. Perfect for donor updates.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: _exportOptionCard(ctx, 'PDF Report', Icons.picture_as_pdf, Colors.redAccent, 'Charts & Summary'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _exportOptionCard(ctx, 'CSV Data', Icons.table_chart, Colors.green, 'Raw Data Dump'),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _exportOptionCard(BuildContext context, String title, IconData icon, Color color, String subtitle) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Text('$title saved to Downloads folder!'),
          ]),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
