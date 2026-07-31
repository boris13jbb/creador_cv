import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/resume.dart';

/// Persistencia SQLite exclusiva del módulo CV.
class DBService {
  static final DBService instance = DBService._init();
  static Database? _database;

  DBService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cvs.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE resumes (
        id TEXT PRIMARY KEY,
        nombre TEXT,
        fotoPath TEXT,
        perfil TEXT,
        datosPersonales TEXT,
        competencias TEXT,
        idiomas TEXT,
        experiencia TEXT,
        formacion TEXT,
        colorHex INTEGER,
        designIndex INTEGER,
        ocultarFoto INTEGER DEFAULT 0,
        ocultarPerfil INTEGER DEFAULT 0,
        ocultarExperiencia INTEGER DEFAULT 0,
        ocultarFormacion INTEGER DEFAULT 0,
        ocultarCompetencias INTEGER DEFAULT 0,
        ocultarIdiomas INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> insertarResume(Resume resume) async {
    final db = await database;
    await db.insert('resumes', resume.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Resume>> obtenerResumes() async {
    final db = await database;
    final rows = await db.query('resumes', orderBy: 'id DESC');
    return rows.map((r) => Resume.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<Resume?> obtenerResume(String id) async {
    final db = await database;
    final rows = await db.query('resumes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Resume.fromMap(Map<String, dynamic>.from(rows.first));
  }

  Future<void> eliminarResume(String id) async {
    final db = await database;
    await db.delete('resumes', where: 'id = ?', whereArgs: [id]);
  }
}
