import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

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

        // --- Page Transitions ---
        const pageTransitionsTheme = PageTransitionsTheme(
          builders: {
            TargetPlatform.android: SharedAxisPageTransitionsBuilder(
              transitionType: SharedAxisTransitionType.scaled,
            ),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        );

        // --- Color Palette ---
        const primaryColor = Color(0xFF9575CD); // Soft purple
        const secondaryColor = Color(0xFF512DA8); // Deep violet
        const lightBackgroundColor = Color(0xFFEDE7F6); // Very light lavender
        const darkBackgroundColor = Color(0xFF1A1A2E); // Deep violet-black
        const darkSurfaceColor = Color(0xFF2C2C4E);
        const textColorLight = Color(0xFF3A3A3A); // Charcoal

        // --- Light Theme ---
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
            displayLarge: textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: textColorLight),
            displayMedium: textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold, color: textColorLight),
            displaySmall: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: textColorLight),
            headlineLarge: textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w600, color: textColorLight),
            headlineMedium: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600, color: textColorLight),
            headlineSmall: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: secondaryColor),
            bodyLarge: textTheme.bodyLarge?.copyWith(color: textColorLight, height: 1.5),
            bodyMedium: textTheme.bodyMedium?.copyWith(color: textColorLight.withOpacity(0.8), height: 1.5),
            labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500), // For buttons
          ),
          cardTheme: CardThemeData(
            elevation: 8.0,
            color: Colors.white,
            surfaceTintColor: Colors.white,
            shadowColor: primaryColor.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.5),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              backgroundColor: primaryColor.withOpacity(0.1),
              foregroundColor: primaryColor,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500, color: primaryColor),
            ),
          ),
          iconTheme: const IconThemeData(color: primaryColor),
          dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),
          appBarTheme: AppBarTheme(
            backgroundColor: lightBackgroundColor,
            foregroundColor: secondaryColor,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            titleTextStyle: textTheme.headlineSmall?.copyWith(color: secondaryColor, fontWeight: FontWeight.bold),
            iconTheme: const IconThemeData(color: secondaryColor),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white.withOpacity(0.8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
            labelStyle: textTheme.bodyMedium?.copyWith(color: textColorLight.withOpacity(0.6)),
            floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: primaryColor),
            prefixIconColor: MaterialStateColor.resolveWith((states) {
              if (states.contains(MaterialState.focused)) return primaryColor;
              return textColorLight.withOpacity(0.6);
            }),
          ),
        );

        // --- Dark Theme ---
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
          textTheme: textTheme.copyWith(
            // Headings: white
            displayLarge: textTheme.displayLarge?.copyWith(color: Colors.white),
            displayMedium: textTheme.displayMedium?.copyWith(color: Colors.white),
            displaySmall: textTheme.displaySmall?.copyWith(color: Colors.white),
            headlineLarge: textTheme.headlineLarge?.copyWith(color: Colors.white),
            headlineMedium: textTheme.headlineMedium?.copyWith(color: Colors.white),
            headlineSmall: textTheme.headlineSmall?.copyWith(color: Colors.white),
            titleLarge: textTheme.titleLarge?.copyWith(color: Colors.white),
            titleMedium: textTheme.titleMedium?.copyWith(color: Colors.white),
            titleSmall: textTheme.titleSmall?.copyWith(color: Colors.white),
            
            // Body text: light gray
            bodyLarge: textTheme.bodyLarge?.copyWith(color: Colors.white70),
            bodyMedium: textTheme.bodyMedium?.copyWith(color: Colors.white70),

            // Labels & captions: muted gray
            labelMedium: textTheme.labelMedium?.copyWith(color: Colors.white60),
            labelSmall: textTheme.labelSmall?.copyWith(color: Colors.white60),
            
            // Button text: white
            labelLarge: textTheme.labelLarge?.copyWith(color: Colors.white), 
          ),
          cardTheme: CardThemeData(
            elevation: 4.0,
            color: darkSurfaceColor,
            shadowColor: Colors.black.withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.5),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              backgroundColor: primaryColor.withOpacity(0.15),
              foregroundColor: primaryColor,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500, color: primaryColor),
            ),
          ),
          dividerTheme: DividerThemeData(color: Colors.white.withOpacity(0.1), thickness: 1),
          appBarTheme: AppBarTheme(
            backgroundColor: darkBackgroundColor,
            foregroundColor: Colors.white,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            titleTextStyle: textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            iconTheme: const IconThemeData(color: Colors.white), 
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: darkSurfaceColor.withOpacity(0.8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
            labelStyle: textTheme.bodyMedium?.copyWith(color: Colors.white70),
            hintStyle: textTheme.bodyMedium?.copyWith(color: Colors.white60),
            floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: primaryColor),
            prefixIconColor: MaterialStateColor.resolveWith((states) {
              if (states.contains(MaterialState.focused)) return primaryColor;
              return Colors.white70;
            }),
          ),
        );

        return MaterialApp(
          title: 'Campusly',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: mode,
          home: const UnifiedLoginScreen(),
        );
      },
    );
  }
}
