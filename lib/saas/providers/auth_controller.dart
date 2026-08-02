import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../config/saas_config.dart';
import '../config/saas_platform.dart';
import '../models/saas_user_profile.dart';
import '../models/user_entitlement.dart';
import '../services/auth_service.dart';
import '../services/entitlement_service.dart';
import '../services/firestore_rest_client.dart';
import '../services/identity_toolkit_client.dart';
import '../services/usage_service.dart';
import '../services/user_profile_service.dart';
import '../../services/db_service.dart';

/// Estado de autenticación, perfil editable y entitlements SaaS.
class AuthController extends ChangeNotifier {
  AuthController() {
    if (!saasUseRestBackend) {
      _sub = AuthService.instance.authStateChanges.listen(_onAuthChanged);
    }
    _bootstrap();
  }

  static const Duration _cloudTimeout = Duration(seconds: 12);

  StreamSubscription<User?>? _sub;
  StreamSubscription<SaasUserProfile?>? _profileSub;
  StreamSubscription<UserEntitlement?>? _entitlementSub;

  User? _user;
  AuthSession? _restSession;
  SaasUserProfile? _profile;
  UserEntitlement? _entitlement;
  bool _loading = true;
  String? _error;
  bool _emailVerified = false;
  bool _offlineFallback = false;

  User? get user => _user;
  AuthSession? get restSession =>
      AuthService.instance.restSession ?? _restSession;
  SaasUserProfile? get profile => _profile;
  UserEntitlement? get entitlement => _entitlement;
  bool get isAuthenticated =>
      (_user != null) ||
      ((AuthService.instance.restSession ?? _restSession)?.uid.isNotEmpty ==
          true);
  bool get loading => _loading;
  String? get error => _error;
  bool get isPro => _entitlement?.isPro ?? false;

  /// Pro otorgado por superadmin (sin Stripe).
  bool get isAdminGrant => _entitlement?.isAdminGrant ?? false;
  bool get emailVerified => _emailVerified;
  bool get usingRestSession =>
      _user == null &&
      (AuthService.instance.restSession ?? _restSession) != null;
  /// true si perfil/plan se resolvieron sin nube (timeout/red).
  bool get offlineFallback => _offlineFallback;

  String? get uid => _user?.uid ?? restSession?.uid;
  String? get email => _user?.email ?? restSession?.email;

  SubscriptionPlan get plan => _entitlement?.plan ?? SubscriptionPlan.free;
  int get maxCvs => _entitlement?.maxCvs ?? SaasConfig.freeMaxCvs;

  Future<void> _bootstrap() async {
    try {
      if (saasUseRestBackend) {
        _restSession = await AuthService.instance
            .restoreRestSession()
            .timeout(const Duration(seconds: 8));
      } else {
        _restSession = AuthService.instance.restSession;
      }
      await _onAuthChanged(AuthService.instance.currentUser);
    } catch (e) {
      _error = _friendlyNetworkMessage(e);
      _loading = false;
      notifyListeners();
    }
  }

  /// Reintenta cargar perfil/entitlements tras un fallo de red.
  Future<void> retrySessionLoad() async {
    _error = null;
    _offlineFallback = false;
    await _onAuthChanged(_user ?? AuthService.instance.currentUser);
  }

