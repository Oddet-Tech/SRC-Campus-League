import 'package:flutter/material.dart';
import 'package:src_project/admin.dart';
import 'package:firebase_auth/firebase_auth.dart';

// this page uses Firebase Authentication; only a single admin account
// is allowed. the email/password are hard‑coded below and any other
// credentials will be rejected.

const String _kAdminEmail = 'shilengeoddet@gmail.com';
const String _kAdminPassword = 'cutsports@freestate.campusleague';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _errorMessage;
  bool _obscurePassword = true; // <-- track password visibility

  Future<void> _attemptLogin() async {
    setState(() {
      _errorMessage = null;
    });

    if (_formKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // only allow the single hard-coded admin credentials
      if (email != _kAdminEmail || password != _kAdminPassword) {
        setState(() {
          _errorMessage = 'Only the designated admin may log in';
        });
        return;
      }

      // credentials are correct; optional Firebase sign-in
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (_) {
        // ignore auth errors since we trust local credentials
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Admin()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter a password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _attemptLogin,
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}