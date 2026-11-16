import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import 'dashboard_screen.dart';
import 'moderation_screen.dart';
import 'more_screen.dart';
import 'users_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _Tab {
  const _Tab(this.label, this.icon, this.selected, this.builder);
  final String label;
  final IconData icon;
  final IconData selected;
  final Widget Function() builder;
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  final _built = <int, Widget>{};

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final tabs = <_Tab>[
      _Tab(
        'Tổng quan',
        Icons.space_dashboard_outlined,
        Icons.space_dashboard,
        () => const DashboardScreen(),
      ),
      if (s.can('users.view'))
        _Tab(
          'Người dùng',
          Icons.people_outline,
          Icons.people,
          () => const UsersScreen(),
        ),
      if (s.can('comments.view') || s.can('reports.view'))
        _Tab(
          'Kiểm duyệt',
          Icons.shield_outlined,
          Icons.shield,
          () => const ModerationScreen(),
        ),
      _Tab('Thêm', Icons.apps_outlined, Icons.apps, () => const MoreScreen()),
    ];
    final index = _index.clamp(0, tabs.length - 1);
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          for (var i = 0; i < tabs.length; i++)
            if (i == index || _built.containsKey(i))
              _built.putIfAbsent(i, tabs[i].builder)
            else
              const SizedBox(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selected),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
