import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventRegistrationScreen extends StatefulWidget {
  final DocumentSnapshot event;

  const EventRegistrationScreen({super.key, required this.event});

  @override
  State<EventRegistrationScreen> createState() => _EventRegistrationScreenState();
}

class _EventRegistrationScreenState extends State<EventRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = true;
  bool isSubmitting = false;
  Map<String, dynamic>? studentData;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _deptController;
  late TextEditingController _yearController;
  late TextEditingController _semController;
  late TextEditingController _ktuIdController;

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('student')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        studentData = doc.data() as Map<String, dynamic>;
        _nameController = TextEditingController(text: studentData?['name'] ?? '');
        _phoneController = TextEditingController(text: studentData?['phone'] ?? '');
        _deptController = TextEditingController(text: studentData?['department'] ?? '');
        _yearController = TextEditingController(text: studentData?['year']?.toString() ?? '');
        _semController = TextEditingController(text: studentData?['semester']?.toString() ?? '');
        _ktuIdController = TextEditingController(text: studentData?['ktuId'] ?? '');
      } else {
        // Fallback for empty controllers if student doc doesn't exist
        _nameController = TextEditingController();
        _phoneController = TextEditingController();
        _deptController = TextEditingController();
        _yearController = TextEditingController();
        _semController = TextEditingController();
        _ktuIdController = TextEditingController();
      }
    }
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _deptController.dispose();
    _yearController.dispose();
    _semController.dispose();
    _ktuIdController.dispose();
    super.dispose();
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 🔹 Check if already registered
      final existingReg = await FirebaseFirestore.instance
          .collection('registrations')
          .where('userId', isEqualTo: user.uid)
          .where('eventId', isEqualTo: widget.event.id)
          .get();

      if (existingReg.docs.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Already Registered"),
              content: const Text("You have already registered for this event."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pop(context); // Go back to event details
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
        return;
      }

      final updatedData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'department': _deptController.text.trim(),
        'year': _yearController.text.trim(),
        'semester': _semController.text.trim(),
        'ktuId': _ktuIdController.text.trim().toUpperCase(),
      };

      // 1. Update Profile if changed
      await FirebaseFirestore.instance
          .collection('student')
          .doc(user.uid)
          .set(updatedData, SetOptions(merge: true));

      // 2. Register for Event
      await FirebaseFirestore.instance.collection('registrations').add({
        'userId': user.uid,
        'eventId': widget.event.id,
        'eventTitle': widget.event['title'] ?? widget.event['name'] ?? 'Untitled Event',
        'studentName': updatedData['name'],
        'studentEmail': user.email,
        'studentPhone': updatedData['phone'],
        'department': updatedData['department'],
        'year': updatedData['year'],
        'semester': updatedData['semester'],
        'ktuId': updatedData['ktuId'],
        'registeredAt': FieldValue.serverTimestamp(),
      });

      // Increment filledSeats count
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .update({'filledSeats': FieldValue.increment(1)});

      if (mounted) {
        // Show Confirmation Dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Registration Successful!",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "You have successfully registered for\n${widget.event['title'] ?? widget.event['name'] ?? 'Untitled Event'}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                    },
                    child: const Text("OK", style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
        
        if (mounted) {
          Navigator.pop(context); // Go back to event details
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Details'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Please review and confirm your details for registration.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(_nameController, "Full Name", Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildTextField(_phoneController, "Phone Number", Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),
                    const SizedBox(height: 16),
                    _buildTextField(_deptController, "Department", Icons.business_outlined),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(_yearController, "Year", Icons.calendar_today_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)]),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(_semController, "Semester", Icons.format_list_numbered_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(_ktuIdController, "KTU ID", Icons.badge_outlined,
                        inputFormatters: [UpperCaseTextFormatter()]),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : _handleRegistration,
                        child: isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Confirm & Register", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) {
          return '$label is required';
        }
        return null;
      },
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
