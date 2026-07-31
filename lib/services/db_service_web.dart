import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/resume.dart';

/// Persistencia Web exclusiva del módulo CV.
class DBService {
  static final DBService instance = DBService._init();
  static const _keyResumes = 'resumes_data';

  DBService._init();

  Future<void> get database async {}

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  Future<void> insertarResume(Resume resume) async {
    final prefs = await _prefs;
    final list = await obtenerResumes();
    final idx = list.indexWhere((r) => r.id == resume.id);
    if (idx >= 0) {
      list[idx] = resume;
    } else {
      list.insert(0, resume);
    }
    final data = list.map((r) => r.toMap()).toList();
    await prefs.setString(_keyResumes, jsonEncode(data));
  }

  Future<List<Resume>> obtenerResumes() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_keyResumes);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>? ?? [];
      return list.map((e) => Resume.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Resume?> obtenerResume(String id) async {
    final list = await obtenerResumes();
    try {
      return list.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> eliminarResume(String id) async {
    final prefs = await _prefs;
    final list = await obtenerResumes();
    list.removeWhere((r) => r.id == id);
    final data = list.map((r) => r.toMap()).toList();
    await prefs.setString(_keyResumes, jsonEncode(data));
  }
}
