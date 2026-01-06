import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:leadtracker/core/constants/api_constants.dart';
import 'package:leadtracker/core/constants/access_levels.dart';
import 'package:leadtracker/presentation/screens/home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _irIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    final irId = _irIdController.text.trim();
    final password = _passwordController.text;

    print("🔹 IR ID: $irId");
    print("🔹 Password entered: $password");

    if (irId.isEmpty || password.isEmpty) {
      _showError("Please enter both IR ID and password.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('$baseUrl$loginIrEndpoint');
      print("🌐 URL: $url");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'ir_id': irId,
          'ir_password': password,
        }),
      );

      setState(() => _isLoading = false);

      print("🔁 Response status: ${response.statusCode}");
      print("📦 Response body: ${response.body}");

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.body.isNotEmpty) {
        final responseData = json.decode(response.body);

        if (responseData['message'] == 'Login Successful') {
          final ir = responseData['ir'];

          final String id = ir['ir_id'] ?? '';
          final String name = ir['ir_name'] ?? '';
          final String email = ir['ir_email'] ?? '';
          final String startedDate = ir['started_date'] ?? '';
          final int accessLevel = ir['ir_access_level'] ?? AccessLevel.ir;

          print("✅ Login Success");
          print(
              "🧠 IR ID: $id | Name: $name | Email: $email | Role: ${AccessLevel.getRoleName(accessLevel)} (Level $accessLevel)");

          // Save login state to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('irId', id);
          await prefs.setInt('userRole', accessLevel);

          // 🔁 Push to MainScreen with role number
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(
                userRole: accessLevel,
                irId: irId, // Pass as string
              ),
            ),
          );
          return;
        } else {
          _showError(
              "Login failed: ${responseData['message'] ?? 'Unknown error'}");
        }
      } else {
        _showError(
            "Login failed: ${response.statusCode} - ${response.reasonPhrase}");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print("❌ Exception: $e");
      _showError("Unexpected error: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Login to Your IR Account",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _irIdController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'IR ID',
                labelStyle: const TextStyle(color: Colors.cyanAccent),
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
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(color: Colors.cyanAccent),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
              onTap: _isLoading ? null : _login,
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
                          "Login",
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
    );
  }
}
