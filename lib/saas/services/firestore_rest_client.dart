import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../../models/resume.dart';
import 'identity_toolkit_client.dart';

/// Persistencia Firestore vía REST (Windows, cuando Auth nativo no abre sesión).
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

  Future<void> upsertUserProfile({
    required AuthSession session,
    required Map<String, dynamic> profile,
  }) async {
    final fields = _toFields(profile);
    final res = await http.patch(
      _userDoc(session.uid),
      headers: _headers(session.idToken),
      body: jsonEncode({'fields': fields}),
    );
    _ensureOk(res, 'upsertUserProfile');
  }

  Future<void> upsertResume({
    required AuthSession session,
    required Resume resume,
  }) async {
    final data = resume.toMap();
    data['userId'] = session.uid;
    data['updatedAt'] = DateTime.now().toIso8601String();
    final res = await http.patch(
      _doc(session.uid, resume.id),
      headers: _headers(session.idToken),
      body: jsonEncode({'fields': _toFields(data)}),
    );
    _ensureOk(res, 'upsertResume');
  }

  Future<List<Resume>> listResumes(AuthSession session) async {
    final res = await http.get(_col(session.uid), headers: _headers(session.idToken));
    if (res.statusCode == 404) return [];
    _ensureOk(res, 'listResumes');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = (body['documents'] as List<dynamic>?) ?? [];
    final list = docs.map((d) {
      final map = _fromFields(Map<String, dynamic>.from(d['fields'] as Map? ?? {}));
      map.remove('userId');
      final updatedAt = map.remove('updatedAt');
      final resume = Resume.fromMap(map);
      return MapEntry(updatedAt?.toString() ?? '', resume);
    }).toList();
    list.sort((a, b) => b.key.compareTo(a.key));
    return list.map((e) => e.value).toList();
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
    return {'stringValue': value.toString()};
  }

  Map<String, dynamic> _fromFields(Map<String, dynamic> fields) {
    final out = <String, dynamic>{};
    fields.forEach((key, raw) {
      final v = Map<String, dynamic>.from(raw as Map);
      if (v.containsKey('stringValue')) {
        out[key] = v['stringValue'];
      } else if (v.containsKey('integerValue')) {
        out[key] = int.tryParse('${v['integerValue']}') ?? 0;
      } else if (v.containsKey('doubleValue')) {
        out[key] = (v['doubleValue'] as num).toDouble();
      } else if (v.containsKey('booleanValue')) {
        out[key] = v['booleanValue'] == true;
      } else {
        out[key] = null;
      }
    });
    return out;
  }
}
