import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../config/saas_config.dart';
import '../config/saas_platform.dart';
import '../models/saas_user_profile.dart';
import '../services/auth_service.dart';
import '../services/firestore_rest_client.dart';
import '../services/identity_toolkit_client.dart';
import '../services/user_profile_service.dart';

/// Estado de autenticación y perfil SaaS para la UI.
class AuthController extends ChangeNotifier {
  AuthController() {
    if (!saasUseRestBackend) {
      _sub = AuthService.instance.authStateChanges.listen(_onAuthChanged);
    }
    _bootstrap();
  }

  StreamSubscription<User?>? _sub;
  StreamSubscription<SaasUserProfile?>? _profileSub;

  User? _user;
  AuthSession? _restSession;
  SaasUserProfile? _profile;
  bool _loading = true;
  String? _error;

  User? get user => _user;
  AuthSession? get restSession => _restSession;
  SaasUserProfile? get profile => _profile;
  bool get isAuthenticated =>
      (_user != null) || (_restSession != null && _restSession!.uid.isNotEmpty);
  bool get loading => _loading;
  String? get error => _error;
  bool get isPro => _profile?.isPro ?? false;
  bool get usingRestSession => _user == null && _restSession != null;

  String? get uid => _user?.uid ?? _restSession?.uid;
  String? get email => _user?.email ?? _restSession?.email;

  Future<void> _bootstrap() async {
    _restSession = AuthService.instance.restSession;
    await _onAuthChanged(AuthService.instance.currentUser);
  }

  Future<void> _onAuthChanged(User? user) async {
    _user = user;
    _error = null;
    await _profileSub?.cancel();
    _profileSub = null;

    if (user == null && _restSession == null) {
      _profile = null;
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      _loading = true;
      notifyListeners();
      if (user != null) {
        _restSession = null;
        _profile = await UserProfileService.instance.ensureProfile(user);
        _profileSub = UserProfileService.instance.watchProfile(user.uid).listen((p) {
          _profile = p;
          notifyListeners();
        });
      } else if (_restSession != null) {
        _profile = await _ensureRestProfile(_restSession!);
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<SaasUserProfile> _ensureRestProfile(AuthSession session) async {
    final now = DateTime.now();
    final profile = SaasUserProfile(
      uid: session.uid,
      email: session.email,
      displayName: session.displayName ??
          (session.email.contains('@') ? session.email.split('@').first : 'Usuario'),
      plan: SubscriptionPlan.free,
      subscriptionStatus: 'active',
      trialEndsAt: now.add(const Duration(days: 14)),
      createdAt: now,
      updatedAt: now,
    );
    await FirestoreRestClient.instance.upsertUserProfile(
      session: session,
      profile: profile.toMap(),
    );
    return profile;
  }

  Future<bool> signIn({required String email, required String password}) async {
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      await AuthService.instance.signIn(email: email, password: password);
      _restSession = AuthService.instance.restSession;
      await _onAuthChanged(AuthService.instance.currentUser);
      return isAuthenticated;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      await AuthService.instance.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      _restSession = AuthService.instance.restSession;
      await _onAuthChanged(AuthService.instance.currentUser);
      return isAuthenticated;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await AuthService.instance.signOut();
    _restSession = null;
    _profile = null;
    _user = null;
    notifyListeners();
  }

  Future<bool> resetPassword(String email) async {
    _error = null;
    try {
      await AuthService.instance.resetPassword(email);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
