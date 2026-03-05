import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventRegistrationScreen extends StatefulWidget {
  final DocumentSnapshot event;

  const EventRegistrationScreen({super.key, required this.event});

  @override
  State<EventRegistrationScreen> createState() =>
      _EventRegistrationScreenState();
}

class _EventRegistrationScreenState extends State<EventRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = true;
  bool isSubmitting = false;
  Map<String, dynamic>? studentData;
  String _registrationType = 'participant';
  final List<_StudentOption> _selectedTeammates = [];

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
      var doc = await FirebaseFirestore.instance
          .collection('student')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        doc = await FirebaseFirestore.instance
            .collection('faculty')
            .doc(user.uid)
            .get();
      }

      if (doc.exists) {
        studentData = doc.data() as Map<String, dynamic>;
        _nameController = TextEditingController(text: studentData?['name'] ?? '');
        _phoneController = TextEditingController(text: studentData?['phone'] ?? '');
        _deptController = TextEditingController(text: studentData?['department'] ?? '');
        _yearController = TextEditingController(text: studentData?['year']?.toString() ?? '');
        _semController = TextEditingController(text: studentData?['semester']?.toString() ?? '');
        _ktuIdController = TextEditingController(text: studentData?['ktuId'] ?? '');
      } else {
        _nameController = TextEditingController();
        _phoneController = TextEditingController();
        _deptController = TextEditingController();
        _yearController = TextEditingController();
        _semController = TextEditingController();
        _ktuIdController = TextEditingController();
      }
    }
    if (mounted) {
      setState(() => isLoading = false);
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

    setState(() => isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final updatedData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'department': _deptController.text.trim(),
        'year': _yearController.text.trim(),
        'semester': _semController.text.trim(),
        'ktuId': _ktuIdController.text.trim().toUpperCase(),
      };

      final bool isTeamEvent = (widget.event['isTeamEvent'] ?? false) == true;
      final int teamSize = int.tryParse((widget.event['teamSize'] ?? '').toString()) ?? 0;
      final bool shouldRegisterAsTeam = isTeamEvent && _registrationType == 'participant';

      if (shouldRegisterAsTeam) {
        final requiredMateCount = teamSize - 1;
        if (_selectedTeammates.length != requiredMateCount) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select exactly $requiredMateCount teammates.')));
          setState(() => isSubmitting = false);
          return;
        }
      }

      final List<String> finalMemberIds = [user.uid, ..._selectedTeammates.map((e) => e.uid)];

      for (final memberId in finalMemberIds) {
        final existingReg = await FirebaseFirestore.instance
            .collection('registrations')
            .where('userId', isEqualTo: memberId)
            .where('eventId', isEqualTo: widget.event.id)
            .limit(1).get();

        if (existingReg.docs.isNotEmpty) {
          final existingData = existingReg.docs.first.data();
          final memberName = (existingData['studentName'] ?? 'A selected member').toString();
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Already Registered'),
                content: Text('$memberName is already registered for this event.'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
              ),
            );
          }
          setState(() => isSubmitting = false);
          return;
        }
      }

      await FirebaseFirestore.instance.collection('student').doc(user.uid).set(updatedData, SetOptions(merge: true));

      final List<Map<String, dynamic>> teamMembersPayload = shouldRegisterAsTeam
          ? [
              {'userId': user.uid, 'name': updatedData['name'], 'email': user.email ?? ''},
              ..._selectedTeammates.map((m) => {'userId': m.uid, 'name': m.name, 'email': m.email}),
            ]
          : [];
      
      final String? teamId = shouldRegisterAsTeam ? FirebaseFirestore.instance.collection('registrations').doc().id : null;
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      final captainDoc = FirebaseFirestore.instance.collection('registrations').doc();
      batch.set(captainDoc, {
        'userId': user.uid,
        'eventId': widget.event.id,
        'eventTitle': widget.event['title'] ?? 'Untitled Event',
        'studentName': updatedData['name'],
        'studentEmail': user.email,
        'studentPhone': updatedData['phone'],
        'department': updatedData['department'],
        'year': updatedData['year'],
        'semester': updatedData['semester'],
        'ktuId': updatedData['ktuId'],
        'registrationType': _registrationType,
        'registeredAt': FieldValue.serverTimestamp(),
        'isTeamEvent': shouldRegisterAsTeam,
        'teamId': teamId,
        'teamSize': shouldRegisterAsTeam ? teamSize : null,
        'isTeamLeader': shouldRegisterAsTeam,
        'teamMembers': teamMembersPayload,
        'status': 'confirmed', // Leader is auto-confirmed
      });

      if (shouldRegisterAsTeam) {
        for (final mate in _selectedTeammates) {
          final memberDoc = FirebaseFirestore.instance.collection('registrations').doc();
          batch.set(memberDoc, {
            'userId': mate.uid,
            'eventId': widget.event.id,
            'eventTitle': widget.event['title'] ?? 'Untitled Event',
            'studentName': mate.name,
            'studentEmail': mate.email,
            'studentPhone': mate.phone,
            'department': mate.department,
            'year': mate.year,
            'semester': mate.semester,
            'ktuId': mate.ktuId.toUpperCase(),
            'registrationType': 'participant',
            'registeredAt': FieldValue.serverTimestamp(),
            'isTeamEvent': true,
            'teamId': teamId,
            'teamSize': teamSize,
            'isTeamLeader': false,
            'teamMembers': teamMembersPayload,
            'status': 'pending', // Teammates are pending until confirmation
          });

          final notificationDoc = FirebaseFirestore.instance
              .collection('student')
              .doc(mate.uid)
              .collection('notifications')
              .doc();
          batch.set(notificationDoc, {
            'title': 'New Team Invitation',
            'message': '${updatedData['name']} added you to their team for ${widget.event['title'] ?? 'the event'}.',
            'type': 'team_invite',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'eventId': widget.event.id,
            'regId': memberDoc.id, // Link to the specific registration for confirmation
          });
        }
      }

      await batch.commit();

      await FirebaseFirestore.instance.collection('events').doc(widget.event.id).update({
        'filledSeats': FieldValue.increment(shouldRegisterAsTeam ? teamSize : 1),
      });

      if (_registrationType == 'volunteer') {
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final eventRef = FirebaseFirestore.instance.collection('events').doc(widget.event.id);
          final snap = await tx.get(eventRef);
          final current = int.tryParse(snap.data()?['volunteerCount']?.toString() ?? '0') ?? 0;
          tx.update(eventRef, {'volunteerCount': current > 0 ? current - 1 : 0});
        });
      }

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 16),
                const Text('Registration Successful!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('You and your team have been successfully registered for\n${widget.event['title']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4B3CC9), foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context), 
                  child: const Text('OK'),
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
    final bool requiresVolunteers = (widget.event['requiresVolunteers'] ?? false) == true;
    final bool isTeamEvent = (widget.event['isTeamEvent'] ?? false) == true;
    final int teamSize = int.tryParse((widget.event['teamSize'] ?? '').toString()) ?? 0;
    final bool showTeamSection = isTeamEvent && _registrationType == 'participant';

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Details')),
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
                      _buildRegisterTypeCard(),
                      const SizedBox(height: 20),
                    ],
                    if (showTeamSection) ...[
                      _buildTeamSelectionCard(teamSize),
                      const SizedBox(height: 20),
                    ],
                    const Text("Confirm your details for registration.", style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 24),
                    _buildTextField(_nameController, "Full Name", Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildTextField(_phoneController, "Phone", Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildTextField(_deptController, "Department", Icons.business_outlined),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_yearController, "Year", Icons.calendar_today_outlined, keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_semController, "Sem", Icons.format_list_numbered_outlined, keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(_ktuIdController, "KTU ID", Icons.badge_outlined, inputFormatters: [UpperCaseTextFormatter()]),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4B3CC9), foregroundColor: Colors.white),
                        onPressed: isSubmitting ? null : _handleRegistration,
                        child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("Confirm & Register"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(labelText: '$label *', prefixIcon: Icon(icon), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      validator: (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null,
    );
  }

  Widget _buildTeamSelectionCard(int teamSize) {
    final int requiredMateCount = teamSize - 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE3E7F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.groups_rounded, color: const Color(0xFF4B3CC9)), const SizedBox(width: 8), const Text('Team Registration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
          const SizedBox(height: 8),
          Text('Select $requiredMateCount teammates from your college.', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openTeammateSelector,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(_selectedTeammates.isEmpty ? 'Choose Teammates' : 'Selected ${_selectedTeammates.length}/$requiredMateCount'),
            ),
          ),
          if (_selectedTeammates.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _selectedTeammates.map((m) => Chip(
                label: Text(m.name),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(() => _selectedTeammates.removeWhere((e) => e.uid == m.uid)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openTeammateSelector() async {
    final int teamSize = int.tryParse((widget.event['teamSize'] ?? '').toString()) ?? 0;
    final int requiredMateCount = teamSize - 1;
    final String myCollege = (studentData?['college'] ?? '').toString().trim();
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    List<_StudentOption> workingSelection = List<_StudentOption>.from(_selectedTeammates);
    String search = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Choose Teammates (${workingSelection.length}/$requiredMateCount)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
                  ],
                ),
                TextField(
                  decoration: const InputDecoration(hintText: 'Search by name', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setSheetState(() => search = v),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('student')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      // 🔹 Robust filtering: Case-insensitive, exclude members already in teams
                      final candidates = (snapshot.data?.docs ?? [])
                          .where((doc) {
                            if (doc.id == currentUserId) return false;
                            final data = doc.data() as Map<String, dynamic>;
                            final college = (data['college'] ?? '').toString().trim().toLowerCase();
                            return college == myCollege.toLowerCase();
                          })
                          .map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return _StudentOption(
                              uid: doc.id,
                              name: (data['name'] ?? '').toString(),
                              email: (data['email'] ?? '').toString(),
                              college: (data['college'] ?? '').toString(),
                              phone: (data['phone'] ?? '').toString(),
                              department: (data['department'] ?? '').toString(),
                              year: (data['year'] ?? '').toString(),
                              semester: (data['semester'] ?? '').toString(),
                              ktuId: (data['ktuId'] ?? '').toString(),
                            );
                          })
                          .where((s) {
                            final q = search.toLowerCase();
                            return s.name.toLowerCase().contains(q);
                          })
                          .toList()
                        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                      if (candidates.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                search.isEmpty ? "No other students found in your college." : "No students match your search.",
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final s = candidates[index];
                          final isSelected = workingSelection.any((e) => e.uid == s.uid);
                          return CheckboxListTile(
                            activeColor: const Color(0xFF4B3CC9),
                            value: isSelected,
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            onChanged: (val) {
                              setSheetState(() {
                                if (val == true) {
                                  if (!isSelected && workingSelection.length < requiredMateCount) {
                                    workingSelection.add(s);
                                  }
                                } else {
                                  workingSelection.removeWhere((e) => e.uid == s.uid);
                                }
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4B3CC9), foregroundColor: Colors.white),
                    onPressed: () {
                      setState(() {
                        _selectedTeammates.clear();
                        _selectedTeammates.addAll(workingSelection);
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Confirm Selection'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRegisterTypeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE6E9F2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Register As", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _RegisterTypePill(label: "Participant", icon: Icons.person_outline, isSelected: _registrationType == 'participant', onTap: () => setState(() => _registrationType = 'participant'))),
              const SizedBox(width: 8),
              Expanded(child: _RegisterTypePill(label: "Volunteer", icon: Icons.volunteer_activism_outlined, isSelected: _registrationType == 'volunteer', onTap: () => setState(() { _registrationType = 'volunteer'; _selectedTeammates.clear(); }))),
            ],
          ),
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
  const _RegisterTypePill({required this.label, required this.icon, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4B3CC9) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF4B3CC9) : const Color(0xFFE3E7F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _StudentOption {
  final String uid, name, email, college, phone, department, year, semester, ktuId;
  const _StudentOption({required this.uid, required this.name, required this.email, required this.college, required this.phone, required this.department, required this.year, required this.semester, required this.ktuId});
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) => TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
}
