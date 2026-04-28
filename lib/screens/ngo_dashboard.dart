import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'add_survey_screen.dart';
import 'survey_detail_screen.dart';
import 'survey_analytics_screen.dart';
import 'heatmap_screen.dart';
import 'ai_insights_screen.dart';
import '../models/survey_model.dart';
import '../models/camp_model.dart';
import '../services/camp_service.dart';
import 'camp_detail_screen.dart';
import 'community_hub_screen.dart';
import 'register_volunteer_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';
import 'feedback_history_screen.dart';

import 'package:fl_chart/fl_chart.dart';

class NgoDashboard extends StatefulWidget {
  const NgoDashboard({super.key});

  @override
  State<NgoDashboard> createState() => _NgoDashboardState();
}

class _NgoDashboardState extends State<NgoDashboard> {
  final Color baseColor = const Color(0xFFF2F2F2);
  String? _selectedProblemType;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A0DAD), Color(0xFF8A2387), Color(0xFFE94057)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x44E94057),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Logo + Title
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('NGO Connect',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          )),
                      Text('Dashboard & Analytics',
                          style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                  const Spacer(),


                  // Profile avatar button
                  GestureDetector(
                    onTap: () async {
                      final user = await AuthService().getUserDetails(uid);
                      if (user != null && context.mounted) {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => ProfileScreen(userModel: user)));
                      }
                    },
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Logout
                  GestureDetector(
                    onTap: () async => await AuthService().logout(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.logout, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Logout', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      backgroundColor: baseColor,
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuickActionsVerticalSidebar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildVolunteerAndTasksRow(),
                        const SizedBox(height: 24),
                        _buildSurveysAnalytics(),
                        const SizedBox(height: 16),
                        _buildCampsSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddSurveyScreen()),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8A2387), Color(0xFFE94057)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE94057).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'New Survey',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Frosted glass icon button for app bar
  Widget _appBarAction(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: color.withOpacity(0.2),
          highlightColor: color.withOpacity(0.1),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.7), color],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsVerticalSidebar(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    // Keep sidebar compact: 80px max on any phone
    final sidebarW = screenW < 600 ? 82.0 : 120.0;
    final iconSize = 20.0;
    final fontSize = 9.0;

    return SizedBox(
      width: sidebarW,
      child: Padding(
        padding: EdgeInsets.only(left: screenW < 380 ? 8 : 12, top: 16, bottom: 16, right: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 12),
              child: Row(
                children: [
                  Container(width: 3, height: 18,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('⚡ Actions', style: TextStyle(
                    fontSize: fontSize + 1, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                children: [
                  _buildCompactActionCard(context, 'Community\nHub', Icons.public, const Color(0xFF8A2387), iconSize, fontSize,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityHubScreen()))),
                  _buildCompactActionCard(context, 'Register\nVolunteer', Icons.person_add_alt_1, Colors.deepOrange, iconSize, fontSize,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterVolunteerScreen()))),
                  _buildCompactActionCard(context, 'Live\nHeatmap', Icons.map_outlined, Colors.red, iconSize, fontSize,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeatmapScreen()))),
                  _buildCompactActionCard(context, 'AI\nInsights', Icons.psychology, Colors.purple, iconSize, fontSize,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiInsightsScreen()))),
                  _buildCompactActionCard(context, 'Feedback\nHistory', Icons.history, Colors.blue, iconSize, fontSize,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackHistoryScreen()))),
                  _buildCompactActionCard(context, 'Push\nAlerts', Icons.notifications_outlined, Colors.teal, iconSize, fontSize,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactActionCard(BuildContext context, String title, IconData icon, Color color,
      double iconSize, double fontSize, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25), width: 1.2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: color.withOpacity(0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(iconSize < 22 ? 8 : 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color.withOpacity(0.8), color]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))],
                  ),
                  child: Icon(icon, color: Colors.white, size: iconSize),
                ),
                const SizedBox(height: 7),
                Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.grey.shade800, height: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Row for top-level stats
  Widget _buildVolunteerAndTasksRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('tasks').snapshots(),
      builder: (context, taskSnap) {
        int completedTasks = 0;
        int totalTasks = 0;
        if (taskSnap.hasData) {
          totalTasks = taskSnap.data!.docs.length;
          completedTasks = taskSnap.data!.docs
              .where((d) => (d.data() as Map)['status'] == 'completed')
              .length;
        }
        final completionPct = totalTasks > 0
            ? '${((completedTasks / totalTasks) * 100).toStringAsFixed(0)}%'
            : '—';

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('feedback').snapshots(),
          builder: (context, feedbackSnap) {
            int totalPeopleHelped = 0;
            if (feedbackSnap.hasData) {
              for (final doc in feedbackSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                totalPeopleHelped += (data['people_helped'] as int? ?? 0);
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'volunteer')
                  .snapshots(),
              builder: (context, volSnap) {
                int volunteerCount = volSnap.hasData ? volSnap.data!.docs.length : 0;

                return Column(
                  children: [
                    // Mega impact banner
                    ClayContainer(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: 20,
                      depth: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.favorite, color: Colors.white, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    totalPeopleHelped.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      height: 1.0,
                                    ),
                                  ),
                                  const Text(
                                    'Total People Helped',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 3 summary cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            title: 'Volunteers',
                            value: volunteerCount.toString(),
                            icon: Icons.group,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            title: 'Tasks Done',
                            value: '$completedTasks/$totalTasks',
                            icon: Icons.task_alt,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            title: 'Completion\nRate',
                            value: completionPct,
                            icon: Icons.trending_up,
                            color: Colors.deepPurpleAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // Large integrated StreamBuilder for all Survey Analytics
  Widget _buildSurveysAnalytics() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('surveys')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [const Color(0xFF8A2387).withOpacity(0.1), const Color(0xFFE94057).withOpacity(0.1)]),
                    ),
                    child: const Icon(Icons.analytics_outlined, size: 70, color: Color(0xFF8A2387)),
                  ),
                  const SizedBox(height: 24),
                  const Text('No Surveys Yet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  const SizedBox(height: 12),
                  const Text('Start by creating a new survey to collect data and get AI-powered recommendations.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8A2387),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: const Color(0xFF8A2387).withOpacity(0.5),
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSurveyScreen())),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Create your first survey', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        }

        // 5. Total Activities
        final totalActivities = docs.length;

        // Aggregations
        int highPriorityCount = 0;
        Map<String, int> areaPeopleMap = {};
        Map<String, int> problemTypeMap = {};
        List<Map<String, dynamic>> crossNgoEvents = [];

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id_doc'] = doc.id;

          crossNgoEvents.add(data); // 4. Cross NGO events

          final urgency = data['urgency'] ?? 'Low';
          if (urgency == 'High') highPriorityCount++; // 1. High Priority Needs

          final area = data['area'] ?? 'Unknown';
          final peopleCount = (data['people_count'] ?? 0) as int;
          areaPeopleMap[area] =
              (areaPeopleMap[area] ?? 0) + peopleCount; // 2. Area-wise Needs

          final problemType = data['problem_type'] ?? 'Other';
          problemTypeMap[problemType] =
              (problemTypeMap[problemType] ?? 0) +
              1; // 3. Problem Type Distribution
        }

        // 8. Most Affected Areas (Top 3 areas with highest people_count)
        var sortedAreas = areaPeopleMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top3Areas = sortedAreas.take(3).toList();

        final mySurveys = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['ngo_id'] == FirebaseAuth.instance.currentUser?.uid;
        }).toList();

        if (_selectedProblemType != null) {
          crossNgoEvents = crossNgoEvents.where((e) => e['problem_type'] == _selectedProblemType).toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Total\nActivities',
                    value: totalActivities.toString(),
                    icon: Icons.local_activity,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'High Priority\nNeeds',
                    value: highPriorityCount.toString(),
                    icon: Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildSectionTitle('Problem Type Distribution'),
            if (_selectedProblemType != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Filtered by: $_selectedProblemType (Tap chart to clear)', style: const TextStyle(color: Color(0xFF8A2387), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            _buildProblemTypeChart(problemTypeMap, totalActivities),
            const SizedBox(height: 16),

            _buildSectionTitle('Top 3 Most Affected Areas'),
            _buildTopAreasWidget(top3Areas),
            const SizedBox(height: 16),

            _buildSectionTitle('My Surveys (Tap for Analytics)'),
            _buildMySurveysWidget(
              _selectedProblemType == null 
                ? mySurveys 
                : mySurveys.where((d) => (d.data() as Map<String, dynamic>)['problem_type'] == _selectedProblemType).toList()
            ),
            const SizedBox(height: 16),

            _buildSectionTitle('Area-wise Needs (Total People)'),
            _buildAreaWiseNeedsWidget(sortedAreas),
            const SizedBox(height: 16),

            _buildSectionTitle('Cross NGO Events (Recent Surveys)'),
            _buildCrossNgoEventsWidget(crossNgoEvents),
            const SizedBox(height: 80), // Padding for FAB
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 15,
        depth: 20,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ClayContainer(
                color: baseColor,
                borderRadius: 20,
                depth: 10,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Icon(icon, size: 28, color: color),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 8.0, top: 16.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemTypeChart(
    Map<String, int> problemTypeMap,
    int totalActivities,
  ) {
    if (problemTypeMap.isEmpty) {
      problemTypeMap = {
        'Food (Demo)': 45,
        'Medical (Demo)': 30,
        'Shelter (Demo)': 25,
      };
      totalActivities = 100;
    }
    
    final List<Color> colors = [
      Colors.deepPurple, Colors.orange, Colors.redAccent, 
      Colors.green, Colors.blueAccent, Colors.pink, Colors.teal
    ];
    int idx = 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 15,
        depth: 20,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                            return;
                          }
                          final touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          if (touchedIndex >= 0 && touchedIndex < problemTypeMap.length) {
                            final key = problemTypeMap.keys.elementAt(touchedIndex);
                            setState(() {
                              if (_selectedProblemType == key) {
                                _selectedProblemType = null;
                              } else {
                                _selectedProblemType = key;
                              }
                            });
                          }
                        },
                      ),
                      sectionsSpace: 2,
                      centerSpaceRadius: 35,
                      sections: problemTypeMap.entries.map((e) {
                        final isTouched = _selectedProblemType == e.key;
                        final radius = isTouched ? 50.0 : 40.0;
                        final color = colors[(problemTypeMap.keys.toList().indexOf(e.key)) % colors.length];
                        return PieChartSectionData(
                          color: color,
                          value: e.value.toDouble(),
                          title: '${e.value}',
                          radius: radius,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: problemTypeMap.entries.map((e) {
                        final isTouched = _selectedProblemType == e.key;
                        final color = colors[(problemTypeMap.keys.toList().indexOf(e.key)) % colors.length];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(e.key, style: TextStyle(fontSize: 11, fontWeight: isTouched ? FontWeight.bold : FontWeight.normal))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopAreasWidget(List<MapEntry<String, int>> top3Areas) {
    if (top3Areas.isEmpty) {
      top3Areas = [
        const MapEntry('Downtown (Demo)', 120),
        const MapEntry('Westside (Demo)', 85),
        const MapEntry('North End (Demo)', 40),
      ];
    }
    return Row(
      children: top3Areas
          .map(
            (e) => Expanded(
              child: ClayContainer(
                color: baseColor,
                borderRadius: 14,
                depth: 12,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                  child: Column(
                    children: [
                      Icon(Icons.location_city, color: Colors.red.shade400, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        e.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${e.value} affected',
                          style: TextStyle(color: Colors.red.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAreaWiseNeedsWidget(List<MapEntry<String, int>> sortedAreas) {
    if (sortedAreas.isEmpty) {
      sortedAreas = [
        const MapEntry('Downtown (Demo)', 120),
        const MapEntry('Westside (Demo)', 85),
        const MapEntry('North End (Demo)', 40),
        const MapEntry('Eastside (Demo)', 15),
      ];
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 15,
        depth: 20,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedAreas.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Colors.black12),
          itemBuilder: (context, index) {
            return ListTile(
              leading: const Icon(Icons.location_on, color: Colors.deepPurple),
              title: Text(sortedAreas[index].key, style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${sortedAreas[index].value} affected',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 12),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMySurveysWidget(List<QueryDocumentSnapshot> mySurveys) {
    if (mySurveys.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: ClayContainer(
          color: baseColor, borderRadius: 15, depth: 20,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF8A2387).withOpacity(0.1), const Color(0xFFE94057).withOpacity(0.08)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.assignment_outlined, size: 48, color: Color(0xFF8A2387)),
                ),
                const SizedBox(height: 16),
                const Text('No Surveys Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const SizedBox(height: 8),
                const Text('Create your first survey to start collecting insights from your area.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 15,
        depth: 20,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: mySurveys.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.black12),
          itemBuilder: (context, index) {
            final doc = mySurveys[index];
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              leading: const Icon(Icons.analytics, color: Colors.deepPurple),
              title: Text('${data['problem_type']} in ${data['area']}'),
              subtitle: Text(
                'Created: ${(data['date'] as Timestamp).toDate().toString().split(' ')[0]}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final surveyModel = SurveyModel.fromMap(data, doc.id);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SurveyAnalyticsScreen(survey: surveyModel),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCrossNgoEventsWidget(List<Map<String, dynamic>> crossNgoEvents) {
    if (crossNgoEvents.isEmpty) {
      crossNgoEvents = [
        {
          'problem_type': 'Medical Supplies',
          'area': 'Downtown (Demo)',
          'description': 'Emergency medical camp setup for 120 people.',
          'urgency': 'High',
          'date': Timestamp.now(),
        },
        {
          'problem_type': 'Food Distribution',
          'area': 'Westside (Demo)',
          'description': 'Distributing 85 food packets to local shelters.',
          'urgency': 'Medium',
          'date': Timestamp.now(),
        }
      ];
    }
    // Show top 10 recent events to avoid unlimited list
    final displayEvents = crossNgoEvents.take(10).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 15,
        depth: 20,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayEvents.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Colors.black12),
          itemBuilder: (context, index) {
            final event = displayEvents[index];
            return ListTile(
              leading: const Icon(Icons.event_note, color: Colors.blueGrey),
              title: Text('${event['problem_type']} in ${event['area']}'),
              subtitle: Text(
                event['description'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: _buildUrgencyBadge(event['urgency'] ?? 'Low'),
              onTap: () {
                SurveyModel sModel = SurveyModel(
                  id: event['id_doc'] ?? '',
                  ngoId: event['ngo_id'] ?? '',
                  area: event['area'] ?? '',
                  problemType: event['problem_type'] ?? '',
                  peopleCount: event['people_count'] ?? 0,
                  urgency: event['urgency'] ?? '',
                  description: event['description'] ?? '',
                  date: (event['date'] as Timestamp).toDate(),
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SurveyDetailScreen(survey: sModel),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildUrgencyBadge(String urgency) {
    Color color;
    switch (urgency) {
      case 'High':
        color = Colors.red;
        break;
      case 'Medium':
        color = Colors.orange;
        break;
      default:
        color = Colors.green;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        urgency,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  // ── Camps Section ──────────────────────────────────────────────────────────
  Widget _buildCampsSection() {
    final ngoId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 4, height: 22,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF5F72BD), Color(0xFF8A2387)]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('🏕️ Camps & Events',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ),
            const Text('AI-planned', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 12),

        StreamBuilder<List<CampModel>>(
          stream: CampService().streamCampsForNgo(ngoId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final camps = snap.data ?? [];
            if (camps.isEmpty) {
              return ClayContainer(
                color: baseColor, borderRadius: 16, depth: 20,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF5F72BD).withOpacity(0.12), const Color(0xFF8A2387).withOpacity(0.08)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.festival_outlined, size: 48, color: Color(0xFF5F72BD)),
                      ),
                      const SizedBox(height: 16),
                      const Text('No Camps Created Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      const SizedBox(height: 8),
                      const Text(
                        'Go to a Survey → View Analytics → "Get AI Camp Recommendation" to plan your first event!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: camps.map((camp) {
                final Color statusColor;
                switch (camp.status) {
                  case 'active': statusColor = Colors.green; break;
                  case 'completed': statusColor = Colors.blue; break;
                  default: statusColor = Colors.orange;
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => CampDetailScreen(camp: camp))),
                    child: ClayContainer(
                      color: baseColor, borderRadius: 14, depth: 18,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF5F72BD), Color(0xFF8A2387)],
                                ),
                              ),
                              child: const Icon(Icons.local_hospital, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(camp.campName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('${camp.campType}  •  📍 ${camp.location.isNotEmpty ? camp.location : camp.area}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(
                                    '📅 ${camp.scheduledDate.day}/${camp.scheduledDate.month}/${camp.scheduledDate.year}  •  👥 ${camp.volunteersRequired} volunteers needed',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: statusColor.withOpacity(0.4)),
                              ),
                              child: Text(camp.status.toUpperCase(),
                                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
