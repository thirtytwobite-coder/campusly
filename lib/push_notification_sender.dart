/// Service for sending push notifications using Firebase Cloud Messaging (FCM).
/// This class handles OAuth 2.0 authentication with Firebase service account credentials
/// to send push notifications to specific devices or topics. It manages access token caching
/// and provides methods to send notifications with custom titles, bodies, and data payloads.
/// Note: Storing service account keys on the client side is not recommended for production apps.

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' as jwt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 🚨 WARNING: Storing a Service Account Private Key on the client is insecure.
/// This approach is only for prototypes or small projects on the Firebase Spark plan
/// that require "app-closed" notifications without a backend.
class PushNotificationSender {
  static const String _projectId = "collegeeventmanager-b3211";
  static const String _clientEmail = "firebase-adminsdk-fbsvc@collegeeventmanager-b3211.iam.gserviceaccount.com";
  static const String _privateKey = """-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDT73Q5GWYd8nUL
EDNOcK9660ykS9iX9c80PoQwvvR3L+MOi9oSmimHBQvyb4pkWies6EadieOeNGbG
iPzjHZX15DsWO1uKjv8FeIeV4F0iGqbJsYzMEQA3PG2u6S89sPMDz/P7p+MSnKC8
RUN1Vq5a9par5eSKidkHl31Py8zdnbHTxSh/f1xY7iS0JYVmzsI5fmXV0zoDGra7
hs4cBIX/BmJ54tiw9oK0/vpu1bX4VUDDhKetKc2hgJzqhKG+8nKMRPzW6G32dm+L
QqI90Apx+I3z0fWTqswgzW5IyvgqjiM/10Ein5/O38zs2qlRsnxokNUMyStrVZTH
eiZHTsu/AgMBAAECggEAA+X8L86xS6y5jW4LW46EE9E/NCh2//iUCqR5vwHMMmMN
nnKdi6AOw7txfZ2K423azEyGkpuIx7yeMmmtLp4vURdUgZxzJZseRllKsv8uEOwvd
dIlRCzHm3J0+cUC1zz8xgSjylnb0nNOHu17UylRBWcf+ZoQQi6HUfajCM9UOXCcx
VrAksGtPMx+jc4mpQv+g+mRQMVORx5b96iRj0B2E35FxAcCyvZZJfEBWtlY4iL8W
G/0MAh1d1hiXJ1mdhDjtUHmr78QImCNw8y0VsU+fheGvEehpOLQYAQz0em6epg36
/OiK4Y40NcA2rsz3LekPslMATqDAfBpWWObJ5uX44QKBgQD5r40lqqMwNL3lRA/C
Gywz0ZkKI9kp4sBYoPF6E47bzyZNXofEXppkA5DZTXu3RKvPZpG0vniMtYrt/Lkw
90f7GQDPxgTBV01DJJInzszanJXKpCEcaUceb4/2alKANyO6wuusnbJKkSnF30RR
6bfOXRGTMOtS2kvrdLBDCHaDYQKBgQDZS4Jc9wziQRqSOIdrBqQnaCcQzwOz7aXB
JC5X2rtSQF9gWOWKHvZ9gPF7WJRQrgI9bNfEf1YOLPUZcKhSw/YqRzRfuiWJHv54
Zq6YStgc7rgJKIOxv5yMAKvjqmvsEyLVc8hEVSDGHrkDwir/aMcNvMaVE5k60Fva
9wUtiCLDHwKBgAqo8g+/n0P5nHnjVADnhBWaRzxll2nwYmHmTSj3GMxNpcb72DQM
De9jL5X3dua2Kdeq+2GKGD95qLrMZWOvywTvZld4js9qWMQbFZpZe+mBceu64icC
X6TvAmh01ZzfvcjFdaZi/S+tzujBxXrxzYUj+BIero1VAJTG4JecDuNBAoGAGPdu
ERRprI1iai6IkKmAru5unqXKfR/vDZQEpx+AqmCvFLjiFs6b76ujE1MIJ4T2yOv6
nlp8y2gocV0H0dR4C6LSptd4Ddg/TmS3jHahr0Fc1WggHqaKkcAmbtlrcb5F7TR8y
gXdufpUFGQN0QUhepptsDbDkyDcsdqovNB4SMG0CgYEA1PkOkOsIyGsYQRK5IMWG
eGIY5/WrCgpaUbZ9FCElJwECmfKB9Q+BpTogReFOxRNULUgy/m3wQGODvnkALESW
xsZmuUNyfZxEtyFhflWUDPvgd/OmWL7a0Eh2SMlwlCQMEcJklm1rzPMGZtS7P7SR
NLbfcukmwoxiAukDD8pDsZY=
-----END PRIVATE KEY-----""";

