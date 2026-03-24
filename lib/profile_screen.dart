import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'change_password.dart';
import 'login_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'vibrant_background.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProfileScreen extends StatefulWidget {
  final String? uid;
  const ProfileScreen({super.key, this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _departmentController;
  late TextEditingController _yearController;
  late TextEditingController _semesterController;
  late TextEditingController _ktuIdController;
  late TextEditingController _profilePicController;
  late TextEditingController _aboutController;
  late TextEditingController _interestsController;
  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final String targetUid = widget.uid ?? currentUser?.uid ?? '';
    
    if (targetUid.isNotEmpty) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('faculty')
          .doc(targetUid)
          .get();

      if (!userDoc.exists) {
        userDoc = await FirebaseFirestore.instance
            .collection('student')
            .doc(targetUid)
            .get();
      }

      if (mounted && userDoc.exists) {
        Map<String, dynamic> data =
            Map<String, dynamic>.from(userDoc.data() as Map<String, dynamic>);

        if (userData?['email'] != null) {
          final coordinatorQuery = await FirebaseFirestore.instance
              .collection('clubs')
              .where('coordinatorEmails', arrayContains: userData?['email'])
              .limit(1)
              .get();

          if (coordinatorQuery.docs.isNotEmpty) {
            String currentRole = data['role'] ?? '';
            if (currentRole.isNotEmpty && !currentRole.contains('Club Coordinator')) {
              data['displayRole'] = '$currentRole / Club Coordinator';
            } else if (currentRole.isEmpty) {
              data['displayRole'] = 'Club Coordinator';
            }
          }
        }

        setState(() {
          userData = data;
          _initializeControllers();
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: userData?['name'] ?? '');
    _phoneController = TextEditingController(text: userData?['phone'] ?? '');
    _departmentController = TextEditingController(text: userData?['department'] ?? '');
    _yearController = TextEditingController(text: userData?['year'] ?? '');
    _semesterController = TextEditingController(text: userData?['semester'] ?? '');
    _ktuIdController = TextEditingController(text: userData?['ktuId'] ?? '');
    _profilePicController = TextEditingController(text: userData?['profilePic'] ?? '');
    _aboutController = TextEditingController(text: userData?['about'] ?? '');
    _interestsController = TextEditingController(
      text: (userData?['interests'] is List) 
          ? (userData?['interests'] as List).join(', ') 
          : (userData?['interests']?.toString() ?? '')
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64String = 'data:image/png;base64,${base64Encode(bytes)}';
      setState(() {
        _profilePicController.text = base64String;
        userData = {...?userData, 'profilePic': base64String};
      });
    }
  }

  Future<void> _saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || (widget.uid != null && widget.uid != user.uid)) return;

    if (_nameController.text.trim().isEmpty) {
      _showError('Name is required');
      return;
    }

    String phone = _phoneController.text.trim();
    if (phone.isNotEmpty && !_isValidPhoneNumber(phone)) {
      _showError('Please enter a valid 10-digit phone number (digits only)');
      return;
    }

    try {
      final updateData = {
        'name': _nameController.text.trim(),
        'phone': phone,
        'profilePic': _profilePicController.text.trim(),
        'about': _aboutController.text.trim(),
        'interests': _interestsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      };

      if (userData?['role'] == 'Student') {
        String yearStr = _yearController.text.trim();
        String semStr = _semesterController.text.trim();
        String ktuId = _ktuIdController.text.trim().toUpperCase();

        int? year = int.tryParse(yearStr);
        if (year == null || year < 1 || year > 4) {
          _showError('Year must be between 1 and 4');
          return;
        }

        int? sem = int.tryParse(semStr);
        if (sem == null || sem < 1 || sem > 8) {
          _showError('Semester must be between 1 and 8');
          return;
        }

        if (ktuId.isEmpty) {
          _showError('KTU ID is required');
          return;
        }

        if (!_isValidKtuId(ktuId)) {
          _showError('Invalid KTU ID format (Example: IDK23IT040 or LIDK23IT040)');
          return;
        }

        updateData['year'] = yearStr;
        updateData['semester'] = semStr;
        updateData['ktuId'] = ktuId;
      }

      String collection = userData?['role'] == 'Student' ? 'student' : 'faculty';

      await FirebaseFirestore.instance
          .collection(collection)
          .doc(user.uid)
          .update(updateData);

      if (mounted) {
        setState(() {
          isEditing = false;
          userData = {...?userData, ...updateData};
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  bool _isValidPhoneNumber(String phone) {
    return RegExp(r'^\d{10}$').hasMatch(phone);
  }

  bool _isValidKtuId(String ktuId) {
    final ktuIdRegex = RegExp(r'^L?IDK(2[2-5])(CSE|IT|ME|EC|EEE|AI)0\d{2}$');
    return ktuIdRegex.hasMatch(ktuId);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _yearController.dispose();
    _semesterController.dispose();
    _ktuIdController.dispose();
    _profilePicController.dispose();
    _aboutController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  void _showThemeSelectionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 15)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Material(
                color: isDark ? Colors.black.withOpacity(0.85) : Colors.white.withOpacity(0.95),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.brightness_medium_rounded, color: Colors.orange),
                          const SizedBox(width: 12),
                          const Text(
                            "Select Theme",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildThemeOption(ThemeMode.light, 'Light Mode', Icons.wb_sunny_rounded, ctx),
                      _buildThemeOption(ThemeMode.dark, 'Dark Mode', Icons.nightlight_round_rounded, ctx),
                      _buildThemeOption(ThemeMode.system, 'System Default', Icons.brightness_auto_rounded, ctx),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: Text("CLOSE", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: anim1.drive(CurveTween(curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
    );
  }

  Widget _buildThemeOption(ThemeMode mode, String title, IconData icon, BuildContext dialogCtx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = themeNotifier.value == mode;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? (isDark ? Colors.blueAccent : Theme.of(context).primaryColor).withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isSelected ? (isDark ? Colors.blueAccent : Theme.of(context).primaryColor).withOpacity(0.3) : Colors.transparent),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? Colors.blueAccent : Theme.of(context).primaryColor).withOpacity(0.2) : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: isSelected ? (isDark ? Colors.blueAccent : Theme.of(context).primaryColor) : (isDark ? Colors.white38 : Colors.black54)),
        ),
        title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600, fontSize: 14)),
        trailing: isSelected ? Icon(Icons.check_circle_rounded, color: isDark ? Colors.blueAccent : Theme.of(context).primaryColor, size: 20) : null,
        onTap: () async {
          themeNotifier.value = mode;
          final prefs = await SharedPreferences.getInstance();
          String themeStr = 'system';
          if (mode == ThemeMode.light) themeStr = 'light';
          if (mode == ThemeMode.dark) themeStr = 'dark';
          await prefs.setString('themeMode', themeStr);
          if (mounted) Navigator.pop(dialogCtx);
        },
      ),
    );
  }

  void _showLogoutConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 15)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Material(
                color: isDark ? Colors.black.withOpacity(0.85) : Colors.white.withOpacity(0.95),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.logout_rounded, color: Colors.red, size: 32),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Logout Confirmation',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Are you sure you want to logout? You will need to sign in again to access your account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                              ),
                              child: Text('CANCEL', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await FirebaseAuth.instance.signOut();
                                if (mounted) {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (context) => UnifiedLoginScreen()),
                                    (route) => false,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 0,
                              ),
                              child: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: anim1.drive(CurveTween(curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, IconData icon, String label, Color color, {bool isBold = false}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.w700, fontSize: 13, color: isBold ? color : null)),
        ],
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
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: (isDark ? Colors.black : Colors.white).withOpacity(0.05)),
          ),
        ),
        actions: [
          if (!isEditing && !isLoading && userData != null && (widget.uid == null || widget.uid == FirebaseAuth.instance.currentUser?.uid))
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, size: 28),
              tooltip: 'Edit Profile',
              onPressed: () => setState(() => isEditing = true),
            ),
          if (!isEditing && !isLoading && (widget.uid == null || widget.uid == FirebaseAuth.instance.currentUser?.uid))
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'Settings',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (value) {
                if (value == 'password') {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordScreen()));
                } else if (value == 'biometric') {
                  _showBiometricSettingsDialog();
                } else if (value == 'theme') {
                  _showThemeSelectionDialog();
                } else if (value == 'logout') {
                  _showLogoutConfirmation();
                }
              },
              itemBuilder: (context) => [
                _buildPopupItem('password', Icons.lock_reset_rounded, 'Security', Colors.blue),
                _buildPopupItem('biometric', Icons.fingerprint_rounded, 'Biometrics', Colors.blueAccent),
                _buildPopupItem('theme', Icons.palette_rounded, 'Appearance', Colors.orange),
                const PopupMenuDivider(),
                _buildPopupItem('logout', Icons.logout_rounded, 'Sign Out', Colors.red, isBold: true),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          const VibrantBackground(),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : userData == null
                  ? const Center(child: Text('User data not found.'))
                  : Column(
                      children: [
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _fetchUserData,
                            child: CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                _buildSliverHeader(theme),
                                SliverToBoxAdapter(
                                  child: Transform.translate(
                                    offset: const Offset(0, -40),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 0.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.black.withOpacity(0.8) : Colors.white,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(50)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.12),
                                              blurRadius: 25,
                                              offset: const Offset(0, -10),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Aesthetic Handle
                                            Center(
                                              child: Container(
                                                width: 45,
                                                height: 4.5,
                                                margin: const EdgeInsets.only(bottom: 28),
                                                decoration: BoxDecoration(
                                                  color: isDark ? Colors.white24 : Colors.black12,
                                                  borderRadius: BorderRadius.circular(2.5),
                                                ),
                                              ),
                                            ),
                                            isEditing 
                                                ? _buildModernEditForm(theme)
                                                : _buildModernViewMode(theme),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    String name = userData?['name'] ?? 'User';
    String role = userData?['displayRole'] ?? userData?['role'] ?? 'Role';
    String profilePicUrl = userData?['profilePic'] ?? '';
    final accentColor = isDark ? Colors.blueAccent : theme.primaryColor;

    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height * 0.45,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
          child: Stack(
            fit: StackFit.expand,
          children: [
            // Profile Picture
            Hero(
              tag: 'profile-header-img',
              child: profilePicUrl.isNotEmpty
                  ? (profilePicUrl.startsWith('data:image')
                      ? Image.memory(base64Decode(profilePicUrl.split(',').last), fit: BoxFit.cover)
                      : Image.network(_convertGoogleDriveLink(profilePicUrl), fit: BoxFit.cover))
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accentColor.withOpacity(0.8), accentColor.withOpacity(0.4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w900, color: Colors.white24),
                        ),
                      ),
                    ),
            ),
            
            // Gradient Overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Name and Info
            Positioned(
              bottom: 55,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildModernViewMode(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final bool isMe = widget.uid == null || widget.uid == FirebaseAuth.instance.currentUser?.uid;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (userData?['role'] == 'Student') ...[
          // About Section
          const Text(
            "About",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Text(
            (userData?['about']?.toString().isNotEmpty == true)
                ? userData!['about'].toString()
                : "No bio provided yet. Tap edit to tell others about yourself!",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Interests Section
          const Text(
            "Interests",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: (userData?['interests'] is List && (userData?['interests'] as List).isNotEmpty)
                ? (userData?['interests'] as List).map<Widget>((interest) {
                    return _interestChip(interest.toString(), Icons.stars_rounded, _getColorForInterest(interest.toString()));
                  }).toList()
                : [
                    _interestChip("Coding", Icons.code_rounded, Colors.green),
                    _interestChip("Travel", Icons.flight_takeoff_rounded, Colors.blue),
                    _interestChip("Design", Icons.palette_rounded, Colors.orange),
                  ],
          ),
          const SizedBox(height: 32),
        ],

        // Quick Stats
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _statItem(Icons.school_rounded, 'Year', userData?['year']?.toString() ?? 'N/A', Colors.indigo),
            _statItem(Icons.history_rounded, 'Sem', userData?['semester']?.toString() ?? 'N/A', Colors.teal),
            _statItem(Icons.stars_rounded, 'Events', '12+', Colors.amber),
          ],
        ),
        const SizedBox(height: 40),

        // Detailed Info List
        if (isMe) ...[
          _buildModernSectionHeader('Institutional Profile', Icons.fingerprint_rounded, theme),
          _buildModernInfoGroup([
            _buildModernInfoTile(Icons.phone_iphone_rounded, 'Primary Phone', userData?['phone']?.toString() ?? 'Not provided', theme, Colors.blue),
            _buildModernInfoTile(Icons.account_balance_rounded, 'Institutional Affiliation', userData?['college']?.toString() ?? 'Not provided', theme, Colors.indigo),
            _buildModernInfoTile(Icons.badge_rounded, 'Registry ID', userData?['ktuId']?.toString() ?? 'Not provided', theme, Colors.amber.shade800, isLast: true),
          ], theme),
          const SizedBox(height: 32),
        ] else ...[
          _buildModernSectionHeader('Institutional Profile', Icons.account_balance_rounded, theme),
          _buildModernInfoGroup([
            _buildModernInfoTile(Icons.account_balance_rounded, 'Institutional Affiliation', userData?['college']?.toString() ?? 'Not provided', theme, Colors.indigo, isLast: true),
          ], theme),
          const SizedBox(height: 32),
        ],

        // Profile Strength (Matching imitation)

        
        const SizedBox(height: 32),
      ],
    );
  }


  Widget _interestChip(String label, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForInterest(String interest) {
    final colors = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
      Colors.deepOrange,
    ];
    return colors[interest.length % colors.length];
  }

  Widget _statItem(IconData icon, String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSectionHeader(String title, IconData icon, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? Colors.blueAccent : theme.primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, size: 20, color: accentColor),
          ),
          const SizedBox(width: 14),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
        ],
      ),
    );
  }

  Widget _buildModernInfoGroup(List<Widget> children, ThemeData theme) {
    return GlassCard(
      borderRadius: 30,
      blur: 20,
      color: (theme.brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.03),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildModernInfoTile(IconData icon, String label, String value, ThemeData theme, Color color, {bool isLast = false}) {
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: () {}, // For potential deep-diving in future
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.1), width: 1),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: (isDark ? Colors.white38 : Colors.black38))),
                  const SizedBox(height: 4),
                  Text(value.isEmpty ? 'Not Available' : value,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                ],
              ),
            ),
            if (!isLast) const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildModernEditForm(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return GlassCard(
      borderRadius: 32,
      blur: 20,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('Edit Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
            const SizedBox(height: 8),
            Text('Update your information across the platform.', style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38)),
            const SizedBox(height: 32),
            _buildModernEditableField(_nameController, 'Full Name', Icons.person_rounded, theme),
            const SizedBox(height: 18),
            // Profile Image Picker Button
            StatefulBuilder(builder: (context, setState) {
              final isUploadingPic = false; // Add this state if needed globally, or use a local one
              return Container(
              margin: const EdgeInsets.only(bottom: 18),
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [theme.primaryColor.withOpacity(0.8), theme.primaryColor],
                ),
                boxShadow: [
                  BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final picker = ImagePicker();
                  final pickedFile = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 50,
                    maxWidth: 500,
                  );
                  if (pickedFile == null) return;

                  try {
                    final bytes = await pickedFile.readAsBytes();
                    final base64String = base64Encode(bytes);
                    _profilePicController.text = 'data:image/jpeg;base64,$base64String';
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile picture selected!'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.photo_library_rounded, color: Colors.white),
                label: Text(
                  _profilePicController.text.isNotEmpty ? "CHANGE PROFILE PHOTO" : "SELECT PROFILE PHOTO",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            );
            }),
            const SizedBox(height: 18),
            _buildModernEditableField(_phoneController, 'Phone Contact', Icons.phone_iphone_rounded, theme,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),
            const SizedBox(height: 18),
            if (userData?['role'] == 'Student') ...[
              _buildModernEditableField(_aboutController, 'About Me', Icons.description_rounded, theme, maxLines: 4),
              const SizedBox(height: 18),
              _buildModernEditableField(_interestsController, 'Interests (comma separated)', Icons.interests_rounded, theme),
              const SizedBox(height: 18),
            ],
            if (userData?['role'] == 'Student') ...[
              const SizedBox(height: 32),
              const Divider(height: 1, color: Colors.white10),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(child: _buildModernEditableField(_yearController, 'Year', Icons.event_note_rounded, theme,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)])),
                  const SizedBox(width: 16),
                  Expanded(child: _buildModernEditableField(_semesterController, 'Sem', Icons.format_list_numbered_rounded, theme,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)])),
                ],
              ),
              const SizedBox(height: 18),
              _buildModernEditableField(_ktuIdController, 'KTU Registry ID', Icons.badge_rounded, theme,
                inputFormatters: [UpperCaseTextFormatter()]),
            ],
            
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() { isEditing = false; _initializeControllers(); }),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.white10)),
                    ),
                    child: Text('DISCARD', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                    ),
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                      child: const Text('SAVE PROFILE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildModernEditableField(TextEditingController controller, String label, IconData icon, ThemeData theme,
      {TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, int maxLines = 1}) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.08)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.w700),
          prefixIcon: Icon(icon, color: isDark ? Colors.blueAccent.withOpacity(0.7) : theme.primaryColor.withOpacity(0.7), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  void _showBiometricSettingsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final storage = FlutterSecureStorage();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 15)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Material(
                color: isDark ? Colors.black.withOpacity(0.85) : Colors.white.withOpacity(0.95),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.fingerprint_rounded, color: Colors.blueAccent),
                          SizedBox(width: 12),
                          Text(
                            "Security Settings",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      FutureBuilder<bool>(
                        future: SharedPreferences.getInstance().then((prefs) => prefs.getBool('biometric_enabled') ?? false),
                        builder: (context, snapshot) {
                          final isBioEnabled = snapshot.data ?? false;
                          return StatefulBuilder(
                            builder: (context, setDialogState) {
                              bool localEnabled = isBioEnabled;
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: localEnabled ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(color: localEnabled ? Colors.blueAccent.withOpacity(0.3) : (isDark ? Colors.white12 : Colors.black12)),
                                      ),
                                      child: SwitchListTile(
                                        title: const Text("Biometric Login", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                        subtitle: Text(
                                          localEnabled ? "Enabled" : "Disabled",
                                          style: TextStyle(fontSize: 12, color: localEnabled ? Colors.blueAccent : Colors.grey),
                                        ),
                                        secondary: Icon(Icons.security_rounded, color: localEnabled ? Colors.blueAccent : Colors.grey),
                                        value: localEnabled,
                                        activeColor: Colors.blueAccent,
                                        onChanged: (bool value) async {
                                          if (value) {
                                            _showPasswordConfirmationDialog(ctx, (password) async {
                                              // Trigger biometric check before saving
                                              try {
                                                final authenticated = await _localAuth.authenticate(
                                                  localizedReason: 'Verify your fingerprint to link biometric login',
                                                  options: AuthenticationOptions(
                                                    stickyAuth: true,
                                                    biometricOnly: true,
                                                  ),
                                                );

                                                if (authenticated) {
                                                  final prefs = await SharedPreferences.getInstance();
                                                  await prefs.setBool('biometric_enabled', true);
                                                  await storage.write(key: 'saved_email', value: FirebaseAuth.instance.currentUser?.email);
                                                  await storage.write(key: 'saved_password', value: password);
                                                  setDialogState(() => localEnabled = true);
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Biometric login linked and enabled!'), backgroundColor: Colors.green),
                                                    );
                                                  }
                                                } else {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Biometric verification failed. Please try again.'), backgroundColor: Colors.red),
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Error linking biometrics: ${e.toString()}'), backgroundColor: Colors.red),
                                                  );
                                                }
                                              }
                                            });
                                          } else {
                                            final prefs = await SharedPreferences.getInstance();
                                            await prefs.setBool('biometric_enabled', false);
                                            await storage.delete(key: 'saved_email');
                                            await storage.delete(key: 'saved_password');
                                            setDialogState(() => localEnabled = false);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Biometric login disabled.'), backgroundColor: Colors.orange),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                    if (localEnabled) ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: TextButton.icon(
                                          onPressed: () {
                                            _showPasswordConfirmationDialog(ctx, (password) async {
                                              try {
                                                final authenticated = await _localAuth.authenticate(
                                                  localizedReason: 'Verify your new fingerprint to update link',
                                                  options: AuthenticationOptions(
                                                    stickyAuth: true,
                                                    biometricOnly: true,
                                                  ),
                                                );

                                                if (authenticated) {
                                                  await storage.write(key: 'saved_email', value: FirebaseAuth.instance.currentUser?.email);
                                                  await storage.write(key: 'saved_password', value: password);
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Biometric link updated successfully!'), backgroundColor: Colors.green),
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Error updating biometrics: ${e.toString()}'), backgroundColor: Colors.red),
                                                  );
                                                }
                                              }
                                            });
                                          },
                                          icon: const Icon(Icons.fingerprint_rounded, size: 18),
                                          label: const Text("SET NEW FINGERPRINT", style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.blueAccent,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            backgroundColor: Colors.blueAccent.withOpacity(0.05),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ).animate().fadeIn().slideY(begin: 0.2),
                                      ),
                                    ],
                                  ],
                                );
                            }
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: Text("CLOSE", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: anim1.drive(CurveTween(curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
    );
  }

  void _showPasswordConfirmationDialog(BuildContext parentCtx, Function(String) onConfirm) {
    final passController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: parentCtx,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: const Text("Confirm Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("To enable biometric login, please enter your current password to securely store it on this device.", style: TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: passController,
              obscureText: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: const InputDecoration(
                labelText: "Current Password",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (passController.text.isNotEmpty) {
                Navigator.pop(ctx);
                onConfirm(passController.text);
              }
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

String _convertGoogleDriveLink(String? link) {
  if (link == null || link.isEmpty) return '';
  if (link.contains('.jpg') || link.contains('.jpeg') || link.contains('.png') || link.contains('.gif') || link.contains('.webp')) return link;
  if (link.contains('drive.google.com/uc?export=view')) return link;
  final regex = RegExp(r'(?:drive\.google\.com/file/d/|id=)([a-zA-Z0-9-_]+)');
  final match = regex.firstMatch(link);
  if (match != null) return 'https://drive.google.com/uc?export=view&id=${match.group(1)}';
  return link;
}
