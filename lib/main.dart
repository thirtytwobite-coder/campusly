import 'package:animations/animations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:college_event_manager/club_coordinator_dashboard.dart';
import 'package:college_event_manager/notification_service.dart';
import 'package:college_event_manager/role_selection_screen.dart';
import 'package:college_event_manager/event_details.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'faculty_home.dart';
import 'main_faculty_dashboard.dart' as main_fac;
import 'student_home.dart';
import 'welcome_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
String? _fcmToken;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // 🔹 Initialize Local Notifications with navigation support
  await NotificationService.init(navigatorKey: navigatorKey);

  // set up firebase messaging (permission, token, listeners)
  await _setupFCM();

  // listen for auth changes to save token once user logs in
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null && _fcmToken != null) {
      _saveTokenToFirestore(_fcmToken!);
    }
  });

  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  runApp(const CampuslyApp());
}

Future<void> _setupFCM() async {
  try {
    final messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    // ignore: avoid_print
    print('FCM permission status: ${settings.authorizationStatus}');

    _fcmToken = await messaging.getToken();
    if (_fcmToken != null) {
      await _saveTokenToFirestore(_fcmToken!);
    }

    messaging.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      await _saveTokenToFirestore(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final data = message.data;
      final title = notification?.title ?? '';
      final body = notification?.body ?? '';
      final eventId = data['eventId'] ?? '';

      if (title.isNotEmpty || body.isNotEmpty) {
        NotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: title,
          body: body,
          payload: eventId,
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // handle case when app was terminated
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _handleMessage(initial);
    }
  } catch (e) {
    debugPrint("Error setting up FCM: $e");
  }
}

Future<void> _saveTokenToFirestore(String token) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await userRef.get();
    if (doc.exists) {
      await userRef.update({'fcmToken': token});
    } else {
      String name = '';
      String role = 'STUDENT';
      final studentSnap = await FirebaseFirestore.instance.collection('student').doc(user.uid).get();
      if (studentSnap.exists) {
        name = studentSnap.data()?['name'] ?? '';
        role = 'STUDENT';
      } else {
        final facultySnap = await FirebaseFirestore.instance.collection('faculty').doc(user.uid).get();
        if (facultySnap.exists) {
          name = facultySnap.data()?['name'] ?? '';
          role = 'FACULTY';
        }
      }
      await userRef.set({'name': name, 'role': role, 'fcmToken': token});
    }
  } catch (e) {
    debugPrint("Error saving token: $e");
  }
}

void _handleMessage(RemoteMessage message) {
  final eventId = message.data['eventId'];
  if (eventId != null && eventId.toString().isNotEmpty) {
    FirebaseFirestore.instance.collection('events').doc(eventId).get().then((doc) {
      if (doc.exists) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => EventDetailsScreen(event: doc),
          ),
        );
      }
    });
  }
}

class CampuslyApp extends StatelessWidget {
  const CampuslyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, child) {
        final textTheme = GoogleFonts.manropeTextTheme();

        const pageTransitionsTheme = PageTransitionsTheme(
          builders: {
            TargetPlatform.android: SharedAxisPageTransitionsBuilder(
              transitionType: SharedAxisTransitionType.scaled,
            ),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        );

        const lightScheme = ColorScheme.light(
          primary: Color(0xFF0F4C81),
          secondary: Color(0xFF0EA5A4),
          surface: Color(0xFFFFFFFF),
          onPrimary: Color(0xFFFFFFFF),
          onSecondary: Color(0xFFFFFFFF),
          onSurface: Color(0xFF0F172A),
          error: Color(0xFFDC2626),
        );

        const darkScheme = ColorScheme.dark(
          primary: Color(0xFF60A5FA),
          secondary: Color(0xFF2DD4BF),
          surface: Color(0xFF111827),
          onPrimary: Color(0xFF0F172A),
          onSecondary: Color(0xFF0F172A),
          onSurface: Color(0xFFE2E8F0),
          error: Color(0xFFF87171),
        );

        final lightTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: lightScheme,
          scaffoldBackgroundColor: const Color(0xFFF3F6FA),
          pageTransitionsTheme: pageTransitionsTheme,
          textTheme: textTheme,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: lightScheme.onSurface,
            elevation: 0,
            centerTitle: false,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            titleTextStyle: textTheme.titleLarge?.copyWith(
              color: lightScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          cardTheme: CardThemeData(
            color: Colors.white.withValues(alpha: 0.84),
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: lightScheme.primary.withValues(alpha: 0.18),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: lightScheme.primary.withValues(alpha: 0.16),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: lightScheme.primary, width: 1.6),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        );

        final darkTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: darkScheme,
          scaffoldBackgroundColor: const Color(0xFF0B1220),
          pageTransitionsTheme: pageTransitionsTheme,
          textTheme: textTheme,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: darkScheme.onSurface,
            elevation: 0,
            centerTitle: false,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            titleTextStyle: textTheme.titleLarge?.copyWith(
              color: darkScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          cardTheme: CardThemeData(
            color: darkScheme.surface.withValues(alpha: 0.9),
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: darkScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: darkScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: darkScheme.primary.withValues(alpha: 0.28),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: darkScheme.primary, width: 1.6),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        );

        return MaterialApp(
          navigatorKey: navigatorKey, // 🔹 Set the navigatorKey
          title: 'Campusly',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: mode,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<Widget> _getInitialScreen(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final lastRole = prefs.getString('last_role_${user.uid}');

    final facultySnap = await FirebaseFirestore.instance
        .collection('faculty')
        .doc(user.uid)
        .get();
    if (facultySnap.exists) {
      final data = facultySnap.data()!;
      if (data['role'] == 'Main Faculty') {
        return main_fac.MainFacultyDashboard(collegeName: data['college']);
      }
      return const FacultyHomeScreen();
    }

    final studentSnap = await FirebaseFirestore.instance
        .collection('student')
        .doc(user.uid)
        .get();
    if (studentSnap.exists) {
      final data = studentSnap.data()!;
      final coordSnap = await FirebaseFirestore.instance
          .collection('clubs')
          .where('coordinatorEmails', arrayContains: user.email)
          .limit(1)
          .get();

      final isCoordinator = coordSnap.docs.isNotEmpty;

      if (isCoordinator) {
        if (lastRole == 'coordinator') {
          final clubId = prefs.getString('last_club_id_${user.uid}');
          final clubName = prefs.getString('last_club_name_${user.uid}');
          if (clubId != null && clubName != null) {
            return ClubCoordinatorDashboard(
              initialClubId: clubId,
              initialClubName: clubName,
            );
          }
        }
        if (lastRole == 'student') {
          return const StudentHomeScreen();
        }
        return const RoleSelectionScreen();
      }

      return const StudentHomeScreen();
    }

    return const WelcomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (userSnapshot.hasData) {
          return FutureBuilder<Widget>(
            future: _getInitialScreen(userSnapshot.data!),
            builder: (context, screenSnapshot) {
              if (screenSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return screenSnapshot.data ?? const WelcomeScreen();
            },
          );
        }
        return const WelcomeScreen();
      },
    );
  }
}
