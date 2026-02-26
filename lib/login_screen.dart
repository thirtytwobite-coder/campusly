import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> _login() async {
    if (_loginEmail.text.isEmpty || _loginPass.text.isEmpty) {
      _showErrorDialog('Please fill all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _loginEmail.text.trim(),
            password: _loginPass.text.trim(),
          );

      if (_loginEmail.text.trim() == 'admin@test.com') {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
          );
        }
        return;
      }

      final facultyDoc = await FirebaseFirestore.instance
          .collection('faculty')
          .doc(userCredential.user!.uid)
          .get();

      if (facultyDoc.exists) {
        final data = facultyDoc.data()!;
        if (data.containsKey('isActive') && data['isActive'] == false) {
          _showErrorDialog('Account disabled. Contact Admin.');
          return;
        }

        if (mounted) {
          switch (data['role']) {
            case 'Main Faculty':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => main_fac.MainFacultyDashboard(
                    collegeName: data['college'],
                  ),
                ),
              );
              break;
            case 'Faculty':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const FacultyHomeScreen()),
              );
              break;
            default:
              _showErrorDialog('Invalid role assigned');
          }
        }
      } else {
        final studentDoc = await FirebaseFirestore.instance
            .collection('student')
            .doc(userCredential.user!.uid)
            .get();
        if (studentDoc.exists) {
          await _handleStudentLogin(studentDoc);
        } else {
          _showErrorDialog('No user record found. Please register.');
        }
      }
    } on FirebaseAuthException catch (e) {
      var errorMessage = 'Login failed';
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = 'Incorrect password.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is badly formatted.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'This user account has been disabled.';
      }
      _showErrorDialog(errorMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStudentLogin(DocumentSnapshot studentDoc) async {
    final studentData = studentDoc.data() as Map<String, dynamic>;

    if (studentData.containsKey('isActive') &&
        studentData['isActive'] == false) {
      _showErrorDialog('Account disabled. Contact Admin.');
      return;
    }

    final coordinatorQuery = await FirebaseFirestore.instance
        .collection('clubs')
        .where(
          'coordinators',
          arrayContains: {
            'studentId': studentDoc.id,
            'studentName': studentData['name'],
            'studentEmail': studentData['email'],
          },
        )
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
    if (_loginEmail.text.isEmpty) {
      _showErrorDialog('Please enter your email to reset the password.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _loginEmail.text.trim(),
      );
      _showErrorDialog('Password reset email sent. Please check your inbox.');
    } catch (e) {
      _showErrorDialog('Error: ${e.toString()}');
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

                      return Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xE6172233)
                                  : const Color(0xEEFFFFFF),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white12
                                    : const Color(0x1A0F172A),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black38
                                      : const Color(0x1A0F172A),
                                  blurRadius: 34,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: wide
                                ? _buildWideLayout(theme)
                                : _buildCompactLayout(theme),
                          )
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.05, end: 0);
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Campusly',
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Your Campus,\nYour Stage.',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Discover events, run clubs, and create unforgettable student experiences.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 20),
        const _PromoPoint(text: 'Real-time approvals'),
        const SizedBox(height: 8),
        const _PromoPoint(text: 'Easy club coordination'),
        const SizedBox(height: 8),
        const _PromoPoint(text: 'Participation analytics'),
      ],
    );
  }
}

class _PromoPoint extends StatelessWidget {
  final String text;

  const _PromoPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
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

  const _AuthForm({
    required this.theme,
    required this.emailController,
    required this.passController,
    required this.isLoading,
    required this.isPasswordObscured,
    required this.onTogglePassword,
    required this.onForgotPassword,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
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
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.72,
                      ),
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
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'example@college.edu',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passController,
          obscureText: isPasswordObscured,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
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
            child: const Text('Forgot Password?'),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  onPressed: onLogin,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign In to Campusly'),
                ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
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
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
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
