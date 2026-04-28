import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String? id;
  final String title;
  final String body;
  final String userId;
  final DateTime date;
  final bool readStatus;

  NotificationModel({
    this.id,
    required this.title,
    required this.body,
    required this.userId,
    required this.date,
    this.readStatus = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'user_id': userId,
      'date': Timestamp.fromDate(date),
      'read_status': readStatus,
    };
  }

  factory NotificationModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return NotificationModel(
      id: documentId,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      userId: map['user_id'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      readStatus: map['read_status'] ?? false,
    );
  }
}