  static String? _cachedAccessToken;
  static DateTime? _accessTokenExpiry;

  /// Gets an OAuth 2.0 access token using the Service Account.
  static Future<String?> _getAccessToken() async {
    if (_cachedAccessToken != null && _accessTokenExpiry != null && _accessTokenExpiry!.isAfter(DateTime.now())) {
      return _cachedAccessToken;
    }

    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      final payload = {
        "iss": _clientEmail,
        "scope": "https://www.googleapis.com/auth/cloud-platform",
        "aud": "https://oauth2.googleapis.com/token",
        "exp": now + 3600,
        "iat": now,
      };

      final key = jwt.RSAPrivateKey(_privateKey);
      final token = jwt.JWT(payload);
      final tokenString = token.sign(key, algorithm: jwt.JWTAlgorithm.RS256);

      final response = await http.post(
        Uri.parse("https://oauth2.googleapis.com/token"),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
          "assertion": tokenString,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _cachedAccessToken = data["access_token"];
        _accessTokenExpiry = DateTime.now().add(const Duration(seconds: 3500));
        return _cachedAccessToken;
      } else {
        debugPrint("❌ FCM Auth Error: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ FCM Auth Exception: $e");
      return null;
    }
  }

  /// Sends a push notification to specific users.
  static Future<void> sendToRole({
    required String role,
    String? college,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 1. Fetch matching user tokens from Firestore
      Query query = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: role.toUpperCase());
      if (college != null && college.isNotEmpty) {
        query = query.where('college', isEqualTo: college.toUpperCase());
      }

      final snapshot = await query.get();
      final tokens = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .map((data) => data['fcmToken']?.toString())
          .where((t) => t != null && t.isNotEmpty)
          .cast<String>()
          .toList();

      if (tokens.isEmpty) {
        debugPrint("ℹ️ Push: No matching tokens found for $role @ $college");
        return;
      }

      debugPrint("🚀 Sending Push to ${tokens.length} recipients...");
      
      final accessToken = await _getAccessToken();
      if (accessToken == null) return;

      for (var token in tokens) {
        await _sendToToken(token, title, body, data, accessToken);
      }
    } catch (e) {
      debugPrint("❌ Push Exception: $e");
    }
  }

  /// Sends push to a specific UID.
  static Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final token = userDoc.data()?['fcmToken']?.toString();
      
      if (token == null || token.isEmpty) return;

      final accessToken = await _getAccessToken();
      if (accessToken == null) return;

      await _sendToToken(token, title, body, data, accessToken);
    } catch (e) {
      debugPrint("❌ Push Exception: $e");
    }
  }

  static Future<void> _sendToToken(String token, String title, String body, Map<String, dynamic>? data, String accessToken) async {
    final url = "https://fcm.googleapis.com/v1/projects/$_projectId/messages:send";
    
    final payload = {
      "message": {
        "token": token,
        "notification": {"title": title, "body": body},
        "data": data?.map((key, value) => MapEntry(key, value.toString())) ?? {},
        "android": {
          "priority": "high",
          "notification": {
            "channel_id": "campusly_alert_channel",
            "priority": "high",
            "visibility": "public",
          }
        }
      }
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $accessToken",
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      debugPrint("❌ FCM Send Error: ${response.body}");
    } else {
      debugPrint("✅ Push delivered to token: ${token.substring(0, 5)}...");
    }
  }
}
