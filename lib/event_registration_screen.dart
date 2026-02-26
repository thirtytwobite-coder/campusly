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
  bool _isLoadingTeammates = false;
  final List<_StudentOption> _teamCandidates = [];
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
      final doc = await FirebaseFirestore.instance
          .collection('student')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        studentData = doc.data() as Map<String, dynamic>;
        _nameController = TextEditingController(
          text: studentData?['name'] ?? '',
        );
        _phoneController = TextEditingController(
          text: studentData?['phone'] ?? '',
        );
        _deptController = TextEditingController(
          text: studentData?['department'] ?? '',
        );
        _yearController = TextEditingController(
          text: studentData?['year']?.toString() ?? '',
        );
        _semController = TextEditingController(
          text: studentData?['semester']?.toString() ?? '',
        );
        _ktuIdController = TextEditingController(
          text: studentData?['ktuId'] ?? '',
        );
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
    await _loadTeamCandidates();
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadTeamCandidates() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final eventData = widget.event.data() as Map<String, dynamic>? ?? {};
    final bool isCollegeOnly =
        (eventData['visibility'] ?? 'public').toString().toLowerCase() ==
        'college';
    final String eventCollege = (eventData['college'] ?? '').toString().trim();
    final String myCollege = (studentData?['college'] ?? '').toString().trim();

    setState(() => _isLoadingTeammates = true);
    try {
      Query query = FirebaseFirestore.instance.collection('student');
      if (isCollegeOnly) {
        final collegeFilter = eventCollege.isNotEmpty
            ? eventCollege
            : myCollege;
        if (collegeFilter.isNotEmpty) {
          query = query.where('college', isEqualTo: collegeFilter);
        }
      }

      final snapshot = await query.get();
      final candidates =
          snapshot.docs
              .where((doc) => doc.id != user.uid)
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
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
              .where((s) => s.name.trim().isNotEmpty)
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      _teamCandidates
        ..clear()
        ..addAll(candidates);
    } finally {
      if (mounted) {
        setState(() => _isLoadingTeammates = false);
      }
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

      final updatedData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'department': _deptController.text.trim(),
        'year': _yearController.text.trim(),
        'semester': _semController.text.trim(),
        'ktuId': _ktuIdController.text.trim().toUpperCase(),
      };

      final bool requiresVolunteers =
          (widget.event['requiresVolunteers'] ?? false) == true;
      final String regType = requiresVolunteers
          ? _registrationType
          : 'participant';
      final bool isTeamEvent = (widget.event['isTeamEvent'] ?? false) == true;
      final int teamSize =
          int.tryParse((widget.event['teamSize'] ?? '').toString()) ?? 0;
      final bool shouldRegisterAsTeam = isTeamEvent && regType == 'participant';

      if (shouldRegisterAsTeam) {
        final requiredMateCount = teamSize - 1;
        if (requiredMateCount <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid team size configured for this event.'),
              ),
            );
          }
          return;
        }
        if (_selectedTeammates.length != requiredMateCount) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Select exactly $requiredMateCount teammates to continue.',
                ),
              ),
            );
          }
          return;
        }
      }

      final List<_StudentOption> finalMembers = shouldRegisterAsTeam
          ? [for (final m in _selectedTeammates) m]
          : const [];
      final List<String> finalMemberIds = [
        user.uid,
        ...finalMembers.map((e) => e.uid),
      ];

      for (final memberId in finalMemberIds) {
        final existingReg = await FirebaseFirestore.instance
            .collection('registrations')
            .where('userId', isEqualTo: memberId)
            .where('eventId', isEqualTo: widget.event.id)
            .limit(1)
            .get();

        if (existingReg.docs.isNotEmpty) {
          final existingData = existingReg.docs.first.data();
          final memberName =
              (existingData['studentName'] ?? 'A selected member').toString();
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Already Registered'),
                content: Text(
                  '$memberName is already registered for this event.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }

      await FirebaseFirestore.instance
          .collection('student')
          .doc(user.uid)
          .set(updatedData, SetOptions(merge: true));

      final List<Map<String, dynamic>> teamMembersPayload = shouldRegisterAsTeam
          ? [
              {
                'userId': user.uid,
                'name': updatedData['name'],
                'email': user.email ?? '',
              },
              ...finalMembers.map(
                (m) => {'userId': m.uid, 'name': m.name, 'email': m.email},
              ),
            ]
          : [];
      final String? teamId = shouldRegisterAsTeam
          ? FirebaseFirestore.instance.collection('registrations').doc().id
          : null;

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      final captainDoc = FirebaseFirestore.instance
          .collection('registrations')
          .doc();
      batch.set(captainDoc, {
        'userId': user.uid,
        'eventId': widget.event.id,
        'eventTitle':
            widget.event['title'] ?? widget.event['name'] ?? 'Untitled Event',
        'studentName': updatedData['name'],
        'studentEmail': user.email,
        'studentPhone': updatedData['phone'],
        'department': updatedData['department'],
        'year': updatedData['year'],
        'semester': updatedData['semester'],
        'ktuId': updatedData['ktuId'],
        'registrationType': regType,
        'registeredAt': FieldValue.serverTimestamp(),
        'isTeamEvent': shouldRegisterAsTeam,
        'teamId': teamId,
        'teamSize': shouldRegisterAsTeam ? teamSize : null,
        'isTeamLeader': shouldRegisterAsTeam,
        'teamMembers': shouldRegisterAsTeam ? teamMembersPayload : null,
      });

      if (shouldRegisterAsTeam) {
        for (final mate in finalMembers) {
          final memberDoc = FirebaseFirestore.instance
              .collection('registrations')
              .doc();
          batch.set(memberDoc, {
            'userId': mate.uid,
            'eventId': widget.event.id,
            'eventTitle':
                widget.event['title'] ??
                widget.event['name'] ??
                'Untitled Event',
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
          });
        }
      }

      await batch.commit();

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .update({
            'filledSeats': FieldValue.increment(
              shouldRegisterAsTeam ? teamSize : 1,
            ),
          });

      if (regType == 'volunteer') {
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final eventRef = FirebaseFirestore.instance
              .collection('events')
              .doc(widget.event.id);
          final snap = await tx.get(eventRef);
          final data = snap.data() ?? <String, dynamic>{};
          final int current = (data['volunteerCount'] is int)
              ? data['volunteerCount']
              : int.tryParse(data['volunteerCount']?.toString() ?? '') ?? 0;
          final int next = current > 0 ? current - 1 : 0;
          tx.update(eventRef, {'volunteerCount': next});
        });
      }

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
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
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  shouldRegisterAsTeam
                      ? 'Team Registration Successful!'
                      : 'Registration Successful!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  shouldRegisterAsTeam
                      ? 'Your team has been registered for\n${widget.event['title'] ?? widget.event['name'] ?? 'Untitled Event'}'
                      : 'You have successfully registered for\n${widget.event['title'] ?? widget.event['name'] ?? 'Untitled Event'}',
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('OK', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );

        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    final bool requiresVolunteers =
        (widget.event['requiresVolunteers'] ?? false) == true;
    final String? volunteerRole = widget.event['volunteerRole']?.toString();
    final String volunteerCount = (widget.event['volunteerCount'] ?? '')
        .toString();
    final bool isTeamEvent = (widget.event['isTeamEvent'] ?? false) == true;
    final int teamSize =
        int.tryParse((widget.event['teamSize'] ?? '').toString()) ?? 0;
    final bool showTeamSection =
        isTeamEvent && _registrationType == 'participant';

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
                      _buildRegisterTypeCard(volunteerCount, volunteerRole),
                      const SizedBox(height: 20),
                    ],
                    if (showTeamSection) ...[
                      _buildTeamSelectionCard(teamSize),
                      const SizedBox(height: 20),
                    ],
                    const Text(
                      "Please review and confirm your details for registration.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      _nameController,
                      "Full Name",
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _phoneController,
                      "Phone Number",
                      Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _deptController,
                      "Department",
                      Icons.business_outlined,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _yearController,
                            "Year",
                            Icons.calendar_today_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            _semController,
                            "Semester",
                            Icons.format_list_numbered_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _ktuIdController,
                      "KTU ID",
                      Icons.badge_outlined,
                      inputFormatters: [UpperCaseTextFormatter()],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : _handleRegistration,
                        child: isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Confirm & Register",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool isRequired = true,
  }) {
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

  Widget _buildTeamSelectionCard(int teamSize) {
    final int requiredMateCount = teamSize - 1;
    final bool validTeamSize = requiredMateCount > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E7F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, color: Color(0xFF4B3CC9)),
              const SizedBox(width: 8),
              Text(
                'Team Registration',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            validTeamSize
                ? 'Select exactly $requiredMateCount teammates (Team size: $teamSize).'
                : 'Invalid team size configured for this event.',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (!validTeamSize || _isLoadingTeammates)
                  ? null
                  : _openTeammateSelector,
              icon: _isLoadingTeammates
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded),
              label: Text(
                _selectedTeammates.isEmpty
                    ? 'Choose Teammates'
                    : 'Selected ${_selectedTeammates.length}/$requiredMateCount',
              ),
            ),
          ),
          if (_selectedTeammates.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedTeammates
                  .map(
                    (m) => Chip(
                      label: Text(m.name),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(
                        () => _selectedTeammates.removeWhere(
                          (e) => e.uid == m.uid,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openTeammateSelector() async {
    final int teamSize =
        int.tryParse((widget.event['teamSize'] ?? '').toString()) ?? 0;
    final int requiredMateCount = teamSize - 1;
    if (requiredMateCount <= 0) return;

    final List<_StudentOption> workingSelection = List<_StudentOption>.from(
      _selectedTeammates,
    );
    String search = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = _teamCandidates.where((s) {
              final q = search.toLowerCase();
              return s.name.toLowerCase().contains(q) ||
                  s.email.toLowerCase().contains(q);
            }).toList();

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Select Teammates (${workingSelection.length}/$requiredMateCount)',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by name or email',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setSheetState(() => search = value),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final student = filtered[index];
                          final selected = workingSelection.any(
                            (e) => e.uid == student.uid,
                          );
                          return CheckboxListTile(
                            value: selected,
                            title: Text(student.name),
                            subtitle: Text(
                              student.email.isNotEmpty
                                  ? student.email
                                  : (student.college.isNotEmpty
                                        ? student.college
                                        : 'Student'),
                            ),
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  if (!selected &&
                                      workingSelection.length <
                                          requiredMateCount) {
                                    workingSelection.add(student);
                                  }
                                } else {
                                  workingSelection.removeWhere(
                                    (e) => e.uid == student.uid,
                                  );
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedTeammates
                              ..clear()
                              ..addAll(workingSelection);
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Save Selection'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRegisterTypeCard(String volunteerCount, String? volunteerRole) {
    final String? roleText =
        (volunteerRole != null && volunteerRole.trim().isNotEmpty)
        ? volunteerRole.trim()
        : null;

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
                child: const Icon(
                  Icons.how_to_reg_outlined,
                  size: 20,
                  color: Color(0xFF4B3CC9),
                ),
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
                    onTap: () =>
                        setState(() => _registrationType = 'participant'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RegisterTypePill(
                    label: "Volunteer",
                    icon: Icons.volunteer_activism_outlined,
                    isSelected: _registrationType == 'volunteer',
                    onTap: () => setState(() {
                      _registrationType = 'volunteer';
                      _selectedTeammates.clear();
                    }),
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
                const Icon(
                  Icons.volunteer_activism_outlined,
                  size: 18,
                  color: Color(0xFF2B6CB0),
                ),
                const SizedBox(width: 8),
                Text(
                  volunteerCount.isNotEmpty
                      ? "Volunteers Needed: $volunteerCount"
                      : "Volunteers Needed",
                  style: const TextStyle(
                    color: Color(0xFF2B6CB0),
                    fontWeight: FontWeight.w600,
                  ),
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
                  const Icon(
                    Icons.list_alt_outlined,
                    size: 18,
                    color: Color(0xFFB7791F),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Role: $roleText",
                      style: const TextStyle(
                        color: Color(0xFFB7791F),
                        fontWeight: FontWeight.w600,
                      ),
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
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4B3CC9)
                : const Color(0xFFE3E7F0),
          ),
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
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : const Color(0xFF667085),
            ),
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

class _StudentOption {
  final String uid;
  final String name;
  final String email;
  final String college;
  final String phone;
  final String department;
  final String year;
  final String semester;
  final String ktuId;

  const _StudentOption({
    required this.uid,
    required this.name,
    required this.email,
    required this.college,
    required this.phone,
    required this.department,
    required this.year,
    required this.semester,
    required this.ktuId,
  });
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
