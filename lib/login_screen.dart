import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'add_faculty.dart' as add_fac;
import 'change_password.dart';
import 'college_list.dart';
import 'faculty_home.dart';
import 'main.dart';
import 'main_faculty_dashboard.dart' as main_fac;
import 'role_selection_screen.dart';
import 'student_home.dart';
import 'student_signup_screen.dart';
import 'vibrant_background.dart';

class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordObscured = true;
  bool _biometricEnabled = false;
  final _localAuth = LocalAuthentication();
  final _secureStorage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('biometric_enabled') ?? false;
    if (isEnabled) {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (canCheck && isDeviceSupported) {
        setState(() => _biometricEnabled = true);
      }
    }
  }

  Future<void> _loginWithBiometrics() async {
    if (!_biometricEnabled) return;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to sign in to Campusly',
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        setState(() => _isLoading = true);
        final email = await _secureStorage.read(key: 'saved_email');
        final password = await _secureStorage.read(key: 'saved_password');

        if (email != null && password != null) {
          _loginEmail.text = email;
          _loginPass.text = password;
          await _login();
        } else {
          _showErrorDialog('Saved credentials not found. Please login manually first.');
        }
      }
    } catch (e) {
      _showErrorDialog('Biometric authentication failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    if (_loginEmail.text.isEmpty || _loginPass.text.isEmpty) {
      _showErrorDialog('Please fill all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _loginEmail.text.trim(),
          password: _loginPass.text.trim(),
        );
      } on TypeError catch (e) {
        debugPrint('Sign-in decoding error (caught & proceeding): $e');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Authentication failed.',
        );
      }

      final prefs = await SharedPreferences.getInstance();

      // Check Admin
      if (_loginEmail.text.trim() == 'admin@test.com') {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
          );
        }
        return;
      }

      // Check Faculty
      final facultyDoc = await FirebaseFirestore.instance
          .collection('faculty')
          .doc(user.uid)
          .get();

      if (facultyDoc.exists) {
        final data = facultyDoc.data()!;
        if (data['isActive'] == false) {
          await FirebaseAuth.instance.signOut();
          _showErrorDialog('Account disabled. Contact Admin.');
          return;
        }

        if (mounted) {
          await prefs.setString('role', data['role']);
          await prefs.setString('college', data['college']);
          if (data['name'] != null) await prefs.setString('name', data['name']);

          if (data['role'] == 'Main Faculty') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => main_fac.MainFacultyDashboard(
                  collegeName: data['college'],
                ),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const FacultyHomeScreen()),
            );
          }
        }
      } else {
        // Check Student
        final studentDoc = await FirebaseFirestore.instance
            .collection('student')
            .doc(user.uid)
            .get();

        if (studentDoc.exists) {
          await _handleStudentLogin(studentDoc);
        } else {
          await FirebaseAuth.instance.signOut();
          _showErrorDialog('No user record found. Please register.');
        }
      }

      if (_biometricEnabled) {
        await _secureStorage.write(key: 'saved_email', value: _loginEmail.text.trim());
        await _secureStorage.write(key: 'saved_password', value: _loginPass.text.trim());
      }
    } on FirebaseAuthException catch (e) {
      _showErrorDialog(e.message ?? 'Login failed');
    } catch (e) {
      _showErrorDialog('An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStudentLogin(DocumentSnapshot studentDoc) async {
    final studentData = studentDoc.data() as Map<String, dynamic>;

    if (studentData['isActive'] == false) {
      await FirebaseAuth.instance.signOut();
      _showErrorDialog('Account disabled. Contact Admin.');
      return;
    }

    final coordinatorQuery = await FirebaseFirestore.instance
        .collection('clubs')
        .where('coordinatorEmails', arrayContains: studentData['email'])
        .limit(1)
        .get();

    if (mounted) {
      if (coordinatorQuery.docs.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
        );
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _loginEmail.text.trim();
    if (email.isEmpty) {
      _showErrorDialog('Please enter your email to reset the password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check Admin (Hardcoded)
      if (email == 'admin@test.com') {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        _showErrorDialog('Password reset email sent (Admin account).');
        return;
      }

      // Check Faculty
      final facultyQuery = await FirebaseFirestore.instance
          .collection('faculty')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (facultyQuery.docs.isNotEmpty) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        _showErrorDialog('Password reset email sent. Please check your inbox.');
        return;
      }

      // Check Student
      final studentQuery = await FirebaseFirestore.instance
          .collection('student')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (studentQuery.docs.isNotEmpty) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        _showErrorDialog('Password reset email sent. Please check your inbox.');
        return;
      }

      // Not found
      _showErrorDialog('Email not registered. Please register first.');
    } catch (e) {
      _showErrorDialog('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const VibrantBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 760;
                      return GlassCard(
                          borderRadius: 35,
                          blur: 40,
                          border: Border.all(color: Colors.white.withOpacity(isDark ? 0.08 : 0.2)),
                          color: isDark
                              ? Colors.black.withOpacity(0.4)
                              : Colors.white.withOpacity(0.6),
                          child: wide
                              ? _buildWideLayout(theme)
                              : _buildCompactLayout(theme),
                        ).animate().fadeIn(duration: 600.ms).scale(
                          begin: const Offset(0.95, 0.95),
                          end: const Offset(1, 1),
                          curve: Curves.easeOutBack,
                        );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildWideLayout(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                bottomLeft: Radius.circular(28),
              ),
            ),
            child: _LeftPromo(theme: theme),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: _AuthForm(
              theme: theme,
              emailController: _loginEmail,
              passController: _loginPass,
              isLoading: _isLoading,
              isPasswordObscured: _isPasswordObscured,
              onTogglePassword: () =>
                  setState(() => _isPasswordObscured = !_isPasswordObscured),
               onForgotPassword: _handleForgotPassword,
               onLogin: _login,
               biometricEnabled: _biometricEnabled,
               onBiometricLogin: _loginWithBiometrics,
             ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D4ED8).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: _LeftPromo(theme: theme),
          ),
          const SizedBox(height: 18),
          _AuthForm(
            theme: theme,
            emailController: _loginEmail,
            passController: _loginPass,
            isLoading: _isLoading,
            isPasswordObscured: _isPasswordObscured,
            onTogglePassword: () =>
                setState(() => _isPasswordObscured = !_isPasswordObscured),
            onForgotPassword: _handleForgotPassword,
            onLogin: _login,
            biometricEnabled: _biometricEnabled,
            onBiometricLogin: _loginWithBiometrics,
          ),
        ],
      ),
    );
  }
}

