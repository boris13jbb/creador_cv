import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../saas/config/saas_config.dart';
import '../../saas/providers/auth_controller.dart';
import '../routing/app_router.dart';
import '../theme/app_tokens.dart';
import 'app_layout.dart';

/// Shell responsive: bottom nav / rail / sidebar.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _indexForLocation(String loc) {
    if (loc.startsWith('/resumes')) return 1;
    if (loc.startsWith('/templates')) return 2;
    if (loc.startsWith('/pricing')) return 3;
    if (loc.startsWith('/account')) return 4;
    return 0;
  }

  void _go(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        context.go(AppRoutes.resumes);
      case 2:
        context.go(AppRoutes.templates);
      case 3:
        context.go(AppRoutes.pricing);
      case 4:
        context.go(AppRoutes.account);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final index = _indexForLocation(loc);
    final layout = AppLayout.of(context);
    final auth = context.watch<AuthController>();

    if (layout == AppLayoutType.mobile) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index.clamp(0, 4),
          onDestinationSelected: (i) => _go(context, i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'Mis CVs',
            ),
            NavigationDestination(
              icon: Icon(Icons.dashboard_customize_outlined),
              selectedIcon: Icon(Icons.dashboard_customize),
              label: 'Plantillas',
            ),
            NavigationDestination(
              icon: Icon(Icons.workspace_premium_outlined),
              selectedIcon: Icon(Icons.workspace_premium),
              label: 'Planes',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Cuenta',
            ),
          ],
        ),
      );
    }

    final rail = layout == AppLayoutType.tablet;
    return Scaffold(
      body: Row(
        children: [
          if (rail)
            NavigationRail(
              selectedIndex: index.clamp(0, 4),
              onDestinationSelected: (i) => _go(context, i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Icon(
                  Icons.badge,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Inicio'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: Text('CVs'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_customize_outlined),
                  selectedIcon: Icon(Icons.dashboard_customize),
                  label: Text('Plantillas'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.workspace_premium_outlined),
                  selectedIcon: Icon(Icons.workspace_premium),
                  label: Text('Planes'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Cuenta'),
                ),
              ],
            )
          else
            _DesktopSidebar(
              selectedIndex: index,
              onSelect: (i) => _go(context, i),
              planLabel: auth.plan.label,
              isPro: auth.isPro,
            ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String planLabel;
  final bool isPro;

  const _DesktopSidebar({
    required this.selectedIndex,
    required this.onSelect,
    required this.planLabel,
    required this.isPro,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.navy,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    SaasConfig.productName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isPro
                          ? AppColors.amber.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: AppRadii.pill,
                    ),
                    child: Text(
                      'Plan $planLabel',
                      style: TextStyle(
                        color: isPro ? AppColors.amberSoft : Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SideItem(
              icon: Icons.home_outlined,
              label: 'Inicio',
              selected: selectedIndex == 0,
              onTap: () => onSelect(0),
            ),
            _SideItem(
              icon: Icons.folder_outlined,
              label: 'Mis CVs',
              selected: selectedIndex == 1,
              onTap: () => onSelect(1),
            ),
            _SideItem(
              icon: Icons.dashboard_customize_outlined,
              label: 'Plantillas',
              selected: selectedIndex == 2,
              onTap: () => onSelect(2),
            ),
            _SideItem(
              icon: Icons.workspace_premium_outlined,
              label: 'Planes',
              selected: selectedIndex == 3,
              onTap: () => onSelect(3),
            ),
            _SideItem(
              icon: Icons.person_outline,
              label: 'Mi cuenta',
              selected: selectedIndex == 4,
              onTap: () => onSelect(4),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Currículums profesionales\nen la nube',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SideItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? AppColors.emeraldBright : Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: selected ? 1 : 0.75),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
