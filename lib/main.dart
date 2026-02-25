import 'package:animations/animations.dart';
import 'package:college_event_manager/club_coordinator_dashboard.dart';
import 'package:college_event_manager/role_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_screen.dart';
import 'student_home.dart';
import 'faculty_home.dart';
import 'main_faculty_dashboard.dart' as main_fac;

// Global ValueNotifier for theme changes
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Load the saved theme preference
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isDarkMode = prefs.getBool('isDarkMode') ?? false;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  runApp(const CampuslyApp());
}

class CampuslyApp extends StatelessWidget {
  const CampuslyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        final baseTextTheme = Theme.of(context).textTheme;
        final textTheme = GoogleFonts.poppinsTextTheme(baseTextTheme);

        const pageTransitionsTheme = PageTransitionsTheme(
          builders: {
            TargetPlatform.android: SharedAxisPageTransitionsBuilder(
              transitionType: SharedAxisTransitionType.scaled,
            ),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        );

        const primaryColor = Color(0xFF9575CD);
        const secondaryColor = Color(0xFF512DA8);
        const lightBackgroundColor = Color(0xFFEDE7F6);
        const darkBackgroundColor = Color(0xFF1A1A2E);
        const darkSurfaceColor = Color(0xFF2C2C4E);
        const textColorLight = Color(0xFF3A3A3A);

        final lightTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: lightBackgroundColor,
          primaryColor: primaryColor,
          pageTransitionsTheme: pageTransitionsTheme,
          colorScheme: const ColorScheme.light(
            primary: primaryColor,
            secondary: secondaryColor,
            background: lightBackgroundColor,
            surface: Colors.white,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onBackground: textColorLight,
            onSurface: textColorLight,
            error: Colors.redAccent,
          ),
          textTheme: textTheme.copyWith(
            headlineSmall: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: secondaryColor),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: lightBackgroundColor,
            foregroundColor: secondaryColor,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            titleTextStyle: textTheme.headlineSmall?.copyWith(color: secondaryColor, fontWeight: FontWeight.bold),
            iconTheme: const IconThemeData(color: secondaryColor),
          ),
        );

        final darkTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: darkBackgroundColor,
          primaryColor: primaryColor,
          pageTransitionsTheme: pageTransitionsTheme,
          colorScheme: const ColorScheme.dark(
            primary: primaryColor,
            secondary: primaryColor,
            background: darkBackgroundColor,
            surface: darkSurfaceColor,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onBackground: Colors.white,
            onSurface: Colors.white,
            error: Colors.redAccent,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: darkBackgroundColor,
            foregroundColor: Colors.white,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            titleTextStyle: textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
        );

        return MaterialApp(
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

    final facultySnap = await FirebaseFirestore.instance.collection('faculty').doc(user.uid).get();
    if (facultySnap.exists) {
      final data = facultySnap.data()!;
      if (data['role'] == 'Main Faculty') {
        return main_fac.MainFacultyDashboard(collegeName: data['college']);
      }
      return const FacultyHomeScreen();
    }

    final studentSnap = await FirebaseFirestore.instance.collection('student').doc(user.uid).get();
    if (studentSnap.exists) {
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
            return ClubCoordinatorDashboard(initialClubId: clubId, initialClubName: clubName);
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (userSnapshot.hasData) {
          return FutureBuilder<Widget>(
            future: _getInitialScreen(userSnapshot.data!),
            builder: (context, screenSnapshot) {
              if (screenSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
