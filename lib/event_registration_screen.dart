import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'vibrant_background.dart';

class EventRegistrationScreen extends StatefulWidget {
  final DocumentSnapshot event;

  const EventRegistrationScreen({super.key, required this.event});

  @override
  State<EventRegistrationScreen> createState() => _EventRegistrationScreenState();
}

class _EventRegistrationScreenState extends State<EventRegistrationScreen> with WidgetsBindingObserver {
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
  late TextEditingController _teamNameController;

  final List<Map<String, dynamic>> _selectedTeamMembers = [];
  List<Map<String, dynamic>> _collegeStudents = [];
  bool _isLoadingStudents = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _deptController = TextEditingController();
    _yearController = TextEditingController();
    _semController = TextEditingController();
    _ktuIdController = TextEditingController();
    _teamNameController = TextEditingController();
    _fetchStudentData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _phoneController.dispose();
    _deptController.dispose();
    _yearController.dispose();
    _semController.dispose();
    _ktuIdController.dispose();
    _teamNameController.dispose();
    super.dispose();
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

  bool _isRegistrationClosed() {
    final eventData = widget.event.data() as Map<String, dynamic>? ?? {};
    final deadlineDateStr = eventData['registrationDeadlineDate'];
    final deadlineTimeStr = eventData['registrationDeadlineTime'];
    if (deadlineDateStr != null && deadlineDateStr.isNotEmpty && deadlineTimeStr != null && deadlineTimeStr.isNotEmpty) {
      try {
        final deadline = DateTime.parse('$deadlineDateStr $deadlineTimeStr:00');
        return DateTime.now().isAfter(deadline);
      } catch (e) {
        debugPrint("Error parsing deadline: $e");
      }
    }
    final status = eventData['status']?.toString().toLowerCase() ?? 'approved';
    return status == 'completed';
  }

