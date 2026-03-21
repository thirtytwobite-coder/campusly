import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'change_password.dart';
import 'login_screen.dart';
import 'vibrant_background.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Try fetching from the 'faculty' collection first
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('faculty')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        // If not in 'faculty', try the 'student' collection
        userDoc = await FirebaseFirestore.instance
            .collection('student')
            .doc(user.uid)
            .get();
      }

      if (mounted && userDoc.exists) {
        Map<String, dynamic> data =
            Map<String, dynamic>.from(userDoc.data() as Map<String, dynamic>);

        // Check if user is a club coordinator
        if (user.email != null) {
          final coordinatorQuery = await FirebaseFirestore.instance
              .collection('clubs')
              .where('coordinatorEmails', arrayContains: user.email)
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
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50, // Compress image to reduce base64 string size
      );

      if (image != null) {
        final bytes = await File(image.path).readAsBytes();
        String base64Image = 'data:image/png;base64,${base64Encode(bytes)}';
        
        setState(() {
          _profilePicController.text = base64Image;
          // Update the local userData so the avatar previews the new image immediately
          userData?['profilePic'] = base64Image;
        });
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  Future<void> _saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Validate name
    if (_nameController.text.trim().isEmpty) {
      _showError('Name is required');
      return;
    }

    // Validate phone number if provided
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
      };

      // Add role-specific fields
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

      // Determine which collection to update
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
    // Optional L, then IDK, then year 22-25, then dept, then constant 0, then 2 digits 00-99
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
    super.dispose();
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
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
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (!isEditing && !isLoading && userData != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Profile',
              onPressed: () {
                setState(() {
                  isEditing = true;
                });
              },
            ),
          if (!isEditing && !isLoading)
            PopupMenuButton<String>(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                if (value == 'password') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                  );
                } else if (value == 'logout') {
                  _showLogoutConfirmation();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'password',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.lock_reset, color: Colors.blue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('Change Password'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.logout, color: Colors.red, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Stack(
        children: [
          const VibrantBackground(),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : userData == null
                  ? const Center(child: Text('User data not found.'))
                  : RefreshIndicator(
                      onRefresh: _fetchUserData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            _buildHeader(theme),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: isEditing 
                                  ? _buildEditForm(theme)
                                  : _buildViewMode(theme),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    String name = userData?['name'] ?? 'User';
    String role = userData?['displayRole'] ?? userData?['role'] ?? 'Role';
    String email = userData?['email'] ?? '';
    String profilePicUrl = userData?['profilePic'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 32, top: 16),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.85),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Hero(
                tag: 'profile-avatar',
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  backgroundImage: profilePicUrl.isNotEmpty 
                      ? (profilePicUrl.startsWith('data:image')
                          ? MemoryImage(base64Decode(profilePicUrl.split(',').last)) as ImageProvider
                          : NetworkImage(_convertGoogleDriveLink(profilePicUrl)))
                      : null,
                  child: profilePicUrl.isEmpty 
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : null,
                ),
              ),
              if (isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.cardColor, width: 2),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role.toUpperCase(),
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewMode(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Contact Information', Icons.contact_phone_outlined, theme),
        _buildInfoCard([
          _buildInfoRow(Icons.phone_outlined, 'Phone', userData?['phone']?.toString() ?? 'Not provided', theme),
          _buildInfoRow(Icons.school_outlined, 'College', userData?['college']?.toString() ?? 'Not provided', theme, isLast: true),
        ], theme),
        
        if (userData?['role'] == 'Student') ...[
          const SizedBox(height: 24),
          _buildSectionHeader('Academic Details', Icons.school_outlined, theme),
          _buildInfoCard([
            _buildInfoRow(Icons.business_outlined, 'Department', userData?['department']?.toString() ?? 'Not provided', theme),
            _buildInfoRow(Icons.calendar_today_outlined, 'Year', userData?['year']?.toString() ?? 'Not provided', theme),
            _buildInfoRow(Icons.format_list_numbered_outlined, 'Semester', userData?['semester']?.toString() ?? 'Not provided', theme),
            _buildInfoRow(Icons.badge_outlined, 'KTU ID', userData?['ktuId']?.toString() ?? 'Not provided', theme, isLast: true),
          ], theme),
        ],
      ],
    );
  }

  Widget _buildEditForm(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.cardColor.withOpacity(0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildEditableField(_nameController, 'Full Name', Icons.person_outline, theme),
            const SizedBox(height: 16),
            _buildEditableField(
              _phoneController, 
              'Phone Number', 
              Icons.phone_outlined,
              theme,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly, 
                LengthLimitingTextInputFormatter(10)
              ],
            ),
            
            if (userData?['role'] == 'Student') ...[
              const SizedBox(height: 24),
              const Text('Academic Details', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildEditableField(
                      _yearController, 
                      'Year',
                      Icons.calendar_today_outlined,
                      theme,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly, 
                        LengthLimitingTextInputFormatter(1)
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildEditableField(
                      _semesterController,
                      'Semester', 
                      Icons.format_list_numbered_outlined,
                      theme,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly, 
                        LengthLimitingTextInputFormatter(1)
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildEditableField(
                _ktuIdController, 
                'KTU ID',
                Icons.badge_outlined,
                theme,
                inputFormatters: [UpperCaseTextFormatter()],
              ),
            ],
            
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        isEditing = false;
                        _initializeControllers();
                        // Reset userData profilePic if it was changed during picking
                        _fetchUserData(); 
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children, ThemeData theme, {EdgeInsetsGeometry? padding}) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.cardColor.withOpacity(0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16.0),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, ThemeData theme, {bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    )),
                    const SizedBox(height: 4),
                    Text(
                      value.isEmpty ? 'Not provided' : value, 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(top: 12.0, bottom: 8.0, left: 56.0),
              child: Divider(height: 1, color: theme.dividerColor.withOpacity(0.2)),
            ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
      TextEditingController controller, String label, IconData icon, ThemeData theme,
      {TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
        filled: true,
        fillColor: theme.cardColor.withOpacity(0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  String _convertGoogleDriveLink(String? link) {
    if (link == null || link.isEmpty) return '';

    if (link.contains('.jpg') || link.contains('.jpeg') || link.contains('.png') || link.contains('.gif') || link.contains('.webp')) {
      return link;
    }

    if (link.contains('drive.google.com/uc?export=view')) {
      return link;
    }

    final regex = RegExp(r'(?:drive\.google\.com/file/d/|id=)([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(link);

    if (match != null) {
      final fileId = match.group(1);
      return 'https://drive.google.com/uc?export=view&id=$fileId';
    }

    return link;
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
