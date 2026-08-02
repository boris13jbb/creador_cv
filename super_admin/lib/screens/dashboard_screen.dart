import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_api_service.dart';
import '../state/admin_session.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = AdminApiService();
  final _searchCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _metrics;
  List<dynamic> _audit = const [];
  List<dynamic> _users = const [];
  String? _pageToken;
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final metricsRes = await _api.getMetrics();
      final listRes = await _api.listUsers();
      if (!mounted) return;
      setState(() {
        _metrics = metricsRes['metrics'] as Map<String, dynamic>?;
        _audit = (metricsRes['recentAudit'] as List<dynamic>?) ?? const [];
        _users = (listRes['users'] as List<dynamic>?) ?? const [];
        _pageToken = listRes['pageToken'] as String?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final isEmail = q.contains('@');
      final res = await _api.getUser(
        email: isEmail ? q : null,
        uid: isEmail ? null : q,
      );
      if (!mounted) return;
      setState(() {
        _selected = res['user'] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _grant() async {
    final target = _selected;
    if (target == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Otorgar Pro gratis'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¿Dar acceso completo (Pro) a ${target['email'] ?? target['uid']}?',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Otorgar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      final res = await _api.grantPro(
        uid: target['uid'] as String?,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _selected = res['user'] as Map<String, dynamic>?;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pro de cortesía activado')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _revoke() async {
    final target = _selected;
    if (target == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revocar acceso Pro'),
        content: Text(
          '¿Quitar el grant de cortesía a ${target['email'] ?? target['uid']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      final res = await _api.revokeGrant(uid: target['uid'] as String?);
      if (!mounted) return;
      setState(() {
        _selected = res['user'] as Map<String, dynamic>?;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grant revocado')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSession>();
    final m = _metrics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CV Maker · Super Admin'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
          TextButton(
            onPressed: session.signOut,
            child: Text(session.user?.email ?? 'Salir'),
          ),
        ],
      ),
      body: _loading && m == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null)
                    MaterialBanner(
                      content: Text(_error!),
                      actions: [
                        TextButton(
                          onPressed: () => setState(() => _error = null),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricChip(
                        label: 'Usuarios Auth',
                        value: '${m?['authUsers'] ?? '—'}',
                      ),
                      _MetricChip(
                        label: 'Pro activos',
                        value: '${m?['proActive'] ?? '—'}',
                      ),
                      _MetricChip(
                        label: 'Free',
                        value: '${m?['freeEntitlements'] ?? '—'}',
                      ),
                      _MetricChip(
                        label: 'Grants admin',
                        value: '${m?['adminGrantsActive'] ?? '—'}',
                        highlight: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Buscar cliente',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Email o UID',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _loading ? null : _search,
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar'),
                      ),
                    ],
                  ),
                  if (_selected != null) ...[
                    const SizedBox(height: 16),
                    _UserCard(
                      user: _selected!,
                      onGrant: _grant,
                      onRevoke: _revoke,
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    'Usuarios recientes (Auth)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ..._users.map((raw) {
                    final u = raw as Map<String, dynamic>;
                    return ListTile(
                      title: Text(u['email'] as String? ?? u['uid'] as String),
                      subtitle: Text(
                        'Plan: ${u['plan']} · CVs: ${u['resumeCount']}'
                        '${u['hasAdminGrant'] == true ? ' · GRANT' : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        setState(() => _loading = true);
                        try {
                          final res = await _api.getUser(
                            uid: u['uid'] as String,
                          );
                          if (!mounted) return;
                          setState(() {
                            _selected = res['user'] as Map<String, dynamic>?;
                            _searchCtrl.text =
                                (u['email'] as String?) ?? (u['uid'] as String);
                            _loading = false;
                          });
                        } catch (e) {
                          if (!mounted) return;
                          setState(() {
                            _error =
                                e.toString().replaceFirst('Exception: ', '');
                            _loading = false;
                          });
                        }
                      },
                    );
                  }),
                  if (_pageToken != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () async {
                                setState(() => _loading = true);
                                try {
                                  final listRes = await _api.listUsers(
                                    pageToken: _pageToken,
                                  );
                                  if (!mounted) return;
                                  setState(() {
                                    _users = [
                                      ..._users,
                                      ...((listRes['users'] as List<dynamic>?) ??
                                          const []),
                                    ];
                                    _pageToken =
                                        listRes['pageToken'] as String?;
                                    _loading = false;
                                  });
                                } catch (e) {
                                  if (!mounted) return;
                                  setState(() {
                                    _error = e
                                        .toString()
                                        .replaceFirst('Exception: ', '');
                                    _loading = false;
                                  });
                                }
                              },
                        child: const Text('Cargar más'),
                      ),
                    ),
                  const SizedBox(height: 28),
                  Text(
                    'Auditoría reciente',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (_audit.isEmpty)
                    const Text('Sin eventos aún.')
                  else
                    ..._audit.map((raw) {
                      final a = raw as Map<String, dynamic>;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          a['action'] == 'grant'
                              ? Icons.verified
                              : a['action'] == 'revoke'
                                  ? Icons.block
                                  : Icons.timer_off,
                        ),
                        title: Text(
                          '${a['action']} → ${a['targetEmail'] ?? a['targetUid']}',
                        ),
                        subtitle: Text(
                          '${a['createdAt'] ?? ''}'
                          '${a['note'] != null ? ' · ${a['note']}' : ''}',
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight
        ? Theme.of(context).colorScheme.tertiaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onGrant,
    required this.onRevoke,
  });

  final Map<String, dynamic> user;
  final VoidCallback onGrant;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final entitlement = user['entitlement'] as Map<String, dynamic>?;
    final usage = user['usage'] as Map<String, dynamic>?;
    final hasGrant = user['hasAdminGrant'] == true;
    final isPro = user['isPro'] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user['email'] as String? ?? 'Sin email',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('UID: ${user['uid']}'),
            Text(
              'Plan: ${entitlement?['plan'] ?? '—'} · '
              'estado: ${entitlement?['subscriptionStatus'] ?? '—'} · '
              'origen: ${entitlement?['source'] ?? '—'}',
            ),
            Text('CVs: ${usage?['resumeCount'] ?? 0}'),
            Text(
              isPro
                  ? (hasGrant ? 'Pro por cortesía admin' : 'Pro activo')
                  : 'Free',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isPro
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onGrant,
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('Dar Pro gratis'),
                ),
                OutlinedButton.icon(
                  onPressed: hasGrant ? onRevoke : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Revocar grant'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
