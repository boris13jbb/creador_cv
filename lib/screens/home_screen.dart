import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/resume.dart';
import '../services/db_service.dart';
import '../saas/providers/auth_controller.dart';
import 'account/account_screen.dart';
import 'account/pricing_screen.dart';
import 'historial_cv_screen.dart';
import 'nuevo_cv_screen.dart';
import 'resume_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Resume>> _resumesFuture;
  final Set<String> _resumesOcultos = {};

  @override
  void initState() {
    super.initState();
    _refreshLista();
  }

  void _refreshLista() {
    setState(() {
      _resumesFuture = DBService.instance.obtenerResumes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CV Maker'),
        actions: [
          if (profile != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Chip(
                  label: Text(profile.plan.label, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.workspace_premium_outlined),
            tooltip: 'Planes',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PricingScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Mi cuenta',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLista,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshLista(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withAlpha(13),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿Qué deseas hacer hoy?',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMainButton(
                            context,
                            title: 'Nuevo\nCV Pro',
                            icon: Icons.contact_page,
                            color: Colors.orange,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const NuevoCvScreen()),
                              );
                              _refreshLista();
                            },
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildMainButton(
                            context,
                            title: 'Mis\nCVs',
                            icon: Icons.folder_shared,
                            color: Colors.deepOrange,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const HistorialCVScreen()),
                              );
                              _refreshLista();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CVs Recientes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    TextButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HistorialCVScreen()),
                        );
                        _refreshLista();
                      },
                      child: const Text('Ver todos'),
                    ),
                  ],
                ),
              ),
              _buildRecientesCV(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NuevoCvScreen()),
          );
          _refreshLista();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo CV'),
      ),
    );
  }

  Widget _buildRecientesCV() {
    return FutureBuilder<List<Resume>>(
      future: _resumesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        }
        final allResumes = snapshot.data ?? [];
        final resumes = allResumes.where((r) => !_resumesOcultos.contains(r.id)).toList();
        if (resumes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No hay CVs recientes', style: TextStyle(color: Colors.grey)),
          );
        }
        final recientes = resumes.take(5).toList();
        return Column(
          children: recientes
              .map(
                (r) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(r.colorHex),
                    child: Text(
                      r.nombre.isNotEmpty ? r.nombre[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(r.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(r.perfil, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      if (value == 'ver') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ResumePreviewScreen(resume: r)),
                        );
                        _refreshLista();
                      } else if (value == 'editar') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => NuevoCvScreen(resumeExistente: r)),
                        );
                        _refreshLista();
                      } else if (value == 'ocultar') {
                        setState(() => _resumesOcultos.add(r.id));
                      } else if (value == 'eliminar') {
                        final confirm = await _mostrarConfirmacion(context, 'CV de ${r.nombre}');
                        if (confirm == true) {
                          await DBService.instance.eliminarResume(r.id);
                          _refreshLista();
                        }
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'ver', child: Row(children: [Icon(Icons.visibility_outlined, size: 20), SizedBox(width: 8), Text('Ver PDF')])),
                      PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit_outlined, size: 20), SizedBox(width: 8), Text('Editar')])),
                      PopupMenuItem(value: 'ocultar', child: Row(children: [Icon(Icons.visibility_off_outlined, size: 20), SizedBox(width: 8), Text('Ocultar de recientes')])),
                      PopupMenuItem(value: 'eliminar', child: Row(children: [Icon(Icons.delete_outline, size: 20, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ResumePreviewScreen(resume: r)),
                    );
                    _refreshLista();
                  },
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildMainButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withAlpha(13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(76), width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _mostrarConfirmacion(BuildContext context, String item) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text('¿Estás seguro de eliminar $item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
