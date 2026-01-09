import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        setState(() {
          userData = userDoc.data() as Map<String, dynamic>;
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
    if (_phoneController.text.isNotEmpty && !_isValidPhoneNumber(_phoneController.text)) {
      _showError('Please enter a valid 10-digit phone number');
      return;
    }

    try {
      final updateData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      // Add role-specific fields
      if (userData?['role'] == 'Student') {
        updateData['year'] = _yearController.text.trim();
        updateData['semester'] = _semesterController.text.trim();
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
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    // Check if it's exactly 10 digits
    return digitsOnly.length == 10;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  isEditing = true;
                });
              },
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userData == null
              ? const Center(child: Text('User data not found.'))
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircleAvatar(
                                radius: 50,
                                child: Icon(Icons.person, size: 50),
                              ),
                              const SizedBox(height: 24),
                              if (isEditing)
                                _buildEditableField(
                                    _nameController, 'Name', Icons.person_outline)
                              else
                                _buildProfileInfoRow(
                                    Icons.person_outline,
                                    'Name',
                                    userData?['name'] ?? 'N/A'),
                              const SizedBox(height: 16),
                              _buildProfileInfoRow(
                                  Icons.email_outlined,
                                  'Email',
                                  userData?['email'] ?? 'N/A'),
                              const SizedBox(height: 16),
                              _buildProfileInfoRow(
                                  Icons.school_outlined,
                                  'College',
                                  userData?['college'] ?? 'N/A'),
                              const SizedBox(height: 16),
                              _buildProfileInfoRow(
                                  Icons.badge_outlined,
                                  'Role',
                                  userData?['role'] ?? 'N/A'),
                              const SizedBox(height: 16),
                              if (isEditing)
                                _buildEditableField(
                                    _phoneController, 'Phone', Icons.phone_outlined)
                              else if (userData?['phone'] != null &&
                                  (userData?['phone'] as String).isNotEmpty)
                                _buildProfileInfoRow(
                                    Icons.phone_outlined,
                                    'Phone',
                                    userData?['phone'] ?? 'N/A'),
                              // Show additional fields based on role
                              if (userData?['role'] == 'Student') ...[
                                const SizedBox(height: 16),
                                _buildProfileInfoRow(
                                    Icons.business_outlined,
                                    'Department',
                                    userData?['department'] ?? 'N/A'),
                                const SizedBox(height: 16),
                                if (isEditing)
                                  _buildEditableField(_yearController, 'Year',
                                      Icons.calendar_today_outlined)
                                else
                                  _buildProfileInfoRow(
                                      Icons.calendar_today_outlined,
                                      'Year',
                                      userData?['year'] ?? 'N/A'),
                                const SizedBox(height: 16),
                                if (isEditing)
                                  _buildEditableField(_semesterController,
                                      'Semester', Icons.format_list_numbered_outlined)
                                else
                                  _buildProfileInfoRow(
                                      Icons.format_list_numbered_outlined,
                                      'Semester',
                                      userData?['semester'] ?? 'N/A'),
                                const SizedBox(height: 16),
                                _buildProfileInfoRow(
                                    Icons.badge_outlined,
                                    'KTU ID',
                                    userData?['ktuId'] ?? 'N/A'),
                              ],
                              if (isEditing) ...[
                                const SizedBox(height: 32),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          setState(() {
                                            isEditing = false;
                                            _initializeControllers();
                                          });
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _saveChanges,
                                        child: const Text('Save Changes'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField(
      TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
      ),
    );
  }
}
