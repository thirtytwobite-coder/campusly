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
  String _registrationType = 'participant';

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _deptController;
  late TextEditingController _yearController;
  late TextEditingController _semController;
  late TextEditingController _ktuIdController;

  final List<Map<String, dynamic>> _selectedTeamMembers = [];
  List<Map<String, dynamic>> _collegeStudents = [];
  bool _isLoadingStudents = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers immediately to avoid LateInitializationError
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _deptController = TextEditingController();
    _yearController = TextEditingController();
    _semController = TextEditingController();
    _ktuIdController = TextEditingController();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('student')
            .doc(user.uid)
            .get();

        if (doc.exists && mounted) {
          studentData = doc.data() as Map<String, dynamic>;
          setState(() {
            _nameController.text = studentData?['name'] ?? '';
            _phoneController.text = studentData?['phone'] ?? '';
            _deptController.text = studentData?['department'] ?? '';
            _yearController.text = studentData?['year']?.toString() ?? '';
            _semController.text = studentData?['semester']?.toString() ?? '';
            _ktuIdController.text = studentData?['ktuId'] ?? '';
          });
          _fetchCollegeStudents();
        }
      } catch (e) {
        debugPrint("Error fetching student data: $e");
      }
    }
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchCollegeStudents() async {
    if (studentData == null || studentData!['college'] == null) return;
    final String college = studentData!['college'];
    final user = FirebaseAuth.instance.currentUser;

    setState(() => _isLoadingStudents = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('student')
          .where('college', isEqualTo: college)
          .get();

      if (mounted) {
        setState(() {
          _collegeStudents = snap.docs
              .map((e) => {'id': e.id, ...e.data()})
              .where((e) => e['id'] != user?.uid)
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching students: $e");
    } finally {
      if (mounted) setState(() => _isLoadingStudents = false);
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

      final eventData = widget.event.data() as Map<String, dynamic>? ?? {};

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

      final bool requiresVolunteers = eventData['requiresVolunteers'] == true;
      final String regType = requiresVolunteers ? _registrationType : 'participant';
      final bool isTeamEvent = eventData['isTeamEvent'] == true;
      final int maxTeamSize = (eventData['teamSize'] ?? 1) is int ? eventData['teamSize'] : int.tryParse(eventData['teamSize']?.toString() ?? '1') ?? 1;

      // 1. Update Profile if changed
      await FirebaseFirestore.instance
          .collection('student')
          .doc(user.uid)
          .set(updatedData, SetOptions(merge: true));

      // 2. Register for Event
      final String teamId = (isTeamEvent && regType == 'participant') ? "${widget.event.id}_${user.uid}" : "";

      await FirebaseFirestore.instance.collection('registrations').add({
        'userId': user.uid,
        'eventId': widget.event.id,
        'eventTitle': eventData['title'] ?? eventData['name'] ?? 'Untitled Event',
        'studentName': updatedData['name'],
        'studentEmail': user.email,
        'studentPhone': updatedData['phone'],
        'department': updatedData['department'],
        'year': updatedData['year'],
        'semester': updatedData['semester'],
        'ktuId': updatedData['ktuId'],
        'college': studentData?['college'], // Added college field
        'registrationType': regType,
        'registeredAt': FieldValue.serverTimestamp(),
        if (isTeamEvent && regType == 'participant') 'teamId': teamId,
        if (isTeamEvent && regType == 'participant') 'isTeamLeader': true,
        if (isTeamEvent && regType == 'participant') 'status': 'confirmed',
      });

      // 3. Register added team members dynamically
      if (isTeamEvent && regType == 'participant' && _selectedTeamMembers.isNotEmpty) {
        for (var memberData in _selectedTeamMembers) {
             final pendingRegRef = await FirebaseFirestore.instance.collection('registrations').add({
               'userId': memberData['id'],
               'eventId': widget.event.id,
               'eventTitle': eventData['title'] ?? eventData['name'] ?? 'Untitled Event',
               'studentName': memberData['name'] ?? 'Team Member',
               'studentEmail': memberData['email'] ?? '',
               'studentPhone': memberData['phone'] ?? '',
               'department': memberData['department'] ?? '',
               'year': memberData['year'] ?? '',
               'semester': memberData['semester'] ?? '',
               'ktuId': memberData['ktuId'] ?? '',
               'college': memberData['college'] ?? '',
               'registrationType': 'participant',
               'registeredAt': FieldValue.serverTimestamp(),
               'teamId': teamId,
               'isTeamLeader': false,
               'status': 'pending', 
             });

             await FirebaseFirestore.instance.collection('student').doc(memberData['id']).collection('notifications').add({
               'type': 'team_invite',
               'title': 'Team Invitation',
               'message': '${updatedData['name']} invited you to join their team for ${eventData['title'] ?? 'an event'}.',
               'eventId': widget.event.id,
               'regId': pendingRegRef.id,
               'read': false,
               'timestamp': FieldValue.serverTimestamp(),
             });

             await FirebaseFirestore.instance
                .collection('events')
                .doc(widget.event.id)
                .update({'filledSeats': FieldValue.increment(1)});
        }
      }

      // Increment filledSeats count
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .update({'filledSeats': FieldValue.increment(1)});

      // Decrement volunteers needed when a volunteer registers
      if (regType == 'volunteer') {
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final eventRef = FirebaseFirestore.instance.collection('events').doc(widget.event.id);
          final snap = await tx.get(eventRef);
          final data = snap.data() as Map<String, dynamic>? ?? {};
          final int current = (data['volunteerCount'] is int) ? data['volunteerCount'] as int : int.tryParse(data['volunteerCount']?.toString() ?? '') ?? 0;
          final int next = current > 0 ? current - 1 : 0;
          tx.update(eventRef, {'volunteerCount': next});
        });
      }

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
                  "You have successfully registered for\n${eventData['title'] ?? eventData['name'] ?? 'Untitled Event'}",
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
    final eventData = widget.event.data() as Map<String, dynamic>? ?? {};
    final bool requiresVolunteers = eventData['requiresVolunteers'] == true;
    final String? volunteerRole = eventData['volunteerRole']?.toString();
    final String volunteerCount = (eventData['volunteerCount'] ?? '').toString();
    final bool isTeamEvent = eventData['isTeamEvent'] == true;
    final int maxTeamSize = (eventData['teamSize'] ?? 1) is int ? eventData['teamSize'] : int.tryParse(eventData['teamSize']?.toString() ?? '1') ?? 1;

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
                    if (requiresVolunteers) ...[
                      _buildRegisterTypeCard(volunteerCount, volunteerRole),
                      const SizedBox(height: 20),
                    ],
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
                    if (isTeamEvent && _registrationType == 'participant') ...[
                      const SizedBox(height: 24),
                      _buildTeamSection(maxTeamSize),
                    ],
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

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final availableStudents = _collegeStudents
            .where((s) => !_selectedTeamMembers.any((m) => m['id'] == s['id']))
            .toList();

        return AlertDialog(
          title: const Text("Select Team Member"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: availableStudents.isEmpty
                ? const Center(child: Text("No more students available in your college."))
                : ListView.builder(
                    itemCount: availableStudents.length,
                    itemBuilder: (context, index) {
                      final s = availableStudents[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text((s['name'] ?? '?')[0].toUpperCase())),
                        title: Text(s['name'] ?? 'Unknown'),
                        subtitle: Text(s['department'] ?? ''),
                        onTap: () {
                          setState(() {
                            _selectedTeamMembers.add(s);
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTeamSection(int maxTeamSize) {
    if (maxTeamSize <= 1) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Team Members (Max ${maxTeamSize - 1} more)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (_selectedTeamMembers.length < maxTeamSize - 1 && !_isLoadingStudents)
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Add Member"),
                onPressed: _collegeStudents.isEmpty ? null : _showAddMemberDialog,
              )
          ],
        ),
        const SizedBox(height: 10),
        const Text("Select teammates from your college. They will receive an invite to confirm. You do not need to fill all spots.", style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 10),
        if (_isLoadingStudents)
            const Center(child: CircularProgressIndicator()),
        ...List.generate(_selectedTeamMembers.length, (index) {
          final member = _selectedTeamMembers[index];
          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(child: Text((member['name'] ?? '?')[0].toUpperCase())),
              title: Text(member['name'] ?? 'Unknown'),
              subtitle: Text(member['email'] ?? ''),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _selectedTeamMembers.removeAt(index);
                  });
                },
              ),
            ),
          );
        }),
      ],
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

  Widget _buildRegisterTypeCard(String volunteerCount, String? volunteerRole) {
    final String? roleText = (volunteerRole != null && volunteerRole.trim().isNotEmpty) ? volunteerRole.trim() : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E9F2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F1FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.how_to_reg_outlined, size: 20, color: Color(0xFF4B3CC9)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Register As",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F7FB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE3E7F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _RegisterTypePill(
                    label: "Participant",
                    icon: Icons.person_outline,
                    isSelected: _registrationType == 'participant',
                    onTap: () => setState(() => _registrationType = 'participant'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RegisterTypePill(
                    label: "Volunteer",
                    icon: Icons.volunteer_activism_outlined,
                    isSelected: _registrationType == 'volunteer',
                    onTap: () => setState(() => _registrationType = 'volunteer'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1ECFF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.volunteer_activism_outlined, size: 18, color: Color(0xFF2B6CB0)),
                const SizedBox(width: 8),
                Text(
                  volunteerCount.isNotEmpty ? "Volunteers Needed: $volunteerCount" : "Volunteers Needed",
                  style: const TextStyle(color: Color(0xFF2B6CB0), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (roleText != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE2B3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.list_alt_outlined, size: 18, color: Color(0xFFB7791F)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Role: $roleText",
                      style: const TextStyle(color: Color(0xFFB7791F), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RegisterTypePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RegisterTypePill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4B3CC9) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF4B3CC9) : const Color(0xFFE3E7F0)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4B3CC9).withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF667085)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF667085),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
