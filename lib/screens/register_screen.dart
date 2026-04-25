import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'ngo_dashboard.dart';
import 'volunteer_dashboard.dart';

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
  
  String _selectedRole = 'ngo';
  String _selectedAvailability = 'Full-time';
  bool _isLoading = false;

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
      skills: _selectedRole == 'volunteer' ? _skillsController.text.trim() : null,
      location: _selectedRole == 'volunteer' ? _locationController.text.trim() : null,
      availability: _selectedRole == 'volunteer' ? _selectedAvailability : null,
    );

    setState(() => _isLoading = false);

    if (user != null) {
      if (!mounted) return;
      if (user.role == 'ngo') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const NgoDashboard()));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const VolunteerDashboard()));
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration failed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedRole,
              items: const [
                DropdownMenuItem(value: 'ngo', child: Text('NGO')),
                DropdownMenuItem(value: 'volunteer', child: Text('Volunteer')),
              ],
              onChanged: (value) {
                setState(() {
                  if (value != null) _selectedRole = value;
                });
              },
              decoration: const InputDecoration(labelText: 'Select Role'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            if (_selectedRole == 'volunteer') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _skillsController,
                decoration: const InputDecoration(
                    labelText: 'Skills (comma separated)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedAvailability,
                items: const [
                  DropdownMenuItem(value: 'Full-time', child: Text('Full-time')),
                  DropdownMenuItem(value: 'Part-time', child: Text('Part-time')),
                ],
                onChanged: (value) {
                  setState(() {
                    if (value != null) _selectedAvailability = value;
                  });
                },
                decoration: const InputDecoration(labelText: 'Availability'),
              ),
            ],
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _register,
                    child: const Text('Register'),
                  ),
          ],
        ),
      ),
    );
  }
}
