import 'package:flutter/material.dart';
import 'package:campus_league/admin.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// this page uses Firebase Authentication; only a single admin account
// is allowed. the email/password are stored in Firestore.

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
  late String adminEmail;
  late String adminPassword;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminCredentials();
  }

  Future<void> _loadAdminCredentials() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('admin').doc('credentials').get();
      if (doc.exists) {
        adminEmail = doc['email'];
        adminPassword = doc['password'];
      } else {
        adminEmail = 'cut@sports.com';
        adminPassword = 'sports.campus';
        await FirebaseFirestore.instance.collection('admin').doc('credentials').set({
          'email': adminEmail,
          'password': adminPassword,
        });
      }
    } catch (e) {
      adminEmail = 'cut@sports.com';
      adminPassword = 'sports.campus';
    }
    setState(() {
      _loading = false;
    });
  }

  Future<void> _attemptLogin() async {
    setState(() {
      _errorMessage = null;
    });

    if (_formKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // only allow the stored admin credentials
      if (email != adminEmail || password != adminPassword) {
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

      if (!mounted) return;
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