import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'change_password.dart';
import 'login_screen.dart';
import 'main.dart';

class ClubCoordinatorDashboard extends StatefulWidget {
  const ClubCoordinatorDashboard({super.key});

  @override
  State<ClubCoordinatorDashboard> createState() =>
      _ClubCoordinatorDashboardState();
}

class _ClubCoordinatorDashboardState extends State<ClubCoordinatorDashboard> {
  String? clubId;
  String? clubName;

  @override
  void initState() {
    super.initState();
    _fetchClubInfo();
  }

  Future<bool> _onWillPop() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit'),
          content: const Text('Are you sure you want to Exit?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldLogout ?? false) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const UnifiedLoginScreen()),
          (route) => false,
        );
      }
      return false;
    }
    return false;
  }

  Future<void> _fetchClubInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      final clubsQuery = await FirebaseFirestore.instance
          .collection('clubs')
          .where('coordinatorEmails', arrayContains: user.email)
          .limit(1)
          .get();

      if (mounted && clubsQuery.docs.isNotEmpty) {
        final clubDoc = clubsQuery.docs.first;
        final clubData = clubDoc.data();
        setState(() {
          clubId = clubDoc.id;
          clubName = clubData['name'] as String?;
        });
      }
    }
  }

  Future<void> _showEditDescriptionDialog(String currentDescription) async {
    final TextEditingController descriptionController =
        TextEditingController(text: currentDescription);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Club Description'),
          content: TextField(
            controller: descriptionController,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Enter club description',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () async {
                final newDescription = descriptionController.text;
                if (clubId != null) {
                  await FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(clubId!)
                      .update({'description': newDescription});
                }
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Description updated.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(clubName ?? 'Coordinator Dashboard'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.brightness_6),
              onPressed: () async {
                themeNotifier.value =
                    themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                SharedPreferences prefs = await SharedPreferences.getInstance();
                prefs.setBool('isDarkMode', themeNotifier.value == ThemeMode.dark);
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'changePassword') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                  );
                } else if (value == 'logout') {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const UnifiedLoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
              itemBuilder: (BuildContext context) {
                return [
                  const PopupMenuItem<String>(
                    value: 'changePassword',
                    child: Text('Change Password'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('Logout'),
                  ),
                ];
              },
            ),
          ],
        ),
        body: clubId == null
            ? const Center(child: Text("You are not a coordinator for any club."))
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId!)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Center(child: Text("Club data not found."));
                  }

                  final clubData =
                      snapshot.data!.data() as Map<String, dynamic>?;
                  final description = clubData?['description'] as String? ??
                      'No description available.';

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      color: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Club Description',
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showEditDescriptionDialog(description),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(description, style: const TextStyle(color: Colors.black)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
