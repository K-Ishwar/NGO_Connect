import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final Color baseColor = const Color(0xFFF2F2F2);

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your email address first, then tap Forgot Password.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email. Check your inbox!'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.code == 'user-not-found'
              ? 'No account found for $email.'
              : 'Reset failed: ${e.message}'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final authService = AuthService();
      UserModel? user = await authService.loginUser(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      _handleLoginResult(user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _googleLogin() async {
    setState(() => _isLoading = true);
    try {
      final authService = AuthService();
      // Google sign-in — role will be fetched from Firestore after login
      UserModel? user = await authService.signInWithGoogle('ngo');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _handleLoginResult(user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  void _handleLoginResult(UserModel? user) {
    if (user != null) {
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login failed. Make sure Email/Password sign-in is enabled in Firebase Console.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: baseColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF2F2F2),
              const Color(0xFFE6E6FA).withValues(alpha: 0.5), // Very light pastel purple
              const Color(0xFFF2F2F2),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: ClayContainer(
              color: baseColor,
              borderRadius: 30,
              depth: 20,
              spread: 5,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                            color: const Color(0xFFE94057).withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.volunteer_activism, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'NGO Connect',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        foreground: Paint()..shader = const LinearGradient(
                          colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                        ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome back! Login to continue.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                    const SizedBox(height: 40),

                    // Email Input
                    ClayContainer(
                      color: baseColor,
                      borderRadius: 15,
                      depth: -20, // Inner shadow for inputs
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            labelText: 'Email',
                            icon: Icon(
                              Icons.email_outlined,
                              color: Color(0xFF8A2387),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Password Input
                    ClayContainer(
                      color: baseColor,
                      borderRadius: 15,
                      depth: -20,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            labelText: 'Password',
                            icon: Icon(
                              Icons.lock_outline,
                              color: Color(0xFF8A2387),
                            ),
                          ),
                          obscureText: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Forgot Password link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(color: Color(0xFF8A2387), fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),

                    // Login Button
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFE94057)))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GestureDetector(
                                onTap: _login,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFE94057).withValues(alpha: 0.4),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      )
                                    ]
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 16.0,
                                      horizontal: 40.0,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'LOGIN',
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
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey.shade400)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                    child: Text("OR", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                                  ),
                                  Expanded(child: Divider(color: Colors.grey.shade400)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: _googleLogin,
                                child: ClayContainer(
                                  color: baseColor,
                                  borderRadius: 15,
                                  depth: 20,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Simple Google "G" icon stand-in
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Text('G', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Continue with Google',
                                          style: TextStyle(
                                            color: Colors.deepPurple,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Don\'t have an account? Register',
                        style: TextStyle(color: Color(0xFF8A2387), fontWeight: FontWeight.bold),
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
