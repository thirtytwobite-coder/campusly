import 'package:flutter/material.dart';
import 'student_home.dart';
import 'club_coordinator_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  RoleSelectionScreen({Key? key}) : super(key: key);

  final _user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Role'),
        automaticallyImplyLeading: false,
        actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()));
              },
            )
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Continue as',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person),
                  label: const Text('Student'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.groups),
                  label: const Text('Club Coordinator'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ClubCoordinatorDashboard()),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  _user?.email ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
