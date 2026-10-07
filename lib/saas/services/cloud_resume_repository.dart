import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../core/errors/app_exception.dart';
import '../../core/utils/firestore_map_utils.dart';
import '../../features/resumes/data/resume_photo_service.dart';
import '../../features/resumes/data/resume_repository.dart';
import '../../models/resume.dart';
import '../config/plan_limits.dart';
import '../config/saas_platform.dart';
import '../providers/auth_controller.dart';
import 'auth_service.dart';
import 'firestore_rest_client.dart';
import 'usage_service.dart';

/// Resultado de guardar un CV con foto opcional.
class ResumeSaveOutcome {
  final Resume resume;
  final String? photoWarning;

  const ResumeSaveOutcome({required this.resume, this.photoWarning});
}

/// Implementación cloud del repositorio de CVs (SDK nativo o REST).
class CloudResumeRepository implements ResumeRepository {
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
      final rest =
          _auth?.restSession?.uid ?? AuthService.instance.restSession?.uid;
      if (rest != null && rest.isNotEmpty) return rest;
      throw const AuthAppException('Debes iniciar sesión para continuar.');
    }
    final native = FirebaseAuth.instance.currentUser?.uid;
    if (native != null) return native;
    throw const AuthAppException('Debes iniciar sesión para continuar.');
  }

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('users').doc(_uid).collection('resumes');

  int get _maxCvs =>
      _auth?.maxCvs ?? PlanLimits.maxCvsFor(isPro: _auth?.isPro ?? false);

  bool get _isPro => _auth?.isPro ?? false;

  /// Sincroniza `usage/{uid}` en servidor antes de un create Free.
  /// Evita permission-denied de reglas y aplica el tope real.
  Future<void> _assertServerAllowsNewResume() async {
    if (_isPro) return;
    try {
      final snap = await UsageService.instance.syncResumeUsage();
      if (!snap.canCreate) {
        throw AppException(PlanLimits.limitReachedMessage(isPro: false));
      }
      return;
    } on AppException {
      rethrow;
    } catch (_) {
      // Functions aún no desplegadas o red: fallback al conteo cliente.
    }
  }

  @override
  Future<void> save(Resume resume) => insertarResume(resume);

  /// Guarda CV; sube foto pendiente si [pendingPhotoBytes] no es null.
  ///
  /// Si la foto falla (p. ej. Storage no activado), el CV se guarda igual
  /// y [ResumeSaveOutcome.photoWarning] informa al usuario.
  Future<ResumeSaveOutcome> saveWithOptionalPhoto({
    required Resume resume,
    List<int>? pendingPhotoBytes,
    bool squareCrop = true,
  }) async {
    var toSave = resume;
    String? photoWarning;
    final uid = _uid;

    if (pendingPhotoBytes != null && pendingPhotoBytes.isNotEmpty) {
      try {
        final processed = ResumePhotoService.instance.processBytes(
          Uint8List.fromList(pendingPhotoBytes),
          squareCrop: squareCrop,
        );
        if (resume.fotoStoragePath != null &&
            resume.fotoStoragePath!.isNotEmpty) {
          await ResumePhotoService.instance.deleteIfExists(
            resume.fotoStoragePath,
          );
        }
        final uploaded = await ResumePhotoService.instance.upload(
          uid: uid,
          resumeId: resume.id,
          photo: processed,
        );
        toSave = resume.copyWith(
          fotoUrl: uploaded.downloadUrl,
          fotoStoragePath: uploaded.storagePath,
          clearFotoPath: true,
        );
      } catch (e) {
        photoWarning = ErrorMapper.messageOf(e);
        debugPrint('Foto no subida; se guarda el CV sin foto nueva: $e');
      }
    }

    await insertarResume(toSave);
    return ResumeSaveOutcome(resume: toSave, photoWarning: photoWarning);
  }

  Future<void> insertarResume(Resume resume) async {
    if (_useRest) {
      final session = await AuthService.instance.ensureValidRestToken();
      final actuales = await listAll();
      final exists = actuales.any((r) => r.id == resume.id);
      final max = _maxCvs;
      if (!exists && actuales.length >= max) {
        throw AppException(PlanLimits.limitReachedMessage(isPro: _isPro));
      }
      if (!exists) {
        await _assertServerAllowsNewResume();
      }
      await FirestoreRestClient.instance.upsertResume(
        session: session,
        resume: resume,
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AuthAppException('Debes iniciar sesión para continuar.');
    }
    final existentesSnap = await _col.limit(_maxCvs + 1).get();
    final exists = existentesSnap.docs.any((d) => d.id == resume.id);
    if (!exists && existentesSnap.size >= _maxCvs) {
      throw AppException(PlanLimits.limitReachedMessage(isPro: _isPro));
    }
    if (!exists) {
      await _assertServerAllowsNewResume();
    }

    final docId = resume.id.trim();
    if (docId.isEmpty || docId.contains('/')) {
      throw const ValidationAppException(
        'Identificador de CV inválido. Cierra y vuelve a abrir el CV.',
      );
    }
    if (_uid.isEmpty) {
      throw const AuthAppException('Debes iniciar sesión para continuar.');
    }

    // Quitar nulls antes de añadir FieldValue: evita invalid-argument en Android.
    final data = stripNullsForFirestore(resume.toFirestoreMap(userId: _uid));
    data['id'] = docId;
    data['userId'] = _uid;
    // Limpia data-URI legacy sin enviar `null` crudo al SDK.
    if (!data.containsKey('fotoPath')) {
      data['fotoPath'] = FieldValue.delete();
    }
    data['updatedAtServer'] = FieldValue.serverTimestamp();
    if (resume.createdAt == null) {
      data['createdAtServer'] = FieldValue.serverTimestamp();
    }
    await _col.doc(docId).set(data, SetOptions(merge: true));
  }

  /// Siempre usa el id del path del documento (evita id vacío en el mapa).
  Resume _resumeFromDoc(String docId, Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    map['id'] = docId;
    return Resume.fromMap(map);
  }

  @override
  Future<ResumePage> listPage({int pageSize = 20, String? cursor}) async {
    if (_useRest) {
      if (_auth?.restSession == null &&
          AuthService.instance.restSession == null) {
        return ResumePage.empty;
      }
      final session = await AuthService.instance.ensureValidRestToken();
      return FirestoreRestClient.instance.listResumesPage(
        session,
        pageSize: pageSize,
        cursor: cursor,
      );
    }

    Query<Map<String, dynamic>> q = _col
        .orderBy('updatedAt', descending: true)
        .limit(pageSize + 1);

    if (cursor != null && cursor.isNotEmpty) {
      q = q.startAfter([cursor]);
    }

    final snap = await q.get();
    final docs = snap.docs;
    final hasMore = docs.length > pageSize;
    final pageDocs = hasMore ? docs.sublist(0, pageSize) : docs;
    final items = pageDocs.map((d) => _resumeFromDoc(d.id, d.data())).toList();

    String? next;
    if (hasMore && items.isNotEmpty) {
      next =
          items.last.updatedAt?.toIso8601String() ??
          pageDocs.last.data()['updatedAt']?.toString();
    }
    return ResumePage(items: items, hasMore: hasMore, nextCursor: next);
  }

  @override
  Future<List<Resume>> listAll() => obtenerResumes();

  Future<List<Resume>> obtenerResumes() async {
    if (_useRest) {
      if (_auth?.restSession == null &&
          AuthService.instance.restSession == null) {
        return [];
      }
      final session = await AuthService.instance.ensureValidRestToken();
      return FirestoreRestClient.instance.listResumes(session);
    }
    final snap = await _col.orderBy('updatedAt', descending: true).get();
    return snap.docs.map((d) => _resumeFromDoc(d.id, d.data())).toList();
  }

  @override
  Future<Resume?> getById(String id) => obtenerResume(id);

  Future<Resume?> obtenerResume(String id) async {
    if (_useRest) {
      final all = await obtenerResumes();
      try {
        return all.firstWhere((r) => r.id == id);
      } catch (_) {
        return null;
      }
    }
    final snap = await _col.doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return _resumeFromDoc(snap.id, snap.data()!);
  }

  @override
  Future<void> delete(String id) => eliminarResume(id);

  Future<void> eliminarResume(String id) async {
    Resume? existing;
    try {
      existing = await obtenerResume(id);
    } catch (_) {}

    if (_useRest) {
      final session = await AuthService.instance.ensureValidRestToken();
      await FirestoreRestClient.instance.deleteResume(session, id);
    } else {
      await _col.doc(id).delete();
    }

    if (existing?.fotoStoragePath != null) {
      await ResumePhotoService.instance.deleteIfExists(
        existing!.fotoStoragePath,
      );
    }
  }
}
