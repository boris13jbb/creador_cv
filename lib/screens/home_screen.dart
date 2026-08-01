import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/errors/app_exception.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_layout.dart';
import '../core/widgets/app_skeleton.dart';
import '../core/widgets/app_states.dart';
import '../models/resume.dart';
import '../saas/providers/auth_controller.dart';
import '../services/db_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Resume>> _resumesFuture;

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
    final auth = context.watch<AuthController>();
    final theme = Theme.of(context);
    final layout = AppLayout.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          if (auth.isPro)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Chip(
                avatar: Icon(
                  Icons.workspace_premium,
                  size: 16,
                  color: AppColors.amber,
                ),
                label: Text('Pro'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _refreshLista,
          ),
        ],
      ),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
            context.push(AppRoutes.resumeNew);
          },
        },
        child: Focus(
          autofocus: true,
          child: RefreshIndicator(
            onRefresh: () async => _refreshLista(),
            child: AppContentWidth(
              maxWidth: layout == AppLayoutType.desktop ? 1000 : 800,
              child: ListView(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.navy.withValues(alpha: 0.08),
                          AppColors.emerald.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CV Maker', style: theme.textTheme.headlineMedium),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          auth.profile?.displayName.isNotEmpty == true
                              ? 'Hola, ${auth.profile!.displayName}. Crea o mejora tu currículum.'
                              : 'Crea o mejora tu currículum profesional.',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: [
                            FilledButton.icon(
                              onPressed: () async {
                                await context.push(AppRoutes.resumeNew);
                                _refreshLista();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Nuevo CV'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.go(AppRoutes.resumes),
                              icon: const Icon(Icons.folder_outlined),
                              label: const Text('Mis CVs'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.go(AppRoutes.templates),
                              icon: const Icon(
                                Icons.dashboard_customize_outlined,
                              ),
                              label: const Text('Plantillas'),
                            ),
                          ],
                        ),
                        if (layout == AppLayoutType.desktop) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Atajo: Ctrl+N para nuevo CV',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Text('Recientes', style: theme.textTheme.titleLarge),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.resumes),
                        child: const Text('Ver todos'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FutureBuilder<List<Resume>>(
                    future: _resumesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 220,
                          child: ResumeListSkeleton(),
                        );
                      }
                      if (snapshot.hasError) {
                        return AppErrorState(
                          message: ErrorMapper.messageOf(snapshot.error!),
                          onRetry: _refreshLista,
                        );
                      }
                      final resumes = snapshot.data ?? [];
                      if (resumes.isEmpty) {
                        return AppEmptyState(
                          icon: Icons.contact_page_outlined,
                          title: 'Aún no tienes CVs',
                          subtitle:
                              'Crea el primero y expórtalo en PDF cuando esté listo.',
                          action: FilledButton(
                            onPressed: () => context.push(AppRoutes.resumeNew),
                            child: const Text('Crear CV'),
                          ),
                        );
                      }
                      final recientes = resumes.take(5).toList();
                      return Column(
                        children: recientes
                            .map(
                              (r) => Card(
                                margin: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: Color(r.colorHex),
                                    child: Text(
                                      r.nombre.isNotEmpty
                                          ? r.nombre[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    r.nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    r.perfil,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () async {
                                    await context.push(
                                      '/resumes/preview',
                                      extra: r,
                                    );
                                    _refreshLista();
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push(AppRoutes.resumeNew);
          _refreshLista();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo CV'),
      ),
    );
  }
}
