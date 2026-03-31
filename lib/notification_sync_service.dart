/// Service for synchronizing notifications between Firestore and local notifications.
/// This class listens to the notifications collection in Firestore for unread notifications
/// addressed to the current user and displays them as local notifications.
/// It also provides methods to send notifications to specific users, roles, or colleges.
/// The service handles marking notifications as read and supports different notification types.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class NotificationSyncService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> startListening() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen to notifications collection for current user
    FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientEmail', isEqualTo: user.email)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _showNotification(
          title: data['title'] ?? 'Notification',
          body: data['body'] ?? '',
          type: data['type'] ?? 'info',
        );
        // Mark as read
        doc.reference.update({'isRead': true});
      }
    });
  }

  static Future<void> sendNotification({
    String? targetRole,
    String? targetCollege,
    String? targetUid,
    String? channelId,
    required String title,
    required String body,
    Map<String, String>? data,
    String? relatedId,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // If targeting a specific user by UID
      if (targetUid != null) {
        final userDoc = await firestore.collection('student').doc(targetUid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          final userEmail = userData?['email'];
          if (userEmail != null) {
            await firestore.collection('notifications').add({
              'recipientEmail': userEmail,
              'title': title,
              'body': body,
              'type': data?['type'] ?? 'info',
              'data': data,
              'relatedId': relatedId,
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            });
          }
        }
        return;
      }

      // If targeting by role (FACULTY or STUDENT)
      if (targetRole != null) {
        QuerySnapshot snapshot;
        
        if (targetRole == 'FACULTY') {
          snapshot = await firestore
              .collection('faculty')
              .get();
        } else if (targetRole == 'STUDENT') {
          if (targetCollege != null && targetCollege.isNotEmpty) {
            snapshot = await firestore
                .collection('student')
                .where('college', isEqualTo: targetCollege)
                .get();
          } else {
            snapshot = await firestore
                .collection('student')
                .get();
          }
        } else {
          return;
        }

        final batch = firestore.batch();
        int batchCount = 0;
        
        for (var doc in snapshot.docs) {
          final userData = doc.data() as Map<String, dynamic>?;
          final email = userData?['email'];
          if (email != null) {
            batch.set(firestore.collection('notifications').doc(), {
              'recipientEmail': email,
              'title': title,
              'body': body,
              'type': data?['type'] ?? 'info',
              'data': data,
              'relatedId': relatedId,
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            });
            batchCount++;
            
            // Firestore batch has a limit of 500 operations
            if (batchCount >= 500) {
              await batch.commit();
              batchCount = 0;
            }
          }
        }
        
        if (batchCount > 0) {
          await batch.commit();
        }
        return;
      }

      // Fallback: send to all students
      final allUsers = await firestore.collection('student').get();
      final batch = firestore.batch();
      int batchCount = 0;
      
      for (var doc in allUsers.docs) {
        final userData = doc.data() as Map<String, dynamic>?;
        final email = userData?['email'];
        if (email != null) {
          batch.set(firestore.collection('notifications').doc(), {
            'recipientEmail': email,
            'title': title,
            'body': body,
            'type': data?['type'] ?? 'info',
            'data': data,
            'relatedId': relatedId,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
          batchCount++;
          
          if (batchCount >= 500) {
            await batch.commit();
            batchCount = 0;
          }
        }
      }
      
      if (batchCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  static Future<void> _showNotification({
    required String title,
    required String body,
    String type = 'info',
  }) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'campusly_channel',
        'Campusly Notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _notificationsPlugin.show(
        DateTime.now().hashCode,
        title,
        body,
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }
}
