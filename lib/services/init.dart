import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/hobbies.dart';
import '../data/city.dart';
import '../auth/login_screen.dart';

void initializeFirestoreStructure() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  
  final firestore = FirebaseFirestore.instance;
  
  print('Initializing Firestore structure...');
  
  // 1. Create user document if it doesn't exist
  final userRef = firestore.collection('users').doc(user.uid);
  final userDoc = await userRef.get();
  
  if (!userDoc.exists) {
    await userRef.set({
      'name': user.displayName ?? user.email?.split('@').first ?? 'User',
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'friends': [],
      'hobbies': [],
      'city': '',
      'bio': '',
      'profilePic': '',
    });
    print('✅ Created user document');
  }
  
  // 2. Create users_private document if it doesn't exist
  final privateRef = firestore.collection('users_private').doc(user.uid);
  final privateDoc = await privateRef.get();
  
  if (!privateDoc.exists) {
    await privateRef.set({
      'name': user.displayName ?? user.email?.split('@').first ?? 'User',
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'friends': [],
      'friendRequests': [],
      'sentFriendRequests': [],
      'hobbies': [],
      'city': '',
      'bio': '',
      'profilePic': '',
    });
    print('✅ Created users_private document');
  }
  
  print('✅ Firestore structure initialized');
}