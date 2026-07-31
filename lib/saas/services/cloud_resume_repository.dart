import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/resume.dart';
import '../config/saas_platform.dart';
import '../providers/auth_controller.dart';
import 'firestore_rest_client.dart';
import 'user_profile_service.dart';

/// Repositorio cloud de CVs (SDK nativo o REST en Windows).
class CloudResumeRepository {
  CloudResumeRepository._();
  static final CloudResumeRepository instance = CloudResumeRepository._();

  FirebaseFirestore? _db;
  AuthController? _auth;

  void bindAuth(AuthController auth) => _auth = auth;

  FirebaseFirestore get _firestore {
    _db ??= FirebaseFirestore.instance;
    return _db!;
  }

  bool get _useRest {
    if (saasUseRestBackend) return true;
    return FirebaseAuth.instance.currentUser == null &&
        _auth?.restSession != null;
  }

  String get _uid {
    if (_useRest) {
      final rest = _auth?.restSession?.uid;
      if (rest != null && rest.isNotEmpty) return rest;
      throw Exception('Debes iniciar sesión para continuar.');
    }
    final native = FirebaseAuth.instance.currentUser?.uid;
    if (native != null) return native;
    throw Exception('Debes iniciar sesión para continuar.');
  }

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('users').doc(_uid).collection('resumes');

  Future<void> insertarResume(Resume resume) async {
    if (_useRest) {
      final session = _auth!.restSession!;
      final profile = _auth!.profile;
      final actuales = await obtenerResumes();
      final exists = actuales.any((r) => r.id == resume.id);
      final max = profile?.maxCvs ?? 3;
      if (!exists && actuales.length >= max) {
        throw Exception(
          'Límite del plan ${profile?.plan.label ?? 'Free'}: máximo $max CVs. '
          'Actualiza a Pro para continuar.',
        );
      }
      await FirestoreRestClient.instance.upsertResume(session: session, resume: resume);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Debes iniciar sesión para continuar.');
    final profile = await UserProfileService.instance.ensureProfile(user);
    final actuales = await obtenerResumes();
    final exists = actuales.any((r) => r.id == resume.id);
    if (!exists && actuales.length >= profile.maxCvs) {
      throw Exception(
        'Límite del plan ${profile.plan.label}: máximo ${profile.maxCvs} CVs. '
        'Actualiza a Pro para continuar.',
      );
    }

    final data = resume.toMap();
    data['userId'] = _uid;
    data['updatedAt'] = DateTime.now().toIso8601String();
    await _col.doc(resume.id).set(data, SetOptions(merge: true));
  }

  Future<List<Resume>> obtenerResumes() async {
    if (_useRest) {
      final session = _auth?.restSession;
      if (session == null) return [];
      return FirestoreRestClient.instance.listResumes(session);
    }
    final snap = await _col.orderBy('updatedAt', descending: true).get();
    return snap.docs.map((d) {
      final map = Map<String, dynamic>.from(d.data());
      map.remove('userId');
      map.remove('updatedAt');
      return Resume.fromMap(map);
    }).toList();
  }

  Future<Resume?> obtenerResume(String id) async {
    final all = await obtenerResumes();
    try {
      return all.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> eliminarResume(String id) async {
    if (_useRest) {
      await FirestoreRestClient.instance.deleteResume(_auth!.restSession!, id);
      return;
    }
    await _col.doc(id).delete();
  }
}
