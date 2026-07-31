import 'package:flutter/material.dart';
import '../models/resume.dart';
import '../services/db_service.dart';
import 'nuevo_cv_screen.dart';
import 'resume_preview_screen.dart';

class HistorialCVScreen extends StatefulWidget {
  const HistorialCVScreen({super.key});

  @override
  State<HistorialCVScreen> createState() => _HistorialCVScreenState();
}

class _HistorialCVScreenState extends State<HistorialCVScreen> {
  final _queryController = TextEditingController();
  late Future<List<Resume>> _resumesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _resumesFuture = DBService.instance.obtenerResumes();
    });
  }

  List<Resume> _filtrar(List<Resume> resumes, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return resumes;

    return resumes.where((r) {
      return r.nombre.toLowerCase().contains(query) ||
          r.perfil.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis CVs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _queryController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nombre o perfil profesional',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Resume>>(
                    future: _resumesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      
                      final allResumes = snapshot.data ?? [];
                      final filtered = _filtrar(allResumes, _queryController.text);

                      if (allResumes.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.contact_page_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No hay CVs guardados',
                                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () => _nuevoCV(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Crear primer CV'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              const Text(
                                'Sin resultados para tu búsqueda',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final r = filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Color(r.colorHex),
                                child: Text(
                                  r.nombre.isNotEmpty ? r.nombre[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(r.nombre),
                              subtitle: Text(
                                '${r.experiencia.length} experiencia(s) · ${r.formacion.length} formación',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'ver') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ResumePreviewScreen(resume: r),
                                      ),
                                    );
                                  } else if (v == 'editar') {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => NuevoCvScreen(resumeExistente: r),
                                      ),
                                    );
                                    _refresh();
                                  } else if (v == 'eliminar') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Eliminar CV'),
                                        content: Text('¿Eliminar el CV de ${r.nombre}?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      await DBService.instance.eliminarResume(r.id);
                                      _refresh();
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'ver', child: Row(children: [Icon(Icons.visibility), SizedBox(width: 8), Text('Ver PDF')])),
                                  const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('Editar')])),
                                  const PopupMenuItem(value: 'eliminar', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ResumePreviewScreen(resume: r),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _nuevoCV(context),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo CV'),
            ),
    );
  }

  void _nuevoCV(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NuevoCvScreen()),
    ).then((_) => _refresh());
  }
}
