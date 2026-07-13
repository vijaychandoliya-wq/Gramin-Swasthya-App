import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
  );

  User? get currentUser => _firebaseAuth.currentUser;

  Future<User?> restoredUser() async {
    final current = _firebaseAuth.currentUser;
    if (current != null) return current;
    return _firebaseAuth.authStateChanges().first;
  }

  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      final result = await _firebaseAuth.signInWithPopup(provider);
      return result.user;
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _firebaseAuth.signInWithCredential(credential);
    return result.user;
  }

  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      if (!kIsWeb) _googleSignIn.signOut(),
    ]);
  }
}