  bool _hasEnoughSeats() {
    final eventData = widget.event.data() as Map<String, dynamic>? ?? {};
    final bool isTeamEvent = eventData['isTeamEvent'] == true;
    final int teamSize = eventData['teamSize'] != null 
        ? (eventData['teamSize'] is int ? eventData['teamSize'] : int.tryParse(eventData['teamSize'].toString()) ?? 1)
        : 1;
        
    final bool requiresVolunteers = eventData['requiresVolunteers'] == true;
    final String regType = requiresVolunteers ? _registrationType : 'participant';
    final bool shouldRegisterAsTeam = isTeamEvent && regType == 'participant';
    final int seatsRequired = shouldRegisterAsTeam ? teamSize : 1;

    final int filledSeats = eventData['filledSeats'] is int ? eventData['filledSeats'] : int.tryParse(eventData['filledSeats']?.toString() ?? '') ?? 0;
    final dynamic tsData = eventData['totalSeats'] ?? eventData['capacity'] ?? eventData['maxSeats'];
    final String totalSeatsStr = tsData?.toString() ?? '';
    final int totalSeats = int.tryParse(totalSeatsStr) ?? 0;
    
    final bool isUnlimited = totalSeatsStr.isEmpty || totalSeatsStr.toLowerCase() == 'unlimited' || totalSeats <= 0;
    if (isUnlimited) return true;

    final int availableSeats = totalSeats - filledSeats;
    return availableSeats >= seatsRequired;
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isRegistrationClosed()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration has closed for this event.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (!_hasEnoughSeats()) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text("Event Full"),
            content: const Text("Sorry, there are not enough seats remaining for this registration."),
            actions: [
              TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text("OK")),
            ],
          ),
        );
      }
      return;
    }

    _submitRegistration();
  }

  Future<void> _submitRegistration() async {
    final eventData = widget.event.data() as Map<String, dynamic>? ?? {};
    setState(() => isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text("Already Registered"),
              content: const Text("You have already registered for this event."),
              actions: [
                TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text("OK")),
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

      await FirebaseFirestore.instance
          .collection('student')
          .doc(user.uid)
          .set(updatedData, SetOptions(merge: true));

      final String teamId = (isTeamEvent && regType == 'participant') ? "${widget.event.id}_${user.uid}" : "";
      final String teamName = (isTeamEvent && regType == 'participant') ? _teamNameController.text.trim() : "";

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
        'college': studentData?['college'],
        'registrationType': regType,
        'registeredAt': FieldValue.serverTimestamp(),
        if (isTeamEvent && regType == 'participant') 'teamId': teamId,
        if (isTeamEvent && regType == 'participant') 'teamName': teamName,
        if (isTeamEvent && regType == 'participant') 'isTeamLeader': true,
        if (isTeamEvent && regType == 'participant') 'status': 'confirmed',
      });

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
             'teamName': teamName,
             'isTeamLeader': false,
             'status': 'pending',
           });

           await FirebaseFirestore.instance.collection('student').doc(memberData['id']).collection('notifications').add({
             'type': 'team_invite',
             'title': 'Team Invitation',
             'message': '${updatedData['name']} invited you to join their team ${teamName.isNotEmpty ? "($teamName)" : ""} for ${eventData['title'] ?? 'an event'}.',
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

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .update({'filledSeats': FieldValue.increment(1)});

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
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
                ),
                const SizedBox(height: 24),
                const Text("Registration Successful!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                const Text("You've been successfully registered.", style: TextStyle(color: Colors.grey, fontSize: 15), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Done", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventData = widget.event.data() as Map<String, dynamic>? ?? {};
    final bool requiresVolunteers = eventData['requiresVolunteers'] == true;
    final String? volunteerRole = eventData['volunteerRole']?.toString();
    final String volunteerCount = (eventData['volunteerCount'] ?? '').toString();
    final bool isTeamEvent = eventData['isTeamEvent'] == true;
    final dynamic teamSizeRaw = eventData['teamSize'];
    final int maxTeamSize = (teamSizeRaw is int) ? teamSizeRaw : int.tryParse(teamSizeRaw?.toString() ?? '') ?? 1;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        title: const Text('Confirm Details', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.8, fontSize: 24)),
      ),
      body: Stack(
        children: [
          const VibrantBackground(),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (requiresVolunteers) ...[
                            _buildRegisterTypeCard(volunteerCount, volunteerRole),
                            const SizedBox(height: 24),
                          ],
                          GlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Review Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                                  const SizedBox(height: 8),
                                  Text("Please confirm your information for registration.",
                                    style: TextStyle(fontSize: 14, color: Colors.grey.withOpacity(0.8))),
                                  const SizedBox(height: 32),
                                  _buildTextField(_nameController, "Full Name", Icons.person_rounded),
                                  const SizedBox(height: 18),
                                  _buildTextField(_phoneController, "Phone Number", Icons.phone_android_rounded,
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),
                                  const SizedBox(height: 18),
                                  _buildTextField(_deptController, "Department", Icons.school_rounded),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildTextField(_yearController, "Year", Icons.calendar_month_rounded,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)]),
                                      ),
                                      const SizedBox(width: 18),
                                      Expanded(
                                        child: _buildTextField(_semController, "Semester", Icons.layers_rounded,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)]),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  _buildTextField(_ktuIdController, "KTU ID", Icons.badge_rounded,
                                      inputFormatters: [UpperCaseTextFormatter()]),
                                ],
                              ),
                            ),
                          ),
                          if (isTeamEvent && _registrationType == 'participant') ...[
                            const SizedBox(height: 24),
                            GlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Team Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                                    const SizedBox(height: 16),
                                    _buildTextField(_teamNameController, "Team Name", Icons.group_work_rounded),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildTeamSection(maxTeamSize),
                          ],
                          const SizedBox(height: 48),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).primaryColor.withOpacity(0.4),
                                  blurRadius: 30, offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isRegistrationClosed() ? Colors.grey : Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 68),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                elevation: 0,
                              ),
                              onPressed: (isSubmitting || _isRegistrationClosed()) ? null : _handleRegistration,
                              child: isSubmitting
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(_isRegistrationClosed() ? "REGISTRATION CLOSED" : "CONFIRM REGISTRATION",
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                            ),
                          ),
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Select Team Member", style: TextStyle(fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: availableStudents.isEmpty
                ? const Center(child: Text("No more students available in your college."))
                : ListView.builder(
                    itemCount: availableStudents.length,
                    itemBuilder: (context, index) {
                      final s = availableStudents[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          child: Text((s['name'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(s['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(s['department'] ?? '', style: const TextStyle(fontSize: 12)),
                        onTap: () {
                          setState(() => _selectedTeamMembers.add(s));
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ],
        );
      },
    );
  }

  Widget _buildTeamSection(int maxTeamSize) {
    if (maxTeamSize <= 1) return const SizedBox.shrink();
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text("Team Members (Max ${maxTeamSize - 1} more)",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.5)),
                ),
                if (_selectedTeamMembers.length < maxTeamSize - 1 && !_isLoadingStudents)
                  IconButton(
                    icon: const Icon(Icons.add_circle_rounded, color: Colors.blue, size: 28),
                    onPressed: _collegeStudents.isEmpty ? null : _showAddMemberDialog,
                  )
              ],
            ),
            const SizedBox(height: 4),
            Text("Invite teammates from your college.",
              style: TextStyle(fontSize: 12, color: Colors.grey.withOpacity(0.8))),
            const SizedBox(height: 20),
            if (_isLoadingStudents)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            ...List.generate(_selectedTeamMembers.length, (index) {
              final member = _selectedTeamMembers[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Text((member['name'] ?? '?')[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  title: Text(member['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  subtitle: Text(member['email'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 22),
                    onPressed: () => setState(() => _selectedTeamMembers.removeAt(index)),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, bool isRequired = true}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.2),
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          labelStyle: TextStyle(fontSize: 13, color: Colors.grey.withOpacity(0.8), fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, size: 22, color: Colors.blueAccent.withOpacity(0.7)),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.blueAccent.withOpacity(0.5), width: 1.5),
          ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildRegisterTypeCard(String volunteerCount, String? volunteerRole) {
    final String? roleText = (volunteerRole != null && volunteerRole.trim().isNotEmpty) ? volunteerRole.trim() : null;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.how_to_reg_rounded, size: 22, color: Colors.blue),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text("Registration Type",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _RegisterTypePill(
                      label: "Participant",
                      icon: Icons.person_rounded,
                      isSelected: _registrationType == 'participant',
                      onTap: () => setState(() => _registrationType = 'participant'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RegisterTypePill(
                      label: "Volunteer",
                      icon: Icons.volunteer_activism_rounded,
                      isSelected: _registrationType == 'volunteer',
                      onTap: () => setState(() => _registrationType = 'volunteer'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.volunteer_activism_rounded, size: 20, color: Colors.blue),
                  const SizedBox(width: 10),
                  Text(
                    volunteerCount.isNotEmpty ? "Volunteers Needed: $volunteerCount" : "Volunteers Needed",
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (roleText != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt_rounded, size: 20, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text("Role: $roleText",
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
    required this.label, required this.icon, required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [
            BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey.withOpacity(0.8)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: isSelected ? Colors.white : Colors.grey.withOpacity(0.8), fontWeight: FontWeight.w900, fontSize: 13)),
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