  Future<void> _onAuthChanged(User? user) async {
    _user = user;
    _error = null;
    _offlineFallback = false;
    await _profileSub?.cancel();
    await _entitlementSub?.cancel();
    _profileSub = null;
    _entitlementSub = null;

    if (user == null && _restSession == null) {
      _profile = null;
      _entitlement = null;
      _emailVerified = false;
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      _loading = true;
      notifyListeners();
      if (user != null) {
        _restSession = null;
        _emailVerified = user.emailVerified;
        await _loadNativeIdentity(user);
      } else if (_restSession != null) {
        await _loadRestIdentity();
        unawaited(_syncResumeUsageBestEffort());
      }
    } catch (e) {
      _error = _friendlyNetworkMessage(e);
      if (saasUseRestBackend && _isSessionInvalidError(_error!)) {
        await AuthService.instance.clearRestSession();
        _restSession = null;
        _profile = null;
        _entitlement = null;
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Perfil + entitlements con timeout; si la nube no responde, modo limitado.
  Future<void> _loadNativeIdentity(User user) async {
    try {
      _profile = await UserProfileService.instance
          .ensureProfile(user)
          .timeout(_cloudTimeout);
      _entitlement = await EntitlementService.instance
          .ensureEntitlement(uid: user.uid, profile: _profile)
          .timeout(_cloudTimeout);
      _profileSub = UserProfileService.instance.watchProfile(user.uid).listen(
        (p) {
          _profile = p;
          notifyListeners();
        },
        onError: (_) {},
      );
      _entitlementSub = EntitlementService.instance
          .watchEntitlement(user.uid)
          .listen(
            (e) {
              if (e != null) {
                _entitlement = e;
                notifyListeners();
              }
            },
            onError: (_) {},
          );
      unawaited(_syncResumeUsageBestEffort());
    } on TimeoutException {
      _applyOfflineFallback(user);
    } catch (e) {
      if (_isNetworkish(e)) {
        _applyOfflineFallback(user, detail: e);
      } else {
        rethrow;
      }
    }
  }

  void _applyOfflineFallback(User user, {Object? detail}) {
    _offlineFallback = true;
    _error = _friendlyNetworkMessage(
      detail ??
          TimeoutException(
            'No se pudo resolver firestore.googleapis.com',
          ),
    );
    _profile ??= _profileFromAuthUser(user);
    _entitlement ??= UserEntitlement.freeBootstrap(user.uid);
  }

  SaasUserProfile _profileFromAuthUser(User user) {
    final now = DateTime.now();
    return SaasUserProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName:
          user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email?.split('@').first ?? 'Usuario'),
      createdAt: now,
      updatedAt: now,
    );
  }

  bool _isNetworkish(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('socket') ||
        s.contains('network') ||
        s.contains('unavailable') ||
        s.contains('unable to resolve') ||
        s.contains('unknownhost') ||
        s.contains('timeout') ||
        s.contains('connection') ||
        s.contains('failed host lookup');
  }

  String _friendlyNetworkMessage(Object e) {
    if (_isNetworkish(e) || e is TimeoutException) {
      return 'Sin conexión con Firebase (red/DNS). '
          'Revisa Wi‑Fi o datos móviles e intenta de nuevo. '
          'Si persiste, prueba otra red o desactiva VPN.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  bool _isSessionInvalidError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('sesión expiró') ||
        lower.contains('refresh') ||
        lower.contains('token');
  }

  /// Materializa `usage/{uid}` para límites Free en reglas (best-effort).
  Future<void> _syncResumeUsageBestEffort() async {
    try {
      await UsageService.instance.syncResumeUsage().timeout(
        const Duration(seconds: 15),
      );
    } catch (_) {
      // Functions/red pueden fallar; el create reintentará sync.
    }
  }

  /// Carga perfil + entitlements en REST sin sobrescribir Pro existente.
  Future<void> _loadRestIdentity() async {
    var session = _restSession!;
    try {
      session = await AuthService.instance
          .ensureValidRestToken()
          .timeout(_cloudTimeout);
      _restSession = session;
    } catch (_) {
      rethrow;
    }

    _emailVerified = session.emailVerified == true;
    final displayName =
        session.displayName ??
        (session.email.contains('@')
            ? session.email.split('@').first
            : 'Usuario');

    try {
      _profile = await FirestoreRestClient.instance
          .ensureUserProfile(session: session, displayName: displayName)
          .timeout(_cloudTimeout);
      _entitlement = await EntitlementService.instance
          .ensureEntitlementRest(session: session, profile: _profile)
          .timeout(_cloudTimeout);
    } on TimeoutException {
      _offlineFallback = true;
      _error = _friendlyNetworkMessage(
        TimeoutException('Timeout REST Firestore'),
      );
      final now = DateTime.now();
      _profile ??= SaasUserProfile(
        uid: session.uid,
        email: session.email,
        displayName: displayName,
        createdAt: now,
        updatedAt: now,
      );
      _entitlement ??= UserEntitlement.freeBootstrap(session.uid);
    }
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
    _entitlement = null;
    _user = null;
    _emailVerified = false;
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

  Future<bool> sendEmailVerification() async {
    _error = null;
    try {
      await AuthService.instance.sendEmailVerification();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> refreshEmailVerification() async {
    _error = null;
    try {
      final verified = await AuthService.instance.reloadEmailVerified();
      _emailVerified = verified;
      if (saasUseRestBackend) {
        _restSession = AuthService.instance.restSession;
      } else {
        _user = AuthService.instance.currentUser;
      }
      notifyListeners();
      return verified;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Exporta datos personales + CVs como JSON.
  Future<String> exportPersonalDataJson() async {
    final id = uid;
    if (id == null) throw Exception('No hay sesión activa.');

    if (usingRestSession && _restSession != null) {
      final session = await AuthService.instance.ensureValidRestToken();
      final data = await FirestoreRestClient.instance.exportUserData(session);
      return const JsonEncoder.withIndent('  ').convert(data);
    }

    final profileData = await UserProfileService.instance.exportProfile(id);
    final entitlementData = (await EntitlementService.instance.getEntitlement(
      id,
    ))?.toMap();
    final resumes = await DBService.instance.obtenerResumes();
    final payload = {
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': profileData,
      'entitlement': entitlementData,
      'resumes': resumes.map((r) => r.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Relee entitlements tras Checkout/Portal (webhook puede tardar unos segundos).
  Future<void> refreshEntitlement() async {
    final id = uid;
    if (id == null) return;
    try {
      if (usingRestSession) {
        final session = await AuthService.instance.ensureValidRestToken();
        _restSession = session;
        final remote = await FirestoreRestClient.instance.getEntitlement(
          session,
        );
        if (remote != null) {
          _entitlement = remote;
          notifyListeners();
          return;
        }
        _entitlement = await EntitlementService.instance.ensureEntitlementRest(
          session: session,
          profile: _profile,
        );
      } else {
        final remote = await EntitlementService.instance.getEntitlement(id);
        if (remote != null) {
          _entitlement = remote;
          notifyListeners();
          return;
        }
        _entitlement = await EntitlementService.instance.ensureEntitlement(
          uid: id,
          profile: _profile,
        );
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  /// Elimina CVs del usuario, perfil y cuenta Auth.
  /// Nota: entitlements/billingCustomers requieren Admin SDK (Functions) para borrado total.
  Future<bool> deleteAccount() async {
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      final id = uid;
      if (id == null) throw Exception('No hay sesión activa.');

      if (usingRestSession && _restSession != null) {
        final session = await AuthService.instance.ensureValidRestToken();
        await FirestoreRestClient.instance.deleteAllResumes(session);
        await FirestoreRestClient.instance.deleteUserProfile(session);
        await AuthService.instance.deleteAccount();
      } else {
        final resumes = await DBService.instance.obtenerResumes();
        for (final r in resumes) {
          await DBService.instance.eliminarResume(r.id);
        }
        await UserProfileService.instance.deleteProfile(id);
        await AuthService.instance.deleteAccount();
      }

      _restSession = null;
      _profile = null;
      _entitlement = null;
      _user = null;
      _emailVerified = false;
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _loading = false;
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
    _entitlementSub?.cancel();
    super.dispose();
  }
}
