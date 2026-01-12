import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/main_screen.dart';
import '../data/city.dart';

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

    // ---- SAVE USER PROFILE IN BOTH COLLECTIONS ----
    final userData = {
      'name': name,
      'city': selectedCity,
      'bio': '', // Default empty bio
      'hobbies': [], // Default empty hobbies
      'friends':[],
      'profilePic': '', // Default empty profile pic
      'createdAt': FieldValue.serverTimestamp(),
    };
    final userDatapriv = {
      'name': name,
      'email': email,
      'city': selectedCity,
      'bio': '', // Default empty bio
      'hobbies': [], // Default empty hobbies
      'friends':[],
      'friendRequests':[],
      'sentFriendRequests':[],
      'profilePic': '', // Default empty profile pic
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Create in users_private (for secure data)
    await _firestore.collection('users_private').doc(uid).set(userDatapriv);
    
    // Create in users (for public data)
    await _firestore.collection('users').doc(uid).set(userData);

    if (!mounted) return;

    // ---- GO TO LOGGED IN SCREEN AND CLEAR STACK ----
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (route) => false, // Clear all previous routes
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