class _LeftPromo extends StatelessWidget {
  final ThemeData theme;
  const _LeftPromo({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Image.asset(
              'assets/images/campusly_new_icon.png',
              width: 140,
              height: 140,
              fit: BoxFit.cover,
            ),
          ),
        )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .shimmer(duration: 3.seconds, color: Colors.white24)
            .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 2.seconds, curve: Curves.easeInOut)
            .animate()
            .fadeIn(duration: 800.ms)
            .slideY(begin: -0.2, curve: Curves.easeOutBack),
        const SizedBox(height: 32),
        Text(
          'CAMPUSLY',
          style: theme.textTheme.headlineLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 4.0,
            fontSize: 32,
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 300.ms)
            .slideY(begin: 0.2, duration: 600.ms, curve: Curves.easeOutQuart),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'The next generation of campus connectivity and event management.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withOpacity(0.85),
              fontWeight: FontWeight.w500,
              height: 1.5,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 500.ms)
            .slideY(begin: 0.1, duration: 600.ms, curve: Curves.easeOutCirc),
      ],
    );
  }
}

class _AuthForm extends StatelessWidget {
  final ThemeData theme;
  final TextEditingController emailController;
  final TextEditingController passController;
  final bool isLoading;
  final bool isPasswordObscured;
  final VoidCallback onTogglePassword;
   final VoidCallback onForgotPassword;
   final VoidCallback onLogin;
   final bool biometricEnabled;
   final VoidCallback onBiometricLogin;

