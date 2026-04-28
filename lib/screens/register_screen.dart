import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Common
  final _nameController      = TextEditingController();
  final _emailController     = TextEditingController();
  final _passwordController  = TextEditingController();
  final _phoneController     = TextEditingController();

  // NGO-specific
  final _ngoOrgNameController   = TextEditingController(); // official org name
  final _ngoRegNoController     = TextEditingController();
  final _ngoAddressController   = TextEditingController();
  final _ngoWebsiteController   = TextEditingController();
  String _ngoType = 'Health & Medical';

  // Volunteer-specific
  final _skillsController    = TextEditingController();
  final _locationController  = TextEditingController();

  String _selectedRole         = 'ngo';
  String _selectedAvailability = 'Full-time';
  bool _isLoading              = false;
  bool _obscurePassword        = true;
  final Color baseColor        = const Color(0xFFF2F2F2);

  final _ngoTypes = [
    'Health & Medical',
    'Education',
    'Food & Nutrition',
    'Disaster Relief',
    'Women Empowerment',
    'Child Welfare',
    'Water & Sanitation',
    'Environment',
    'Rural Development',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _ngoOrgNameController.dispose();
    _ngoRegNoController.dispose();
    _ngoAddressController.dispose();
    _ngoWebsiteController.dispose();
    _skillsController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _register() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showSnack('Please fill all required fields (*)', isError: true);
      return;
    }
    if (_passwordController.text.trim().length < 6) {
      _showSnack('Password must be at least 6 characters', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      UserModel? user = await authService.registerUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        role: _selectedRole,
        name: _nameController.text.trim(),
        skills: _selectedRole == 'volunteer'
            ? _skillsController.text.trim().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
            : const [],
        location: _selectedRole == 'volunteer' ? _locationController.text.trim() : null,
        availability: _selectedRole == 'volunteer' ? _selectedAvailability : null,
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      );

      // Save extra NGO details to Firestore
      if (user != null && _selectedRole == 'ngo') {
        await FirebaseFirestore.instance.collection('users').doc(user.id).update({
          'ngo_name':    _ngoOrgNameController.text.trim(),
          'ngo_type':    _ngoType,
          'ngo_reg_no':  _ngoRegNoController.text.trim(),
          'ngo_address': _ngoAddressController.text.trim(),
          'ngo_website': _ngoWebsiteController.text.trim(),
          'phone':       _phoneController.text.trim(),
        });
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user != null) {
        _showSnack('Account created! Welcome aboard 🎉');
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        _showSnack('Registration failed. Please try again.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      duration: Duration(seconds: isError ? 4 : 2),
    ));
  }

  Widget _buildInput(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    bool required = false,
    TextInputType keyboard = TextInputType.text,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 15,
        depth: -20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
            decoration: InputDecoration(
              border: InputBorder.none,
              labelText: required ? '$label *' : label,
              icon: Icon(icon, color: const Color(0xFF8A2387)),
              suffixIcon: suffix,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, IconData icon, String value, List<String> items, void Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 15,
        depth: -20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF8A2387), size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    hint: Text(label),
                    items: items.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => onChanged(v!),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Container(width: 3, height: 16,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepPurple)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        title: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold)),
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
              const Color(0xFFE6E6FA).withValues(alpha: 0.5),
              const Color(0xFFF2F2F2),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: ClayContainer(
              color: baseColor,
              borderRadius: 28,
              depth: 20,
              spread: 5,
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE94057).withValues(alpha: 0.4),
                              blurRadius: 20, offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_add_alt_1, size: 36, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text('Get Started', style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF8A2387),
                      )),
                    ),
                    const SizedBox(height: 24),

                    // Role selector
                    _sectionLabel('I am registering as:'),
                    ClayContainer(
                      color: baseColor, borderRadius: 15, depth: -20,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRole,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8A2387)),
                            items: const [
                              DropdownMenuItem(value: 'ngo', child: Row(
                                children: [Icon(Icons.business, color: Color(0xFF8A2387), size: 18), SizedBox(width: 8), Text('NGO / Organization')],
                              )),
                              DropdownMenuItem(value: 'volunteer', child: Row(
                                children: [Icon(Icons.volunteer_activism, color: Colors.deepOrange, size: 18), SizedBox(width: 8), Text('Volunteer')],
                              )),
                            ],
                            onChanged: (value) => setState(() { if (value != null) _selectedRole = value; }),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Common Fields ──
                    _sectionLabel('Account Details'),
                    _buildInput(_nameController, _selectedRole == 'ngo' ? 'Contact Person Name' : 'Full Name', Icons.person, required: true),
                    _buildInput(_emailController, 'Email Address', Icons.email, required: true, keyboard: TextInputType.emailAddress),
                    _buildInput(_passwordController, 'Password (min 6 chars)', Icons.lock,
                      required: true,
                      obscure: _obscurePassword,
                      suffix: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    _buildInput(_phoneController, 'WhatsApp Number (10 digits)', Icons.phone, keyboard: TextInputType.phone),

                    // ── NGO-Specific Fields ──
                    if (_selectedRole == 'ngo') ...[
                      _sectionLabel('Organization Details'),
                      _buildInput(_ngoOrgNameController, 'Organization / NGO Name *', Icons.business_center, required: true),
                      _buildDropdown('Focus Area *', Icons.category, _ngoType, _ngoTypes, (v) => setState(() => _ngoType = v)),
                      _buildInput(_ngoRegNoController, 'Registration / Trust Number', Icons.numbers),
                      _buildInput(_ngoAddressController, 'Office Address', Icons.location_city, keyboard: TextInputType.streetAddress),
                      _buildInput(_ngoWebsiteController, 'Website / Social Media Link', Icons.link, keyboard: TextInputType.url),
                    ],

                    // ── Volunteer-Specific Fields ──
                    if (_selectedRole == 'volunteer') ...[
                      _sectionLabel('Volunteer Details'),
                      _buildInput(_skillsController, 'Skills (comma separated)', Icons.star),
                      _buildInput(_locationController, 'Your Location / Area', Icons.location_on),
                      _buildDropdown('Availability', Icons.timer, _selectedAvailability,
                        ['Full-time', 'Part-time'],
                        (v) => setState(() => _selectedAvailability = v),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Register Button
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFE94057)))
                        : GestureDetector(
                            onTap: _register,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE94057).withValues(alpha: 0.4),
                                    blurRadius: 15, offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Text('CREATE ACCOUNT', style: TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5,
                                  )),
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
    );
  }
}
