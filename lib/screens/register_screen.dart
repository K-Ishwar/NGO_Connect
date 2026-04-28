import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _skillsController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedRole = 'ngo';
  String _selectedAvailability = 'Full-time';
  bool _isLoading = false;
  final Color baseColor = const Color(0xFFF2F2F2);

  void _register() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final authService = AuthService();
    UserModel? user = await authService.registerUser(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      role: _selectedRole,
      name: _nameController.text.trim(),
      skills: _selectedRole == 'volunteer'
          ? _skillsController.text.trim()
          : null,
      location: _selectedRole == 'volunteer'
          ? _locationController.text.trim()
          : null,
      availability: _selectedRole == 'volunteer' ? _selectedAvailability : null,
      phoneNumber: _selectedRole == 'volunteer'
          ? _phoneController.text.trim()
          : null,
    );

    setState(() => _isLoading = false);

    if (user != null) {
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registration failed.')));
    }
  }

  Widget _buildInput(
    TextEditingController controller,
    String label,
    IconData icon, [
    bool obscure = false,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 15,
        depth: -20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              border: InputBorder.none,
              labelText: label,
              icon: Icon(icon, color: const Color(0xFF8A2387)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        title: const Text(
          'Register',
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
              const Color(
                0xFFE6E6FA,
              ).withOpacity(0.5), // Very light pastel purple
              const Color(0xFFF2F2F2),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 10.0,
            ),
            child: ClayContainer(
              color: baseColor,
              borderRadius: 30,
              depth: 20,
              spread: 5,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE94057).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..shader =
                              const LinearGradient(
                                colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                              ).createShader(
                                const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    ClayContainer(
                      color: baseColor,
                      borderRadius: 15,
                      depth: -20,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRole,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Color(0xFF8A2387),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'ngo',
                                child: Text('NGO'),
                              ),
                              DropdownMenuItem(
                                value: 'volunteer',
                                child: Text('Volunteer'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                if (value != null) _selectedRole = value;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildInput(_nameController, 'Full Name', Icons.person),
                    _buildInput(_emailController, 'Email', Icons.email, false),
                    _buildInput(
                      _passwordController,
                      'Password',
                      Icons.lock,
                      true,
                    ),

                    if (_selectedRole == 'volunteer') ...[
                      _buildInput(
                        _skillsController,
                        'Skills (comma separated)',
                        Icons.star,
                      ),
                      _buildInput(
                        _locationController,
                        'Location',
                        Icons.location_on,
                      ),
                      _buildInput(
                        _phoneController,
                        'WhatsApp Phone Number (with country code)',
                        Icons.phone,
                      ),

                      ClayContainer(
                        color: baseColor,
                        borderRadius: 15,
                        depth: -20,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 4.0,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedAvailability,
                              isExpanded: true,
                              icon: const Icon(
                                Icons.timer,
                                color: Color(0xFF8A2387),
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
                              onChanged: (value) {
                                setState(() {
                                  if (value != null) {
                                    _selectedAvailability = value;
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    _isLoading
                        ? const CircularProgressIndicator(
                            color: Color(0xFFE94057),
                          )
                        : GestureDetector(
                            onTap: _register,
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
                                padding: EdgeInsets.symmetric(
                                  vertical: 16.0,
                                  horizontal: 40.0,
                                ),
                                child: Center(
                                  child: Text(
                                    'REGISTER',
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
    );
  }
}
