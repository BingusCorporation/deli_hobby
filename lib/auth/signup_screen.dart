import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'loggedin_screen.dart';

const List<String> serbiaCities = [
  'Belgrade',
  'Novi Sad',
  'Niš',
  'Kragujevac',
  'Subotica',
  'Čačak',
  'Kraljevo',
  'Zrenjanin',
  'Pančevo',
  'Užice',
  'Šabac',
  'Smederevo',
  'Požarevac',
  'Vršac',
  'Loznica',
];

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String? selectedCity;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> signup() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    // ---- VALIDATION ----
    if (name.isEmpty) {
      showError("Please enter your name");
      return;
    }

    if (selectedCity == null) {
      showError("Please select your city");
      return;
    }

    if (email.isEmpty || password.isEmpty) {
      showError("Email and password are required");
      return;
    }

    try {
      // ---- CREATE AUTH USER ----
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // ---- SAVE USER PROFILE ----
      await _firestore.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'city': selectedCity,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // ---- GO DIRECTLY TO LOGGED IN SCREEN ----
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoggedInScreen()),
      );
    } catch (e) {
      showError("Signup failed: $e");
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: selectedCity,
              decoration: const InputDecoration(
                labelText: "City",
                border: OutlineInputBorder(),
              ),
              items: serbiaCities.map((city) {
                return DropdownMenuItem(
                  value: city,
                  child: Text(city),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCity = value;
                });
              },
              menuMaxHeight: 300,
            ),

            const SizedBox(height: 12),

            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: signup,
              child: const Text("Create Account"),
            ),
          ],
        ),
      ),
    );
  }
}
