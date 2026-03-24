import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'vibrant_background.dart';
import 'main.dart'; // For GlassCard

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isLoading = false;
  
  bool _isOldPasswordObscured = true;
  bool _isNewPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  Future<void> _updatePassword() async {
    if (_newPassController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("New passwords do not match.")),
      );
      return;
    }

    if (_newPassController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: FirebaseAuth.instance.currentUser!.email!,
        password: _oldPassController.text.trim(),
      );
      await FirebaseAuth.instance.currentUser!
          .reauthenticateWithCredential(credential);

      await FirebaseAuth.instance.currentUser!
          .updatePassword(_newPassController.text.trim());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password updated successfully!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = "An error occurred. Please try again.";
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = "The current password you entered is incorrect.";
      } else {
        message = e.message ?? message;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Security Settings", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const VibrantBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 120, 24, 40),
            child: Column(
              children: [
                GlassCard(
                  borderRadius: 32,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.security_rounded, size: 32, color: Colors.redAccent),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Change Password",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Ensure your account is secure by using a strong password.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                        ),
                        const SizedBox(height: 32),
                        _buildPasswordField(_oldPassController, "Current Password", _isOldPasswordObscured, (v) => setState(() => _isOldPasswordObscured = v)),
                        const SizedBox(height: 16),
                        _buildPasswordField(_newPassController, "New Password", _isNewPasswordObscured, (v) => setState(() => _isNewPasswordObscured = v)),
                        const SizedBox(height: 16),
                        _buildPasswordField(_confirmPassController, "Confirm New Password", _isConfirmPasswordObscured, (v) => setState(() => _isConfirmPasswordObscured = v)),
                        const SizedBox(height: 32),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _updatePassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: const Text("UPDATE PASSWORD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ).animate().scale(delay: 200.ms),
                              ),
                      ],
                    ),
                  ),
                ).animate().fadeIn().slideY(begin: 0.1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label, bool isObscured, Function(bool) onToggle) {
    return TextField(
      controller: controller,
      obscureText: isObscured,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        suffixIcon: IconButton(
          icon: Icon(isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
          onPressed: () => onToggle(!isObscured),
        ),
      ),
    );
  }
}
