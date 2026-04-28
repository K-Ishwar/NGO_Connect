import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:confetti/confetti.dart';

class RegisterVolunteerScreen extends StatefulWidget {
  const RegisterVolunteerScreen({super.key});

  @override
  State<RegisterVolunteerScreen> createState() =>
      _RegisterVolunteerScreenState();
}

class _RegisterVolunteerScreenState extends State<RegisterVolunteerScreen> {
  final _formKey = GlobalKey<FormState>();
  final Color baseColor = const Color(0xFFF2F2F2);

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _customSkillCtrl = TextEditingController();

  String _availability = 'Part-time';
  bool _isLoading = false;
  int _currentStep = 0;
  late ConfettiController _confettiController;

  final _availOptions = ['Full-time', 'Part-time', 'Weekends only'];

  final _allSkills = [
    'Medical / First Aid',
    'Nursing',
    'Doctor',
    'Logistics / Transport',
    'Teaching / Education',
    'Coordination',
    'Cooking / Food Prep',
    'Construction',
    'Counselling',
    'Social Work',
    'IT / Tech',
    'Language / Interpreter',
  ];
  final Set<String> _selectedSkills = {};

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _expCtrl.dispose();
    _customSkillCtrl.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  String _generateTempPassword() {
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final last4 = phone.length >= 4
        ? phone.substring(phone.length - 4)
        : '1234';
    return 'NGO@$last4';
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      if (_selectedSkills.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one skill.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() => _currentStep++);
    } else {
      _register();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _addCustomSkill() {
    final skill = _customSkillCtrl.text.trim();
    if (skill.isNotEmpty) {
      setState(() {
        if (!_allSkills.contains(skill)) _allSkills.add(skill);
        _selectedSkills.add(skill);
        _customSkillCtrl.clear();
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSkills.isEmpty) return;

    setState(() => _isLoading = true);

    final email = _emailCtrl.text.trim();
    final tempPassword = _generateTempPassword();
    final ngoId = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      // Store in 'pending_volunteers' — when the volunteer self-registers with
      // this email, their profile gets merged. No Firebase Auth call needed here,
      // which avoids signing out the current NGO session.
      await FirebaseFirestore.instance
          .collection('pending_volunteers')
          .doc(email)
          .set({
            'name': _nameCtrl.text.trim(),
            'email': email,
            'suggested_password': tempPassword,
            'phone_number': _phoneCtrl.text.trim(),
            'location': _locationCtrl.text.trim(),
            'skills': _selectedSkills.toList(),
            'availability': _availability,
            'experience_years': int.tryParse(_expCtrl.text) ?? 0,
            'role': 'volunteer',
            'ngo_registered_by': ngoId,
            'registered_at': DateTime.now().toIso8601String(),
            'status': 'pending', // Becomes 'active' after volunteer logs in
          });

      if (!mounted) return;
      setState(() => _isLoading = false);
      _confettiController.play();
      _showSuccessDialog(
        name: _nameCtrl.text.trim(),
        email: email,
        password: tempPassword,
        phone: _phoneCtrl.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessDialog({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 8),
            Text(
              'Volunteer Registered!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share these credentials with the volunteer:',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _credRow('Name', name),
            _credRow('Email (Login)', email),
            _credRow('Password', password),
            const SizedBox(height: 4),
            const Text(
              '⚠️ Volunteer should change their password after first login.',
              style: TextStyle(color: Colors.orange, fontSize: 11),
            ),
          ],
        ),
        actions: [
          // Copy button
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: 'Login: $email\nPassword: $password'),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Credentials copied!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          // WhatsApp share
          if (phone.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 16),
              label: const Text(
                'WhatsApp',
                style: TextStyle(color: Color(0xFF25D366)),
              ),
              onPressed: () async {
                final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
                final msg = Uri.encodeComponent(
                  'Hello $name! 🎗️\n\nYou have been registered as a volunteer on NGO Connect.\n\n'
                  '📧 Email: $email\n🔑 Password: $password\n\n'
                  'Download the app and login to get started. Please change your password after first login.',
                );
                final url = Uri.parse('https://wa.me/$clean?text=$msg');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8A2387),
            ),
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _credRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 85,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: baseColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8A2387), Color(0xFFE94057)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x44E94057),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_add,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Register Volunteer',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Add a volunteer to your team',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF2F2F2),
                  const Color(0xFFE6E6FA).withValues(alpha: 0.5),
                  const Color(0xFFF2F2F2),
                ],
              ),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: Stepper(
                      type: StepperType.horizontal,
                      currentStep: _currentStep,
                      onStepContinue: _nextStep,
                      onStepCancel: _prevStep,
                      onStepTapped: (step) =>
                          setState(() => _currentStep = step),
                      controlsBuilder: (context, details) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: _isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF8A2387),
                                        ),
                                      )
                                    : ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF8A2387,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        onPressed: details.onStepContinue,
                                        child: Text(
                                          _currentStep == 2
                                              ? 'REGISTER VOLUNTEER'
                                              : 'NEXT STEP',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              ),
                              if (_currentStep > 0 && !_isLoading) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFF8A2387),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: details.onStepCancel,
                                    child: const Text(
                                      'BACK',
                                      style: TextStyle(
                                        color: Color(0xFF8A2387),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                      steps: [
                        Step(
                          title: const Text(
                            'Personal',
                            style: TextStyle(fontSize: 12),
                          ),
                          isActive: _currentStep >= 0,
                          state: _currentStep > 0
                              ? StepState.complete
                              : StepState.indexed,
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _clayInput(
                                _nameCtrl,
                                'Full Name *',
                                Icons.person,
                                validator: (v) =>
                                    v == null || v.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 16),
                              _clayInput(
                                _emailCtrl,
                                'Email Address *',
                                Icons.email,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  if (!v.contains('@')) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _clayInput(
                                _phoneCtrl,
                                'Phone Number *',
                                Icons.phone,
                                keyboardType: TextInputType.phone,
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Required (used for temp password)'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        Step(
                          title: const Text(
                            'Skills',
                            style: TextStyle(fontSize: 12),
                          ),
                          isActive: _currentStep >= 1,
                          state: _currentStep > 1
                              ? StepState.complete
                              : StepState.indexed,
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _clayInput(
                                _locationCtrl,
                                'Area / Location',
                                Icons.location_on,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Select Skills',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _allSkills.map((skill) {
                                  final selected = _selectedSkills.contains(
                                    skill,
                                  );
                                  return FilterChip(
                                    label: Text(
                                      skill,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: selected
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    selected: selected,
                                    selectedColor: const Color(0xFF8A2387),
                                    checkmarkColor: Colors.white,
                                    onSelected: (val) {
                                      setState(() {
                                        if (val) {
                                          _selectedSkills.add(skill);
                                        } else {
                                          _selectedSkills.remove(skill);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _clayInput(
                                      _customSkillCtrl,
                                      'Add Custom Skill',
                                      Icons.add_circle_outline,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check,
                                      color: Colors.green,
                                    ),
                                    onPressed: _addCustomSkill,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Step(
                          title: const Text(
                            'Availability',
                            style: TextStyle(fontSize: 12),
                          ),
                          isActive: _currentStep >= 2,
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _clayInput(
                                _expCtrl,
                                'Years of Experience',
                                Icons.workspace_premium,
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                initialValue: _availability,
                                decoration: InputDecoration(
                                  labelText: 'Availability',
                                  prefixIcon: const Icon(
                                    Icons.access_time,
                                    color: Color(0xFF8A2387),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                items: _availOptions
                                    .map(
                                      (a) => DropdownMenuItem(
                                        value: a,
                                        child: Text(a),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _availability = v!),
                              ),
                              const SizedBox(height: 16),
                              ClayContainer(
                                color: baseColor,
                                borderRadius: 16,
                                depth: 15,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(
                                          0xFF8A2387,
                                        ).withValues(alpha: 0.1),
                                        const Color(
                                          0xFFE94057,
                                        ).withValues(alpha: 0.08),
                                      ],
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Color(0xFF8A2387),
                                        size: 20,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'A temporary password will be auto-generated. Share it with the volunteer so they can log in.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clayInput(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return ClayContainer(
      color: baseColor,
      borderRadius: 14,
      depth: -18,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            border: InputBorder.none,
            labelText: label,
            prefixIcon: Icon(icon, color: const Color(0xFF8A2387)),
          ),
        ),
      ),
    );
  }
}
