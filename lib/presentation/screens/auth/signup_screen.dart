import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:leadtracker/core/constants/api_constants.dart';
import 'package:leadtracker/presentation/screens/home/home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _irIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _signup() async {
    final irId = _irIdController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (irId.isEmpty || name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError("Please fill all fields.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔹 Step 1: Reserve IR ID
      final reserveResponse = await http.post(
        Uri.parse('$baseUrl$addIrId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ir_id': irId}),
      );
      print("Printing Response Code");
      print(reserveResponse.statusCode);
      if (reserveResponse.statusCode != 200) {
        setState(() => _isLoading = false);
        _showError("Could not reserve IR ID. Try another one.");
        return;
      }

      // 🔹 Step 2: Register the IR
      final registerResponse = await http.post(
        Uri.parse('$baseUrl$registerIrId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'ir_id': irId,
          'ir_name': name,
          'ir_email': email,
          'ir_password': password,
        }),
      );

      setState(() => _isLoading = false);

      if (registerResponse.statusCode == 200 ||
          registerResponse.statusCode == 201) {
        final responseData = json.decode(registerResponse.body);
        final registeredId = responseData['ir_id'] ?? irId;

        print("Print ✅ IR Registered: $registeredId");

        // Navigate to home screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              userRole: 1,
              irId: irId,
            ),
          ),
        );
      } else {
        final msg = json.decode(registerResponse.body)['detail'] ??
            json.decode(registerResponse.body)['message'] ??
            "Registration failed.";
        _showError(msg);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print("Print ❌ Exception during signup: $e");
      _showError("Something went wrong. Please try again.");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text("Sign Up")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Text(
                "Create a New Account",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _irIdController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("IR ID"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Name"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Email"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: Colors.cyanAccent),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.cyanAccent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        const BorderSide(color: Colors.cyanAccent, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: _isLoading ? null : _signup,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _isLoading ? Colors.grey : Colors.cyanAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text(
                            "Sign Up",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.cyanAccent),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.cyanAccent),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
