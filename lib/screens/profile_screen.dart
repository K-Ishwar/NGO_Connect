import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clay_containers/clay_containers.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel userModel;

  const ProfileScreen({super.key, required this.userModel});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _skillsController;
  late TextEditingController _locationController;
  String? _selectedAvailability;

  bool _isLoading = false;
  final Color baseColor = const Color(0xFFF2F2F2);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userModel.name);
    _skillsController = TextEditingController(
      text: widget.userModel.skills.join(', '),
    );
    _locationController = TextEditingController(
      text: widget.userModel.location ?? '',
    );
    _selectedAvailability = widget.userModel.availability ?? 'Part-time';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skillsController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final updateData = {
        'name': _nameController.text.trim(),
        if (widget.userModel.role == 'volunteer')
          'skills': _skillsController.text.trim(),
        if (widget.userModel.role == 'volunteer')
          'location': _locationController.text.trim(),
        if (widget.userModel.role == 'volunteer')
          'availability': _selectedAvailability,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildInput(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 15,
        depth: -20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              border: InputBorder.none,
              labelText: label,
            ),
            validator:
                validator ??
                (val) => val == null || val.isEmpty ? 'Required' : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVolunteer = widget.userModel.role == 'volunteer';

    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF8A2387)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF2F2F2),
              const Color(0xFFE6E6FA).withOpacity(0.5),
              const Color(0xFFF2F2F2),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ClayContainer(
              color: baseColor,
              borderRadius: 30,
              depth: 20,
              spread: 5,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          'Your Settings',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            foreground: Paint()
                              ..shader =
                                  const LinearGradient(
                                    colors: [
                                      Color(0xFF8A2387),
                                      Color(0xFFE94057),
                                    ],
                                  ).createShader(
                                    const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildInput(_nameController, 'Full Name'),

                      if (isVolunteer) ...[
                        _buildInput(
                          _skillsController,
                          'Skills (e.g., Medical, Driving)',
                        ),
                        _buildInput(
                          _locationController,
                          'Location (Area/City)',
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: ClayContainer(
                            color: baseColor,
                            borderRadius: 15,
                            depth: -20,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 4.0,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedAvailability,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    labelText: 'Availability',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Full-time',
                                      child: Text('Full-time'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Part-time',
                                      child: Text('Part-time'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    setState(() => _selectedAvailability = val);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),
                      _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFE94057),
                              ),
                            )
                          : GestureDetector(
                              onTap: _updateProfile,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF8A2387),
                                      Color(0xFFE94057),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFE94057,
                                      ).withOpacity(0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Text(
                                      'SAVE CHANGES',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
