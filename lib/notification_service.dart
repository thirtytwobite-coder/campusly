import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_details.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Call this once during app startup.  If [navigatorKey] is provided
  /// tap callbacks will use it to push an [EventDetailsScreen] when the
  /// payload contains an event id.
  static Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (navigatorKey != null && payload != null && payload.isNotEmpty) {
          // fetch event doc and navigate
          final doc = await FirebaseFirestore.instance
              .collection('events')
              .doc(payload)
              .get();
          if (doc.exists) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                  builder: (_) => EventDetailsScreen(event: doc)),
            );
          }
        }
      },
    );
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'campusly_notifications',
      'Campusly Notifications',
      channelDescription: 'Notifications for events and team updates',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
}
