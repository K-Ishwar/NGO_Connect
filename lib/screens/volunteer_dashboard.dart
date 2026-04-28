import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/task_service.dart';
import 'feedback_screen.dart';
import 'survey_response_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import '../models/user_model.dart';
import '../models/survey_model.dart';

class VolunteerDashboard extends StatefulWidget {
  const VolunteerDashboard({super.key});

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TaskService _taskService = TaskService();
  final Color baseColor = const Color(0xFFF2F2F2);
  UserModel? _userModel;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (currentUser != null) {
      final userModel = await AuthService().getUserDetails(currentUser!.uid);
      if (mounted) {
        setState(() {
          _userModel = userModel;
        });
      }
    }
  }

  int _calculateMatchScore(Map<String, dynamic> surveyData) {
    if (_userModel == null) return 0;
    int score = 0;
    
    final surveyArea = (surveyData['area'] ?? '').toString().toLowerCase();
    final userLocation = (_userModel!.location ?? '').toString().toLowerCase();
    if (surveyArea.isNotEmpty && userLocation.isNotEmpty && (surveyArea.contains(userLocation) || userLocation.contains(surveyArea))) {
      score += 50;
    }
    
    final surveyProblem = (surveyData['problem_type'] ?? '').toString().toLowerCase();
    final userSkills = (_userModel!.skills ?? '').toString().toLowerCase();
    if (surveyProblem.isNotEmpty && userSkills.isNotEmpty && (userSkills.contains(surveyProblem) || surveyProblem.contains(userSkills))) {
      score += 50;
    }
    
    return score;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        title: const Text('Volunteer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            ),
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                final user = await AuthService().getUserDetails(uid);
                if (user != null && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userModel: user),
                    ),
                  );
                }
              }
            },
            tooltip: 'Profile',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().logout();
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: currentUser == null
          ? const Center(child: Text("Not logged in."))
          : Container(
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
              child: _buildDashboardContent(),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
        ],
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

  Widget _buildDashboardContent() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Your Assigned Tasks'),
              Expanded(flex: 1, child: _buildAssignedTasks()),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              _buildSectionTitle('Available Tasks (Surveys)'),
              Expanded(flex: 2, child: _buildAvailableSurveys()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignedTasks() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('volunteer_id', isEqualTo: currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final assignedTasks = snapshot.data!.docs;
        if (assignedTasks.isEmpty) {
          return ListView.builder(
            itemCount: 1,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: ClayContainer(
                  color: baseColor,
                  borderRadius: 15,
                  depth: 20,
                  child: ListTile(
                    leading: const Icon(Icons.pending_actions, color: Colors.orange),
                    title: const Text('Survey ID: DEMO_TASK_123'),
                    subtitle: const Text('Status: assigned (Demo)'),
                    trailing: ClayContainer(
                      color: baseColor,
                      borderRadius: 10,
                      depth: 20,
                      child: InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo task cannot be completed.')));
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          child: Text('Complete', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }

        return ListView.builder(
          itemCount: assignedTasks.length,
          itemBuilder: (context, index) {
            final taskData = assignedTasks[index].data() as Map<String, dynamic>;
            final taskId = assignedTasks[index].id;
            final isCompleted = taskData['status'] == 'completed';
            final surveyId = taskData['survey_id'] ?? '';

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('surveys').doc(surveyId).get(),
              builder: (context, surveySnap) {
                String taskTitle = 'Loading...';
                String taskSubtitle = 'Status: ${taskData['status']}';
                if (surveySnap.hasData && surveySnap.data!.exists) {
                  final sd = surveySnap.data!.data() as Map<String, dynamic>;
                  taskTitle = '${sd['problem_type'] ?? ''} in ${sd['area'] ?? ''}';
                  taskSubtitle = 'Urgency: ${sd['urgency'] ?? ''} • ${sd['people_count'] ?? 0} people • ${taskData['status']}';
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: ClayContainer(
                    color: baseColor,
                    borderRadius: 15,
                    depth: 20,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCompleted ? Colors.green.shade100 : Colors.orange.shade100,
                        child: Icon(
                          isCompleted ? Icons.check_circle : Icons.pending_actions,
                          color: isCompleted ? Colors.green : Colors.orange,
                        ),
                      ),
                      title: Text(taskTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(taskSubtitle, style: const TextStyle(fontSize: 12)),
                      trailing: isCompleted
                          ? null
                          : ClayContainer(
                              color: baseColor,
                              borderRadius: 10,
                              depth: 20,
                              child: InkWell(
                                onTap: () {
                                  if (surveySnap.hasData && surveySnap.data!.exists) {
                                    final sd = surveySnap.data!.data() as Map<String, dynamic>;
                                    final survey = SurveyModel.fromMap(sd, surveyId);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SurveyResponseScreen(
                                          survey: survey,
                                          taskId: taskId,
                                        ),
                                      ),
                                    );
                                  } else {
                                    // Fallback to old FeedbackScreen if survey not found
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FeedbackScreen(
                                          taskId: taskId,
                                          surveyId: surveyId,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                  child: Text(
                                    'Start Survey',
                                    style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAvailableSurveys() {
    // We fetch logic inside logic.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('surveys').snapshots(),
      builder: (context, surveySnapshot) {
        if (!surveySnapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final surveys = surveySnapshot.data!.docs;
        if (surveys.isEmpty) {
          return ListView.builder(
            itemCount: 2,
            itemBuilder: (context, index) {
              final demoSurveys = [
                {'problem_type': 'Medical Relief', 'area': 'North Region (Demo)', 'urgency': 'High'},
                {'problem_type': 'Food Supply', 'area': 'Eastside (Demo)', 'urgency': 'Medium'}
              ];
              final data = demoSurveys[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: ClayContainer(
                  color: baseColor,
                  borderRadius: 15,
                  depth: 20,
                  child: ListTile(
                    title: Text('${data['problem_type']} in ${data['area']}'),
                    subtitle: Text('Urgency: ${data['urgency']}'),
                    trailing: ClayContainer(
                      color: Colors.deepPurpleAccent,
                      borderRadius: 10,
                      depth: 20,
                      child: InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo survey cannot be accepted.')));
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          child: Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }

        // Concurrent fetching of user's Tasks to disable accepted surveys
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tasks')
              .where('volunteer_id', isEqualTo: currentUser!.uid)
              .snapshots(),
          builder: (context, taskSnapshot) {
            if (!taskSnapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            final myTasks = taskSnapshot.data!.docs;
            final mySurveyIds = myTasks
                .map((t) => (t.data() as Map<String, dynamic>)['survey_id'])
                .toSet();

            final sortedSurveys = surveys.toList();
            sortedSurveys.sort((a, b) {
               int scoreA = _calculateMatchScore(a.data() as Map<String, dynamic>);
               int scoreB = _calculateMatchScore(b.data() as Map<String, dynamic>);
               return scoreB.compareTo(scoreA); // Highest first
            });

            return ListView.builder(
              itemCount: sortedSurveys.length,
              itemBuilder: (context, index) {
                final surveyDoc = sortedSurveys[index];
                final surveyId = surveyDoc.id;
                final data = surveyDoc.data() as Map<String, dynamic>;

                final isAccepted = mySurveyIds.contains(surveyId);
                final matchScore = _calculateMatchScore(data);

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 4.0,
                  ),
                  child: ClayContainer(
                    color: baseColor,
                    borderRadius: 15,
                    depth: 20,
                    child: ListTile(
                      title: Row(
                        children: [
                          Expanded(child: Text('${data['problem_type']} in ${data['area']}')),
                          if (matchScore > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: matchScore == 100 ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$matchScore% Match',
                                style: TextStyle(
                                  color: matchScore == 100 ? Colors.green : Colors.orange.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            )
                        ],
                      ),
                      subtitle: Text('Urgency: ${data['urgency']}'),
                      trailing: isAccepted
                          ? const Text(
                              'Accepted',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : ClayContainer(
                              color: Colors.deepPurpleAccent,
                              borderRadius: 10,
                              depth: 20,
                              child: InkWell(
                                onTap: () async {
                                  final success = await _taskService.acceptTask(
                                    surveyId: surveyId,
                                    volunteerId: currentUser!.uid,
                                  );
                                  if (success && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Task Accepted!'),
                                      ),
                                    );
                                  }
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                    vertical: 8.0,
                                  ),
                                  child: Text(
                                    'Accept',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
