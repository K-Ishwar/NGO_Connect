import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final Color baseColor = const Color(0xFFF2F2F2);

    if (userId == null) {
      return Scaffold(
        backgroundColor: baseColor,
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.deepPurpleAccent),
        ),
        body: const Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        title: const Text('Alerts Inbox'),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.deepPurpleAccent),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('user_id', whereIn: [userId, 'global_topic'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Error loading notifications. Index might be building.',
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No notifications right now.'));
          }

          final notifications = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aDate = (a.data() as Map)['date'];
              final bDate = (b.data() as Map)['date'];
              if (aDate is Timestamp && bDate is Timestamp) {
                return bDate.compareTo(aDate);
              }
              return 0;
            });

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Alert';
              final body = data['body'] ?? '';
              final dateObj = data['date'];

              String dateString = '';
              if (dateObj is Timestamp) {
                dateString = DateFormat.yMMMd().add_jm().format(
                  dateObj.toDate(),
                );
              }

              final isHighUrgency = title.toString().contains('High Urgency');

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ClayContainer(
                  color: baseColor,
                  borderRadius: 15,
                  depth: 20,
                  curveType: CurveType.concave,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isHighUrgency
                          ? Colors.redAccent
                          : Colors.deepPurpleAccent,
                      child: Icon(
                        isHighUrgency ? Icons.warning : Icons.notifications,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(body),
                        const SizedBox(height: 4),
                        Text(
                          dateString,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
