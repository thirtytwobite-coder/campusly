import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'change_password.dart';
import 'login_screen.dart';
import 'main.dart';
import 'manage_programs.dart';
import 'profile_screen.dart';

class ClubCoordinatorDashboard extends StatefulWidget {
  const ClubCoordinatorDashboard({super.key});

  @override
  State<ClubCoordinatorDashboard> createState() =>
      _ClubCoordinatorDashboardState();
}

class _ClubCoordinatorDashboardState extends State<ClubCoordinatorDashboard> {
  String? clubId;
  String? clubName;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchClubInfo();
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

  void _onItemTapped(int index) {
    if (index == 0) {
      setState(() {
        _selectedIndex = index;
      });
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      if (clubId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ManageProgramsScreen(
              clubId: clubId!,
              clubName: clubName ?? 'Club',
            ),
          ),
        ).then((_) {
          if (mounted) {
            setState(() {
              _selectedIndex = 0;
            });
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Club information not loaded yet.')),
        );
        setState(() {
          _selectedIndex = 0;
        });
      }
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      ).then((_) {
        if (mounted) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      });
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
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) {
          return;
        }
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
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(clubName ?? 'Coordinator Dashboard'),
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
        body: Column(
          children: [
            Expanded(
              child: clubId == null
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

                        final clubData = snapshot.data!.data() as Map<String, dynamic>?;
                        final description = clubData?['description'] as String? ?? 'No description available.';

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Club Description',
                                            style: Theme.of(context).textTheme.titleLarge,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () => _showEditDescriptionDialog(description),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(description),
                                    ],
                                  ),
                                ),
                              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.5),
                              const SizedBox(height: 24),
                              Text(
                                'Quick Actions',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                children: [
                                  _ActionCard(
                                    icon: Icons.people,
                                    title: 'Members',
                                    description: 'View members',
                                    onTap: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Members feature coming soon')),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle, size: 32),
              label: 'Programs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A237E).withOpacity(0.1),
                const Color(0xFF1A237E).withOpacity(0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 40,
                  color: const Color(0xFF1A237E),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
