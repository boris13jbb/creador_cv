import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/errors/app_exception.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_layout.dart';
import '../core/widgets/app_skeleton.dart';
import '../core/widgets/async_body.dart';
import '../features/resumes/data/resume_repository.dart';
import '../models/resume.dart';
import '../services/db_service.dart';

class HistorialCVScreen extends StatefulWidget {
  const HistorialCVScreen({super.key});

  @override
  State<HistorialCVScreen> createState() => _HistorialCVScreenState();
}

class _HistorialCVScreenState extends State<HistorialCVScreen> {
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Resume> _items = [];
  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _loadingMore = false;
  Object? _error;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _refresh();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _refresh() async {
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _cursor = null;
      _hasMore = true;
    });
    try {
      final page = await DBService.instance.listPage(pageSize: 20);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await DBService.instance.listPage(
        pageSize: 20,
        cursor: _cursor,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorMapper.messageOf(e))));
    }
  }

  List<Resume> _filtrar(List<Resume> resumes, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return resumes;
    return resumes.where((r) {
      return r.nombre.toLowerCase().contains(query) ||
          r.perfil.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openNew() async {
    await context.push(AppRoutes.resumeNew);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtrar(_items, _queryController.text);
    final searching = _queryController.text.trim().isNotEmpty;
    final snapshot = _loading && _items.isEmpty
        ? AsyncSnapshot<ResumePage>.withData(
            ConnectionState.waiting,
            ResumePage.empty,
          )
        : _error != null && _items.isEmpty
        ? AsyncSnapshot<ResumePage>.withError(ConnectionState.done, _error!)
        : AsyncSnapshot<ResumePage>.withData(
            ConnectionState.done,
            ResumePage(items: filtered, hasMore: _hasMore, nextCursor: _cursor),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis CVs'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: Column(
        children: [
          AppContentWidth(
            maxWidth: 960,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
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
            child: AsyncBody<ResumePage>(
              snapshot: snapshot,
              emptyIcon: searching
                  ? Icons.search_off_outlined
                  : Icons.description_outlined,
              emptyTitle: searching ? 'Sin resultados' : 'Aún no tienes CVs',
              emptyMessage: searching
                  ? 'Prueba con otro nombre o perfil.'
                  : 'Crea tu primer currículum profesional.',
              emptyAction: searching
                  ? null
                  : FilledButton.icon(
                      onPressed: _openNew,
                      icon: const Icon(Icons.add),
                      label: const Text('Crear CV'),
                    ),
              isEmpty: (page) => page.items.isEmpty,
              onRetry: _refresh,
              loading: const ResumeListSkeleton(),
              builder: (context, page) {
                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    88,
                  ),
                  itemCount: page.items.length + (_loadingMore ? 1 : 0),
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    if (index >= page.items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final r = page.items[index];
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: Card(
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
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              r.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              r.perfil.isEmpty
                                  ? 'Sin perfil profesional'
                                  : r.perfil,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'ver') {
                                  await context.push(
                                    '/resumes/preview',
                                    extra: r,
                                  );
                                  _refresh();
                                } else if (value == 'editar') {
                                  await context.push('/resumes/edit', extra: r);
                                  _refresh();
                                } else if (value == 'eliminar') {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Eliminar'),
                                      content: Text(
                                        '¿Eliminar CV de ${r.nombre}?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text(
                                            'Eliminar',
                                            style: TextStyle(
                                              color: AppColors.danger,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    await DBService.instance.eliminarResume(
                                      r.id,
                                    );
                                    _refresh();
                                  }
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'ver',
                                  child: Text('Ver PDF'),
                                ),
                                PopupMenuItem(
                                  value: 'editar',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'eliminar',
                                  child: Text(
                                    'Eliminar',
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ),
                              ],
                            ),
                            onTap: () async {
                              await context.push('/resumes/preview', extra: r);
                              _refresh();
                            },
                          ),
                        ),
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
        onPressed: _openNew,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo CV'),
      ),
    );
  }
}