   const _AuthForm({
     required this.theme,
     required this.emailController,
     required this.passController,
     required this.isLoading,
     required this.isPasswordObscured,
     required this.onTogglePassword,
     required this.onForgotPassword,
     required this.onLogin,
     required this.biometricEnabled,
     required this.onBiometricLogin,
   });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
              ),
              child: Icon(
                Icons.shield_moon_rounded,
                color: theme.colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Back',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Sign in to access your portal',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildInputField(
          controller: emailController,
          label: 'EMAIL ADDRESS',
          hint: 'Enter your college email',
          icon: Icons.alternate_email_rounded,
          theme: theme,
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        _buildInputField(
          controller: passController,
          label: 'PASSWORD',
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          theme: theme,
          isDark: isDark,
          isPassword: true,
          isObscured: isPasswordObscured,
          onToggle: onTogglePassword,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onForgotPassword,
            child: Text(
              'Forgot Password?', 
              style: TextStyle(
                fontWeight: FontWeight.w800, 
                color: theme.colorScheme.primary,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: isLoading
               ? const Center(child: CircularProgressIndicator())
               : Row(
                   children: [
                     Expanded(
                       child: ElevatedButton.icon(
                         onPressed: onLogin,
                         icon: const Icon(Icons.login_rounded),
                         label: const Text('SIGN IN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                         style: ElevatedButton.styleFrom(
                           padding: const EdgeInsets.symmetric(vertical: 18),
                           backgroundColor: theme.colorScheme.primary,
                           foregroundColor: Colors.white,
                           elevation: 8,
                           shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                         ),
                       ),
                     ),
                     if (biometricEnabled) ...[
                       const SizedBox(width: 12),
                       Container(
                         height: 50,
                         width: 50,
                         decoration: BoxDecoration(
                           color: theme.colorScheme.primary.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(15),
                         ),
                         child: IconButton(
                           onPressed: onBiometricLogin,
                           icon: Icon(Icons.fingerprint_rounded, color: theme.colorScheme.primary),
                           tooltip: 'Login with Biometrics',
                         ),
                       ),
                     ],
                   ],
                 ),
         ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.72),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StudentSignUpScreen(),
                  ),
                );
              },
              child: Text(
                'Register',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ThemeData theme,
    required bool isDark,
    bool isPassword = false,
    bool isObscured = false,
    VoidCallback? onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary.withOpacity(0.8),
              letterSpacing: 1.5,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.08)),
              ),
              child: TextField(
                controller: controller,
                obscureText: isObscured,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.3), fontWeight: FontWeight.w500),
                  prefixIcon: Icon(icon, color: theme.colorScheme.primary.withOpacity(0.7), size: 22),
                  suffixIcon: isPassword
                      ? IconButton(
                          icon: Icon(
                            isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: theme.colorScheme.primary.withOpacity(0.5),
                            size: 20,
                          ),
                          onPressed: onToggle,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, _) => IconButton(
              icon: Icon(mode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: Colors.white),
              onPressed: () async {
                themeNotifier.value = mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isDarkMode', themeNotifier.value == ThemeMode.dark);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const VibrantBackground(),
          SingleChildScrollView(
            child: Column(
              children: [
                // Premium Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 120, 24, 40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.8),
                        theme.colorScheme.secondary.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Welcome Back,",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const Text(
                        "Super Admin",
                        style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    children: [
                      _buildPremiumCard(
                        context,
                        'Add Main Faculty',
                        'Register college admins',
                        Icons.person_add_rounded,
                        [Colors.blue, Colors.lightBlueAccent],
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const add_fac.AddFacultyScreen(role: 'Main Faculty'),
                          ),
                        ),
                        0,
                      ),
                      _buildPremiumCard(
                        context,
                        'Manage Clubs',
                        'All college clubs',
                        Icons.group_work_rounded,
                        [Colors.purple, Colors.deepPurpleAccent],
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminClubsScreen()),
                        ),
                        1,
                      ),
                      _buildPremiumCard(
                        context,
                        'Colleges & Status',
                        'System wide analytics',
                        Icons.analytics_rounded,
                        [Colors.orange, Colors.amberAccent],
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CollegeListView()),
                        ),
                        2,
                      ),
                      _buildPremiumCard(
                        context,
                        'Security',
                        'Update credentials',
                        Icons.security_rounded,
                        [Colors.red, Colors.orangeAccent],
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChangePasswordScreen()),
                        ),
                        3,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context, String title, String subtitle, IconData icon, List<Color> colors, VoidCallback onTap, int index) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: colors[0].withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (100 * index).ms).scale(begin: const Offset(0.9, 0.9));
  }
}


class AdminClubsScreen extends StatefulWidget {
  const AdminClubsScreen({super.key});

  @override
  State<AdminClubsScreen> createState() => _AdminClubsScreenState();
}

class _AdminClubsScreenState extends State<AdminClubsScreen> {
  Future<void> _showAddClubDialog() async {
    final clubName = TextEditingController();
    final clubDesc = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('Add New Club', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: clubName,
                decoration: InputDecoration(
                  labelText: 'Club Name',
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.business_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: clubDesc,
                decoration: InputDecoration(
                  labelText: 'Description',
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.description_rounded),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () async {
                if (clubName.text.isEmpty) return;
                await FirebaseFirestore.instance.collection('clubs').add({
                  'clubName': clubName.text.trim(),
                  'description': clubDesc.text.trim(),
                  'createdBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Add Club', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Manage Clubs', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddClubDialog,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text("New Club", style: TextStyle(fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 400.ms),
      body: Stack(
        children: [
          const VibrantBackground(),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business_center_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black12),
                      const SizedBox(height: 16),
                      Text("No clubs found", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black38)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 120, 20, 100),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: 16),
                    borderRadius: 24,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.group_work_rounded, color: theme.colorScheme.primary),
                      ),
                      title: Text(
                        data['clubName'] ?? 'Unnamed Club',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          data['description'] ?? 'No description provided',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                            height: 1.3,
                          ),
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Delete Club?"),
                              content: const Text("This action cannot be undone."),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await FirebaseFirestore.instance.collection('clubs').doc(docs[index].id).delete();
                          }
                        },
                      ),
                    ),
                  ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
