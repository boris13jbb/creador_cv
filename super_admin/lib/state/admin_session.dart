import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Sesión del panel: exige custom claim `superadmin`.
class AdminSession extends ChangeNotifier {
  User? _user;
  bool _loading = true;
  bool _isSuperAdmin = false;
  String? _error;

  User? get user => _user;
  bool get loading => _loading;
  bool get isSuperAdmin => _isSuperAdmin;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  AdminSession() {
    FirebaseAuth.instance.authStateChanges().listen(_onAuth);
  }

  Future<void> _onAuth(User? user) async {
    _user = user;
    _error = null;
    _isSuperAdmin = false;
    if (user == null) {
      _loading = false;
      notifyListeners();
      return;
    }
    try {
      final token = await user.getIdTokenResult(true);
      _isSuperAdmin = token.claims?['superadmin'] == true;
      if (!_isSuperAdmin) {
        _error = 'Esta cuenta no tiene rol superadmin.';
      }
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? e.code;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> refreshClaims() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _loading = true;
    notifyListeners();
    await _onAuth(user);
  }
}
