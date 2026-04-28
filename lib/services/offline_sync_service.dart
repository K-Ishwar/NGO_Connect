import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfflineSyncService {
  static const String _pendingFeedbackBox = 'pending_feedback';
  static const String _cachedTasksBox = 'cached_tasks';

  static Future<void> initHive() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(_pendingFeedbackBox);
    await Hive.openBox<Map>(_cachedTasksBox);
  }

  static Box<Map> get pendingFeedbackBox => Hive.box<Map>(_pendingFeedbackBox);
  static Box<Map> get cachedTasksBox => Hive.box<Map>(_cachedTasksBox);

  /// Returns true if device has internet access
  static Future<bool> isConnected() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }

  /// Listen to connectivity changes (yields true when online)
  static Stream<bool> get connectivityStream {
    return Connectivity().onConnectivityChanged.map((results) {
      return results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);
    });
  }

  /// Save a feedback map locally for later sync
  static Future<void> savePendingFeedback(Map<String, dynamic> feedbackMap) async {
    await pendingFeedbackBox.add(feedbackMap);
  }

  /// Save fetched tasks to local cache
  static Future<void> cacheTasks(List<Map<String, dynamic>> tasks) async {
    await cachedTasksBox.clear();
    for (final task in tasks) {
      await cachedTasksBox.add(task);
    }
  }

  /// Get cached tasks
  static List<Map<String, dynamic>> getCachedTasks() {
    return cachedTasksBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Try to upload all pending offline feedback to Firestore
  static Future<int> syncPendingFeedback() async {
    if (!await isConnected()) return 0;

    final box = pendingFeedbackBox;
    if (box.isEmpty) return 0;

    int synced = 0;
    final keys = box.keys.toList();

    for (final key in keys) {
      final data = box.get(key);
      if (data == null) continue;
      try {
        final Map<String, dynamic> feedbackMap = Map<String, dynamic>.from(data);
        final String taskId = feedbackMap['task_id'] ?? '';
        // Re-convert the timestamp if needed
        if (feedbackMap['date'] is String) {
          feedbackMap['date'] = Timestamp.fromDate(DateTime.parse(feedbackMap['date']));
        }
        await FirebaseFirestore.instance.collection('feedback').add(feedbackMap);
        // Also complete the task (Bug 1 fix)
        if (taskId.isNotEmpty && taskId != 'manual_upload') {
          await FirebaseFirestore.instance
              .collection('tasks')
              .doc(taskId)
              .update({'status': 'completed'});
        }
        await box.delete(key);
        synced++;
      } catch (e) {
        // Skip this one if it fails, try next
      }
    }
    return synced;
  }

  /// Count pending offline items
  static int get pendingCount => pendingFeedbackBox.length;
}
