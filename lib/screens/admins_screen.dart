import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../widgets/common.dart';
import 'logs_screen.dart';

const roleLabels = {
  'super_admin': 'Super Admin',
  'admin': 'Admin',
  'moderator': 'Moderator',
  'viewer': 'Viewer',
};

const roleColors = {
  'super_admin': AppColors.primary,
  'admin': AppColors.accent,
  'moderator': AppColors.info,
  'viewer': AppColors.dim,
};

class AdminsScreen extends StatefulWidget {
  const AdminsScreen({super.key});
  @override
  State<AdminsScreen> createState() => _AdminsScreenState();
}

class _AdminsScreenState extends State<AdminsScreen> {
  Map<String, dynamic>? _d;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await AdminApi.I.get('m/admins/');
      if (mounted) {
        setState(() {
          _d = r;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  List<String> get _roles =>
      ((_d?['roles'] as List?) ?? roleLabels.keys.toList())
          .map((e) => e.toString())
          .toList();

  Future<void> _mutate(Map<String, dynamic> body) async {
    final r = await runAction(() => AdminApi.I.post('m/admins/', body: body));
    if (r != null) await _load();
  }

  Future<void> _create() async {
    final user = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController();
    var role = 'viewer';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Tạo quản trị viên'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: user,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu (≥ 8 ký tự)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Vai trò'),
                  items: [
                    for (final r in _roles)
                      DropdownMenuItem(
                        value: r,
                        child: Text(roleLabels[r] ?? r),
                      ),
                  ],
                  onChanged: (v) => set(() => role = v ?? role),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
    final body = {
      'action': 'create',
      'username': user.text.trim(),
      'email': email.text.trim(),
      'password': pass.text,
      'role': role,
    };
    user.dispose();
    email.dispose();
    pass.dispose();
    if (ok == true) await _mutate(body);
  }

  void _menu(Map<String, dynamic> a) {
    final me = context.read<Session>().admin;
    final self = a['username'] == me?.username;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                str(a['username']),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(str(a['email'], 'Không có email')),
            ),
            const Divider(),
            if (!self)
              RadioGroup<String>(
                groupValue: str(a['role']),
                onChanged: (v) {
                  Navigator.pop(sheet);
                  _mutate({'action': 'set_role', 'id': a['id'], 'role': v});
                },
                child: Column(
                  children: [
                    for (final r in _roles)
                      RadioListTile<String>(
                        value: r,
                        title: Text('Vai trò: ${roleLabels[r] ?? r}'),
                      ),
                  ],
                ),
              ),
            if (!self)
              ListTile(
                leading: Icon(
                  a['is_active'] == true ? Icons.lock_outline : Icons.lock_open,
                  color: AppColors.warning,
                ),
                title: Text(
                  a['is_active'] == true
                      ? 'Khoá tài khoản'
                      : 'Mở khoá tài khoản',
                ),
                onTap: () {
                  Navigator.pop(sheet);
                  _mutate({'action': 'toggle_active', 'id': a['id']});
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.phonelink_erase,
                color: AppColors.danger,
              ),
              title: Text(
                'Đăng xuất mọi phiên app (${a['app_sessions'] ?? 0})',
              ),
              onTap: () {
                Navigator.pop(sheet);
                _mutate({'action': 'revoke_tokens', 'id': a['id']});
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Xem nhật ký thao tác'),
              onTap: () {
                Navigator.pop(sheet);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AuditLogsScreen(admin: str(a['username'])),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSuper = _d?['is_super_admin'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Quản trị viên')),
      floatingActionButton: isSuper
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.person_add),
              label: const Text('Thêm admin'),
            )
          : null,
      body: _d == null
          ? (_error != null
                ? ErrorView(_error!, onRetry: _load)
                : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  if (!isSuper)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Chỉ Super Admin mới thay đổi được quản trị viên. Phân quyền chi tiết theo module chỉnh trên web.',
                        style: TextStyle(color: AppColors.dim, fontSize: 12),
                      ),
                    ),
                  for (final a in asList(_d!['rows']))
                    ListTile(
                      onTap: isSuper ? () => _menu(a) : null,
                      leading: Avatar(name: str(a['username'])),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              str(a['username']),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Pill(
                            roleLabels[a['role']] ?? str(a['role'], '—'),
                            color: roleColors[a['role']] ?? AppColors.dim,
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (a['is_active'] != true)
                              const Pill('Đã khoá', color: AppColors.danger),
                            Pill(
                              a['totp_enabled'] == true ? '2FA' : 'Không 2FA',
                              color: a['totp_enabled'] == true
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                            Text(
                              'Đăng nhập ${timeAgo(a['last_login'])}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: isSuper ? const Icon(Icons.more_vert) : null,
                    ),
                ],
              ),
            ),
    );
  }
}
