import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_details.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Channel IDs
  static const String infoChannelId = 'campusly_info_channel';
  static const String alertChannelId = 'campusly_alert_channel';
  static const String successChannelId = 'campusly_success_channel';

  static const AndroidNotificationChannel _infoChannel = AndroidNotificationChannel(
    infoChannelId,
    'Campusly Info',
    description: 'Standard system updates and information',
    importance: Importance.defaultImportance,
    playSound: true,
  );

  static const AndroidNotificationChannel _alertChannel = AndroidNotificationChannel(
    alertChannelId,
    'Campusly Alerts',
    description: 'Critical notifications and urgent updates',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _successChannel = AndroidNotificationChannel(
    successChannelId,
    'Campusly Success',
    description: 'Confirmations and successful operations',
    importance: Importance.low,
    playSound: true,
  );

  static Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // Create all channels explicitly for Android 8.0+
    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    await androidPlugin?.createNotificationChannel(_infoChannel);
    await androidPlugin?.createNotificationChannel(_alertChannel);
    await androidPlugin?.createNotificationChannel(_successChannel);

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

  static Future<bool> requestPermission() async {
    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.requestNotificationsPermission() ?? false;
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = infoChannelId,
  }) async {
    // 🔹 Ensure MAX importance for ALL channels so they pop-up ("heads-up") on any device
    const importance = Importance.max;
    const priority = Priority.high;

    await _notificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == alertChannelId ? _alertChannel.name : (channelId == successChannelId ? _successChannel.name : _infoChannel.name),
          channelDescription: channelId == alertChannelId ? _alertChannel.description : (channelId == successChannelId ? _successChannel.description : _infoChannel.description),
          importance: importance,
          priority: priority,
          ticker: 'ticker',
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: payload,
    );
  }
}
