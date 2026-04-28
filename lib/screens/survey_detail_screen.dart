import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/survey_model.dart';
import '../services/task_service.dart';

class SurveyDetailScreen extends StatefulWidget {
  final SurveyModel survey;

  const SurveyDetailScreen({super.key, required this.survey});

  @override
  State<SurveyDetailScreen> createState() => _SurveyDetailScreenState();
}

class _SurveyDetailScreenState extends State<SurveyDetailScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TaskService _taskService = TaskService();
  final Color baseColor = const Color(0xFFF2F2F2);

  void _manualAssign(String volunteerId, String volunteerName) async {
    final success = await _taskService.acceptTask(
      surveyId: widget.survey.id!,
      volunteerId: volunteerId,
      assignedBy: 'manual',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Assigned to $volunteerName manually.'
                : 'Failed to assign.',
          ),
        ),
      );
    }
  }

  void _autoAssign() async {
    final result = await _taskService.autoAssign(widget.survey);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  void _notifyViaWhatsApp(String? phone, String volunteerName) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number registered for this volunteer.'),
        ),
      );
      return;
    }

    // Clean phone — keep only digits
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Add India country code if needed (10-digit numbers = India mobile)
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    } else if (cleanPhone.length == 11 && cleanPhone.startsWith('0')) {
      cleanPhone = '91${cleanPhone.substring(1)}'; // Strip leading 0
    }
    // If already starts with 91 and is 12 digits, leave as-is

    final message = Uri.encodeComponent(
      '🚨 NGO Connect Task Alert — ${widget.survey.problemType} in ${widget.survey.area}.\n'
      '${widget.survey.peopleCount} people are affected. Urgency: ${widget.survey.urgency}.\n\n'
      'Please open NGO Connect to view and accept this task.',
    );

    // Try direct whatsapp:// scheme first (faster, opens WhatsApp directly)
    final directUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$message');
    // Fallback: web link
    final webUri = Uri.parse('https://wa.me/$cleanPhone?text=$message');

    if (await canLaunchUrl(directUri)) {
      await launchUrl(directUri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('WhatsApp not installed. Phone: +$cleanPhone'),
            action: SnackBarAction(
              label: 'Copy',
              onPressed: () {
                // Could copy to clipboard
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isOwner = currentUser?.uid == widget.survey.ngoId;

    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        title: const Text('Survey Settings'),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.deepPurpleAccent),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClayContainer(
              color: baseColor,
              borderRadius: 20,
              depth: 30,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Type: ${widget.survey.problemType}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Area: ${widget.survey.area}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text('Affected: ${widget.survey.peopleCount} individuals'),
                    const SizedBox(height: 4),
                    Text(
                      'Urgency: ${widget.survey.urgency}',
                      style: TextStyle(
                        color: widget.survey.urgency == 'High'
                            ? Colors.red
                            : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(color: Colors.black12),
                    ),
                    Text(widget.survey.description),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (isOwner) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Volunteer Assignments',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _autoAssign,
                    child: ClayContainer(
                      color: Colors.deepPurpleAccent,
                      borderRadius: 10,
                      depth: 15,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Auto Assign',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Manually Assign Volunteer:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildVolunteerList(),
            ],
            const SizedBox(height: 24),
            const Text(
              'Assigned Volunteers:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            _buildAssignedTaskRoster(),
          ],
        ),
      ),
    );
  }

  Widget _buildVolunteerList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'volunteer')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final volunteers = snapshot.data!.docs;

        return SizedBox(
          height: 200,
          child: ClayContainer(
            color: baseColor,
            borderRadius: 15,
            depth: -20,
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: volunteers.length,
              itemBuilder: (context, index) {
                final volId = volunteers[index].id;
                final data = volunteers[index].data() as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ClayContainer(
                    color: baseColor,
                    borderRadius: 10,
                    depth: 10,
                    child: ListTile(
                      title: Text(
                        data['name'] ?? 'Volunteer',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Builder(builder: (ctx) {
                          // Handle skills stored as List<String> or String
                          final rawSkills = data['skills'];
                          String skillsDisplay = '';
                          if (rawSkills is List) {
                            skillsDisplay = rawSkills.join(', ');
                          } else if (rawSkills is String) {
                            skillsDisplay = rawSkills;
                          }
                          return Text(
                            '${skillsDisplay.isEmpty ? "No skills listed" : skillsDisplay}\nLoc: ${data['location'] ?? "–"}',
                          );
                        }),
                      isThreeLine: true,
                      trailing: ClayContainer(
                        color: Colors.white,
                        borderRadius: 10,
                        depth: 10,
                        child: InkWell(
                          onTap: () => _manualAssign(volId, data['name']),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              'Assign',
                              style: TextStyle(
                                color: Colors.deepPurple,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssignedTaskRoster() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('survey_id', isEqualTo: widget.survey.id)
          .snapshots(),
      builder: (context, taskSnapshot) {
        if (!taskSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tasks = taskSnapshot.data!.docs;
        if (tasks.isEmpty) {
          return const Text(
            'No volunteers assigned yet.',
            style: TextStyle(fontStyle: FontStyle.italic),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final taskData = tasks[index].data() as Map<String, dynamic>;
            final volunteerId = taskData['volunteer_id'];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(volunteerId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const ListTile(title: Text('Loading volunteer...'));
                }
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox();

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: ClayContainer(
                    color: baseColor,
                    borderRadius: 15,
                    depth: 20,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(
                              Icons.volunteer_activism,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userData['name'] ?? 'Unknown Volunteer',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${userData['email']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                Text(
                                  'Assigned by: ${taskData['assigned_by']}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _notifyViaWhatsApp(
                              userData['phone_number'],
                              userData['name'] ?? '',
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chat,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'WhatsApp',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
