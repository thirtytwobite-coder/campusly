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
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
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
                                  Icons.phone_outlined,
                                  'Phone',
                                  userData?['phone'] ?? 'N/A'),
                              const SizedBox(height: 16),
                              _buildProfileInfoRow(
                                  Icons.school_outlined,
                                  'College',
                                  userData?['college'] ?? 'N/A'),
                              const SizedBox(height: 16),
                              _buildProfileInfoRow(
                                  Icons.business_outlined,
                                  'Department',
                                  userData?['department'] ?? 'N/A'),
                              const SizedBox(height: 16),
                              _buildProfileInfoRow(
                                  Icons.calendar_today_outlined,
                                  'Year',
                                  userData?['year'] ?? 'N/A'),
                              const SizedBox(height: 16),
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
}
