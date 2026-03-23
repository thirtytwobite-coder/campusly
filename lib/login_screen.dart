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
      // 🔹 Workaround for the Pigeon codec mismatch error:
      // The login often succeeds natively even if the return value fails to decode.
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

      // If login successful and biometric enabled, update stored credentials
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
                          blur: 25,
                          color: isDark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.white.withOpacity(0.4),
                          child: wide
                              ? _buildWideLayout(theme)
                              : _buildCompactLayout(theme),
                        ).animate().fadeIn(duration: 400.ms).scale(
                          begin: const Offset(0.98, 0.98),
                          end: const Offset(1, 1),
                          curve: Curves.easeOutCubic,
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
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 64),
        )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .shimmer(duration: 3.seconds, color: Colors.white24)
            .scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 2.seconds, curve: Curves.easeInOut)
            .animate()
            .fadeIn(duration: 800.ms)
            .slideY(begin: -0.3, end: 0, curve: Curves.easeOutBack),
        const SizedBox(height: 32),
        Text(
          'CAMPUSLY',
          style: theme.textTheme.headlineLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 300.ms)
            .slideY(begin: 0.3, end: 0, duration: 600.ms, curve: Curves.easeOutQuart),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'A simpler way to connect, discover events, and experience college life.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 500.ms)
            .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutCirc),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_circle_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign In',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Continue with your college email',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email Address',
            labelStyle: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary.withOpacity(0.8)),
            hintText: 'example@college.edu',
            prefixIcon: Icon(Icons.alternate_email_rounded, color: theme.colorScheme.primary),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5), width: 1)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passController,
          obscureText: isPasswordObscured,
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary.withOpacity(0.8)),
            hintText: 'Enter your password',
            prefixIcon: Icon(Icons.lock_outline_rounded, color: theme.colorScheme.primary),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5), width: 1)),
            suffixIcon: IconButton(
              onPressed: onTogglePassword,
              icon: Icon(
                isPasswordObscured
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onForgotPassword,
            child: Text('Forgot Password?', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
          ),
        ),
        const SizedBox(height: 4),
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
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () async {
              themeNotifier.value = themeNotifier.value == ThemeMode.light
                  ? ThemeMode.dark
                  : ThemeMode.light;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(
                'isDarkMode',
                themeNotifier.value == ThemeMode.dark,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
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
          GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _card(
                context,
                'Add Main Faculty',
                Icons.person_add,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const add_fac.AddFacultyScreen(role: 'Main Faculty'),
                  ),
                ),
              ),
              _card(
                context,
                'Manage Clubs',
                Icons.group_work,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminClubsScreen()),
                ),
              ),
              _card(
                context,
                'Colleges & Status',
                Icons.list_alt,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CollegeListView()),
                ),
              ),
              _card(
                context,
                'Change Password',
                Icons.lock_reset,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChangePasswordScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 26, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      builder: (_) => AlertDialog(
        title: const Text('Add New Club'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: clubName,
              decoration: const InputDecoration(labelText: 'Club Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: clubDesc,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (clubName.text.isEmpty) return;
              await FirebaseFirestore.instance.collection('clubs').add({
                'clubName': clubName.text.trim(),
                'description': clubDesc.text.trim(),
                'createdBy':
                    FirebaseAuth.instance.currentUser?.email ?? 'admin',
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Clubs')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddClubDialog,
        child: const Icon(Icons.add),
      ),
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
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(
                        data['clubName'] ?? '',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(data['description'] ?? ''),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => FirebaseFirestore.instance
                            .collection('clubs')
                            .doc(docs[index].id)
                            .delete(),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
