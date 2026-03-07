import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_details.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'campusly_notifications_id',
    'Campusly Alerts',
    description: 'Notifications for events and team invitations',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // Create the channel explicitly for Android 8.0+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (navigatorKey != null && payload != null && payload.isNotEmpty) {
          final doc = await FirebaseFirestore.instance
              .collection('events')
              .doc(payload)
              .get();
          if (doc.exists) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => EventDetailsScreen(event: doc)),
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
    await _notificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: payload,
    );
  }
}
