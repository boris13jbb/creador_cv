import '../models/resume.dart';
import '../features/resumes/data/resume_repository.dart';
import '../saas/services/cloud_resume_repository.dart';

/// Fachada de persistencia de CVs (compatibilidad con pantallas existentes).
class DBService implements ResumeRepository {
  static final DBService instance = DBService._();
  DBService._();

  final CloudResumeRepository _cloud = CloudResumeRepository.instance;

  @override
  Future<void> save(Resume resume) => _cloud.save(resume);

  Future<void> insertarResume(Resume resume) => _cloud.insertarResume(resume);

  Future<Resume> saveWithOptionalPhoto({
    required Resume resume,
    List<int>? pendingPhotoBytes,
    bool squareCrop = true,
  }) => _cloud.saveWithOptionalPhoto(
    resume: resume,
    pendingPhotoBytes: pendingPhotoBytes,
    squareCrop: squareCrop,
  );

  @override
  Future<ResumePage> listPage({int pageSize = 20, String? cursor}) =>
      _cloud.listPage(pageSize: pageSize, cursor: cursor);

  @override
  Future<List<Resume>> listAll() => _cloud.listAll();

  Future<List<Resume>> obtenerResumes() => _cloud.obtenerResumes();

  @override
  Future<Resume?> getById(String id) => _cloud.getById(id);

  Future<Resume?> obtenerResume(String id) => _cloud.obtenerResume(id);

  @override
  Future<void> delete(String id) => _cloud.delete(id);

  Future<void> eliminarResume(String id) => _cloud.eliminarResume(id);
}
