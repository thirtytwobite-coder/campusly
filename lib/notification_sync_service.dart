import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'push_notification_sender.dart';

/// A service that synchronizes notifications via Firestore for users on the Firebase Spark (Free) plan.
/// This acts as a "Push Notification" alternative by listening to a central collection.
class NotificationSyncService {
  static StreamSubscription<QuerySnapshot>? _subscription;
  static final Set<String> _handledIds = {};

  /// Starts listening for notifications targeting the current user or their role.
  static void startListening() {
    _subscription?.cancel();
    _handledIds.clear();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Start listening immediately
    _startFilteredListener(user.uid);
  }

  static void _startFilteredListener(String userId) async {
    // 🔹 Fetch from consolidated 'users' collection instead of 'student'
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      debugPrint("⚠️ NotificationSync: User document not found in /users/$userId");
      return;
    }

    final role = (userDoc.data()?['role']?.toString() ?? '').toUpperCase();
    final college = (userDoc.data()?['college']?.toString() ?? '').toUpperCase();

    debugPrint("🔔 NotificationSync: Starting optimized listener for $role @ $college");
    final String myCollege = college;

    // We fetch the last 20 notifications by order, NOT by value.
    _subscription = FirebaseFirestore.instance
        .collection('push_notifications')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final data = change.doc.data();
          if (data == null || data['status'] != 'pending') continue;

          final String docId = change.doc.id;
          if (_handledIds.contains(docId)) continue;

          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          if (createdAt != null &&
              createdAt.isBefore(DateTime.now().subtract(const Duration(minutes: 15)))) {
            continue;
          }

          bool forMe = false;
          final String targetUid = data['targetUid']?.toString() ?? '';
          final String targetRole = (data['targetRole']?.toString() ?? '').toUpperCase();
          final String targetCollege = (data['targetCollege']?.toString() ?? '').toUpperCase();

          if (targetUid == userId) {
            forMe = true;
          } else if (targetRole == role) {
            // Role-based notification: Must match college if specified
            if (targetCollege.isEmpty || targetCollege == myCollege) {
              forMe = true;
            }
          }

          if (forMe) {
            _handledIds.add(docId);
            final String channelId = data['channelId']?.toString() ?? NotificationService.infoChannelId;
            
            NotificationService.showNotification(
              id: docId.hashCode,
              title: data['title'] ?? 'New Notification',
              body: data['body'] ?? '',
              payload: data['data']?['screen'] ?? '',
              channelId: channelId,
            );

            if (targetUid == userId) {
              change.doc.reference.update({'status': 'delivered'});
            }
          }
        }
      }
    });
  }

  /// Stops the listener.
  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _handledIds.clear();
  }

  /// Static helper to send a notification (writes to Firestore message bus).
  static Future<void> sendNotification({
    String? targetUid,
    String? targetRole,
    String? targetCollege,
    String? channelId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await FirebaseFirestore.instance.collection('push_notifications').add({
      'targetUid': targetUid,
      'targetRole': targetRole?.toUpperCase(),
      'targetCollege': targetCollege,
      'channelId': channelId ?? NotificationService.infoChannelId,
      'title': title,
      'body': body,
      'data': data ?? {},
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 🚀 NEW: Trigger True Push Notification (FCM) for "App Closed" support
    if (targetUid != null) {
      PushNotificationSender.sendToUser(
        userId: targetUid,
        title: title,
        body: body,
        data: data,
      );
    } else if (targetRole != null) {
      PushNotificationSender.sendToRole(
        role: targetRole,
        college: targetCollege,
        title: title,
        body: body,
        data: data,
      );
    }
  }
}
