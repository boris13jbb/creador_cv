import '../../../models/resume.dart';

/// Página de resultados de CV.
class ResumePage {
  final List<Resume> items;
  final bool hasMore;

  /// Cursor opaco (updatedAt del último ítem o docId).
  final String? nextCursor;

  const ResumePage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  static const empty = ResumePage(items: [], hasMore: false);
}

/// Contrato del repositorio de CVs.
abstract class ResumeRepository {
  Future<void> save(Resume resume);

  Future<ResumePage> listPage({int pageSize = 20, String? cursor});

  Future<List<Resume>> listAll();

  Future<Resume?> getById(String id);

  Future<void> delete(String id);
}
