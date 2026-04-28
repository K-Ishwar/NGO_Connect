import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class RegisterVolunteerScreen extends StatefulWidget {
  const RegisterVolunteerScreen({super.key});

  @override
  State<RegisterVolunteerScreen> createState() => _RegisterVolunteerScreenState();
}

class _RegisterVolunteerScreenState extends State<RegisterVolunteerScreen> {
  final _formKey = GlobalKey<FormState>();
  final Color baseColor = const Color(0xFFF2F2F2);

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _expCtrl = TextEditingController();

  String _availability = 'Part-time';
  bool _isLoading = false;

  final _availOptions = ['Full-time', 'Part-time', 'Weekends only'];

  final _allSkills = [
    'Medical / First Aid', 'Nursing', 'Doctor', 'Logistics / Transport',
    'Teaching / Education', 'Coordination', 'Cooking / Food Prep',
    'Construction', 'Counselling', 'Social Work', 'IT / Tech', 'Language / Interpreter',
  ];
  final Set<String> _selectedSkills = {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _expCtrl.dispose();
    super.dispose();
  }

  String _generateTempPassword() {
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final last4 = phone.length >= 4 ? phone.substring(phone.length - 4) : '1234';
    return 'NGO@$last4';
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one skill.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final email = _emailCtrl.text.trim();
    final tempPassword = _generateTempPassword();
    final ngoId = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      // Store in 'pending_volunteers' — when the volunteer self-registers with
      // this email, their profile gets merged. No Firebase Auth call needed here,
      // which avoids signing out the current NGO session.
      await FirebaseFirestore.instance.collection('pending_volunteers').doc(email).set({
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
            Text('Volunteer Registered!', textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share these credentials with the volunteer:',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            _credRow('Name', name),
            _credRow('Email (Login)', email),
            _credRow('Password', password),
            const SizedBox(height: 4),
            const Text('⚠️ Volunteer should change their password after first login.',
                style: TextStyle(color: Colors.orange, fontSize: 11)),
          ],
        ),
        actions: [
          // Copy button
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: 'Login: $email\nPassword: $password',
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Credentials copied!'), duration: Duration(seconds: 2)),
              );
            },
          ),
          // WhatsApp share
          if (phone.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 16),
              label: const Text('WhatsApp', style: TextStyle(color: Color(0xFF25D366))),
              onPressed: () async {
                final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
                final msg = Uri.encodeComponent(
                  'Hello $name! 🎗️\n\nYou have been registered as a volunteer on NGO Connect.\n\n'
                  '📧 Email: $email\n🔑 Password: $password\n\n'
                  'Download the app and login to get started. Please change your password after first login.',
                );
                final url = Uri.parse('https://wa.me/$clean?text=$msg');
                if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
              },
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8A2387)),
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
          SizedBox(width: 85, child: Text('$label:', style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
            boxShadow: [BoxShadow(color: Color(0x44E94057), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Register Volunteer',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Add a volunteer to your team',
                          style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [const Color(0xFFF2F2F2), const Color(0xFFE6E6FA).withOpacity(0.5), const Color(0xFFF2F2F2)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner
                ClayContainer(
                  color: baseColor, borderRadius: 16, depth: 15,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [const Color(0xFF8A2387).withOpacity(0.1), const Color(0xFFE94057).withOpacity(0.08)],
                      ),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF8A2387), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'A temporary password will be auto-generated. Share it with the volunteer so they can log in.',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Personal Details ──────────────────────────
                _sectionLabel('👤 Personal Details'),
                _clayInput(_nameCtrl, 'Full Name *', Icons.person,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                const SizedBox(height: 10),
                _clayInput(_emailCtrl, 'Email Address *', Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    }),
                const SizedBox(height: 10),
                _clayInput(_phoneCtrl, 'Phone Number *', Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.isEmpty ? 'Required (used for temp password)' : null),
                const SizedBox(height: 20),

                // ── Location & Experience ─────────────────────
                _sectionLabel('📍 Location & Experience'),
                _clayInput(_locationCtrl, 'Area / Location', Icons.location_on),
                const SizedBox(height: 10),
                _clayInput(_expCtrl, 'Years of Experience', Icons.workspace_premium,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 10),

                // Availability
                ClayContainer(
                  color: baseColor, borderRadius: 14, depth: -18,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: DropdownButtonFormField<String>(
                      value: _availability,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        labelText: 'Availability',
                        prefixIcon: Icon(Icons.access_time, color: Color(0xFF8A2387)),
                      ),
                      items: _availOptions
                          .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                          .toList(),
                      onChanged: (v) => setState(() => _availability = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Skills ────────────────────────────────────
                _sectionLabel('🎯 Skills (Select all that apply)'),
                const SizedBox(height: 8),
                ClayContainer(
                  color: baseColor, borderRadius: 14, depth: 15,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _allSkills.map((skill) {
                        final selected = _selectedSkills.contains(skill);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (selected) _selectedSkills.remove(skill);
                            else _selectedSkills.add(skill);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)])
                                  : null,
                              color: selected ? null : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? Colors.transparent : Colors.grey.shade300,
                              ),
                              boxShadow: selected
                                  ? [BoxShadow(color: const Color(0xFFE94057).withOpacity(0.25),
                                      blurRadius: 6, offset: const Offset(0, 3))]
                                  : [],
                            ),
                            child: Text(skill,
                                style: TextStyle(
                                  color: selected ? Colors.white : Colors.black54,
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                )),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit
                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF8A2387)))
                    : GestureDetector(
                        onTap: _register,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [BoxShadow(
                              color: const Color(0xFFE94057).withOpacity(0.4),
                              blurRadius: 15, offset: const Offset(0, 8),
                            )],
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_add, color: Colors.white),
                              SizedBox(width: 10),
                              Text('REGISTER VOLUNTEER',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            ],
                          ),
                        ),
                      ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
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
      color: baseColor, borderRadius: 14, depth: -18,
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

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4, height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        ],
      ),
    );
  }
}
