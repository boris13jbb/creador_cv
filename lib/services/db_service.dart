import '../models/resume.dart';
import '../saas/services/cloud_resume_repository.dart';

class DBService {
  static final DBService instance = DBService._();
  DBService._();

  final _cloud = CloudResumeRepository.instance;

  Future<void> get database async {}

  Future<void> insertarResume(Resume resume) => _cloud.insertarResume(resume);

  Future<List<Resume>> obtenerResumes() => _cloud.obtenerResumes();

  Future<Resume?> obtenerResume(String id) => _cloud.obtenerResume(id);

  Future<void> eliminarResume(String id) => _cloud.eliminarResume(id);
}
