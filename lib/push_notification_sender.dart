import 'package:cloud_firestore/cloud_firestore.dart';

class PushNotificationSender {
  /// Sends a push notification to all users with a specific role.
  /// If [college] is provided, it only notifies users in that college.
  static Future<void> sendToRole({
    required String role,
    required String title,
    required String body,
    String? college,
    Map<String, dynamic>? data,
  }) async {
    await FirebaseFirestore.instance.collection('push_notifications').add({
      'targetRole': role,
      'targetCollege': college,
      'title': title,
      'body': body,
      'data': data ?? {},
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Sends a push notification to a specific user by their UID.
  static Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await FirebaseFirestore.instance.collection('push_notifications').add({
      'targetUid': userId,
      'title': title,
      'body': body,
      'data': data ?? {},
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Sends a push notification to all students in a college, or all students globally if [isPublic] is true.
  static Future<void> notifyStudents({
    required String title,
    required String body,
    required String college,
    bool isPublic = false,
    Map<String, dynamic>? data,
  }) async {
    await FirebaseFirestore.instance.collection('push_notifications').add({
      'targetRole': 'STUDENT',
      'targetCollege': isPublic ? null : college,
      'title': title,
      'body': body,
      'data': data ?? {},
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
