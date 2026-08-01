import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../../features/resumes/data/resume_repository.dart';
import '../../models/resume.dart';
import '../models/saas_user_profile.dart';
import '../models/user_entitlement.dart';
import 'identity_toolkit_client.dart';

/// Persistencia Firestore vía REST (Windows/Linux).
class FirestoreRestClient {
  FirestoreRestClient._();
  static final FirestoreRestClient instance = FirestoreRestClient._();

  String get _projectId => IdentityToolkitClient.instance.projectId;

  Uri _doc(String uid, String resumeId) => Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/users/$uid/resumes/$resumeId',
  );

  Uri _col(String uid) => Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/users/$uid/resumes',
  );

  Uri _userDoc(String uid) => Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/users/$uid',
  );

  Uri _entitlementDoc(String uid) => Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/entitlements/$uid',
  );

  Future<SaasUserProfile?> getUserProfile(AuthSession session) async {
    final res = await http.get(
      _userDoc(session.uid),
      headers: _headers(session.idToken),
    );
    if (res.statusCode == 404) return null;
    _ensureOk(res, 'getUserProfile');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final fields = Map<String, dynamic>.from(body['fields'] as Map? ?? {});
    return SaasUserProfile.fromMap(_fromFields(fields));
  }

  /// Crea perfil editable o actualiza solo campos permitidos. Nunca escribe plan.
  Future<SaasUserProfile> ensureUserProfile({
    required AuthSession session,
    required String displayName,
  }) async {
    final existing = await getUserProfile(session);
    if (existing != null) {
      return existing;
    }
    final now = DateTime.now();
    final profile = SaasUserProfile(
      uid: session.uid,
      email: session.email,
      displayName: displayName,
      schemaVersion: SaasUserProfile.currentSchemaVersion,
      createdAt: now,
      updatedAt: now,
    );
    final res = await http.patch(
      _userDoc(session.uid),
      headers: _headers(session.idToken),
      body: jsonEncode({'fields': _toFields(profile.toWritableMap())}),
    );
    _ensureOk(res, 'ensureUserProfile');
    return profile;
  }

  Future<UserEntitlement?> getEntitlement(AuthSession session) async {
    final res = await http.get(
      _entitlementDoc(session.uid),
      headers: _headers(session.idToken),
    );
    if (res.statusCode == 404) return null;
    _ensureOk(res, 'getEntitlement');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final fields = Map<String, dynamic>.from(body['fields'] as Map? ?? {});
    return UserEntitlement.fromMap(_fromFields(fields));
  }

  /// Solo crea si no existe. No sobrescribe entitlements (protege Pro).
  Future<void> createEntitlementIfAbsent({
    required AuthSession session,
    required Map<String, dynamic> entitlement,
  }) async {
    final existing = await getEntitlement(session);
    if (existing != null) return;

    // createDocument evita PATCH destructivo sobre docs existentes.
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/entitlements?documentId=${session.uid}',
    );
    final res = await http.post(
      uri,
      headers: _headers(session.idToken),
      body: jsonEncode({'fields': _toFields(entitlement)}),
    );
    if (res.statusCode == 409) return; // already exists
    _ensureOk(res, 'createEntitlementIfAbsent');
  }

  Future<void> upsertResume({
    required AuthSession session,
    required Resume resume,
  }) async {
    final data = resume.toFirestoreMap(userId: session.uid);
    final res = await http.patch(
      _doc(session.uid, resume.id),
      headers: _headers(session.idToken),
      body: jsonEncode({'fields': _toFields(data)}),
    );
    _ensureOk(res, 'upsertResume');
  }

  Future<List<Resume>> listResumes(AuthSession session) async {
    final page = await listResumesPage(session, pageSize: 500);
    return page.items;
  }

  Future<ResumePage> listResumesPage(
    AuthSession session, {
    int pageSize = 20,
    String? cursor,
  }) async {
    final res = await http.get(
      _col(session.uid),
      headers: _headers(session.idToken),
    );
    if (res.statusCode == 404) return ResumePage.empty;
    _ensureOk(res, 'listResumesPage');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = (body['documents'] as List<dynamic>?) ?? [];
    final list = docs.map((d) {
      final map = _fromFields(
        Map<String, dynamic>.from(d['fields'] as Map? ?? {}),
      );
      final name = d['name'] as String? ?? '';
      final idFromPath = name.split('/').isNotEmpty
          ? name.split('/').last
          : null;
      map.putIfAbsent('id', () => idFromPath ?? '');
      final updatedAt = map['updatedAt']?.toString() ?? '';
      return MapEntry(updatedAt, Resume.fromMap(map));
    }).toList();
    list.sort((a, b) => b.key.compareTo(a.key));

    var start = 0;
    if (cursor != null && cursor.isNotEmpty) {
      final idx = list.indexWhere((e) => e.key == cursor);
      start = idx >= 0 ? idx + 1 : 0;
    }
    final slice = list.skip(start).take(pageSize + 1).toList();
    final hasMore = slice.length > pageSize;
    final pageItems = (hasMore ? slice.sublist(0, pageSize) : slice)
        .map((e) => e.value)
        .toList();
    final next = hasMore && pageItems.isNotEmpty
        ? pageItems.last.updatedAt?.toIso8601String() ??
              list.skip(start).take(pageSize).last.key
        : null;
    return ResumePage(items: pageItems, hasMore: hasMore, nextCursor: next);
  }

  Future<Map<String, dynamic>> exportUserData(AuthSession session) async {
    final profile = await getUserProfile(session);
    final entitlement = await getEntitlement(session);
    final resumes = await listResumes(session);
    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': profile?.toWritableMap(),
      'entitlement': entitlement?.toMap(),
      'resumes': resumes.map((r) => r.toMap()).toList(),
    };
  }

  Future<void> deleteAllResumes(AuthSession session) async {
    final resumes = await listResumes(session);
    for (final r in resumes) {
      await deleteResume(session, r.id);
    }
  }

  Future<void> deleteUserProfile(AuthSession session) async {
    final res = await http.delete(
      _userDoc(session.uid),
      headers: _headers(session.idToken),
    );
    if (res.statusCode == 404) return;
    _ensureOk(res, 'deleteUserProfile');
  }

  Future<void> deleteResume(AuthSession session, String id) async {
    final res = await http.delete(
      _doc(session.uid, id),
      headers: _headers(session.idToken),
    );
    if (res.statusCode == 404) return;
    _ensureOk(res, 'deleteResume');
  }

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  void _ensureOk(http.Response res, String op) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    debugPrint('Firestore REST [$op] ${res.statusCode}: ${res.body}');
    throw Exception('Error de nube ($op). Código ${res.statusCode}.');
  }

  Map<String, dynamic> _toFields(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((key, value) {
      out[key] = _toValue(value);
    });
    return out;
  }

  Map<String, dynamic> _toValue(dynamic value) {
    if (value == null) return {'nullValue': null};
    if (value is String) return {'stringValue': value};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': '$value'};
    if (value is double) return {'doubleValue': value};
    if (value is num) return {'doubleValue': value.toDouble()};
    if (value is List) {
      return {
        'arrayValue': {'values': value.map(_toValue).toList()},
      };
    }
    if (value is Map) {
      final fields = <String, dynamic>{};
      value.forEach((k, v) {
        fields['$k'] = _toValue(v);
      });
      return {
        'mapValue': {'fields': fields},
      };
    }
    return {'stringValue': value.toString()};
  }

  Map<String, dynamic> _fromFields(Map<String, dynamic> fields) {
    final out = <String, dynamic>{};
    fields.forEach((key, raw) {
      out[key] = _fromValue(Map<String, dynamic>.from(raw as Map));
    });
    return out;
  }

  dynamic _fromValue(Map<String, dynamic> v) {
    if (v.containsKey('stringValue')) return v['stringValue'];
    if (v.containsKey('integerValue')) {
      return int.tryParse('${v['integerValue']}') ?? 0;
    }
    if (v.containsKey('doubleValue')) {
      return (v['doubleValue'] as num).toDouble();
    }
    if (v.containsKey('booleanValue')) return v['booleanValue'] == true;
    if (v.containsKey('nullValue')) return null;
    if (v.containsKey('arrayValue')) {
      final values =
          (v['arrayValue'] as Map?)?['values'] as List<dynamic>? ?? [];
      return values
          .map((e) => _fromValue(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (v.containsKey('mapValue')) {
      final fields =
          (v['mapValue'] as Map?)?['fields'] as Map<String, dynamic>? ?? {};
      return _fromFields(Map<String, dynamic>.from(fields));
    }
    if (v.containsKey('timestampValue')) {
      return v['timestampValue'];
    }
    return null;
  }
}
