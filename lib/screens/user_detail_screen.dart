import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../widgets/common.dart';
import 'collection_screen.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.userId});
  final String userId;
  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await AdminApi.I.get('m/users/${widget.userId}/');
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

  Map<String, dynamic> get _u => asMap(_d?['user']);

  Future<void> _act(Future<Map<String, dynamic>> Function() fn) async {
    final r = await runAction(fn);
    if (r != null) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _ban() async {
    final reason = TextEditingController();
    var hours = 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Cấm người dùng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Lý do'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: hours,
                decoration: const InputDecoration(labelText: 'Thời hạn'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Vĩnh viễn')),
                  DropdownMenuItem(value: 1, child: Text('1 giờ')),
                  DropdownMenuItem(value: 24, child: Text('1 ngày')),
                  DropdownMenuItem(value: 72, child: Text('3 ngày')),
                  DropdownMenuItem(value: 168, child: Text('7 ngày')),
                  DropdownMenuItem(value: 720, child: Text('30 ngày')),
                ],
                onChanged: (v) => set(() => hours = v ?? 0),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tất cả phiên đăng nhập của người dùng sẽ bị thu hồi.',
                style: TextStyle(color: AppColors.dim, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Cấm'),
            ),
          ],
        ),
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (ok != true) return;
    await _act(
      () => AdminApi.I.post(
        'user-ban/',
        body: {
          'user_id': widget.userId,
          'action': 'ban',
          'reason': text,
          'duration_hours': hours,
        },
      ),
    );
  }

  Future<void> _edit() async {
    final u = _u;
    final v = await promptFields(
      context,
      'Sửa thông tin',
      ['Tên hiển thị', 'Username', 'Email', 'Avatar URL'],
      initial: [
        str(u['name']),
        str(u['username']),
        str(u['email']),
        str(u['avatar']).startsWith('data:') ? '' : str(u['avatar']),
      ],
    );
    if (v == null) return;
    await _act(
      () => AdminApi.I.post(
        'm/users/${widget.userId}/update/',
        body: {
          'name': v[0],
          if (v[1].trim().isNotEmpty) 'username': v[1],
          if (v[2].trim().isNotEmpty) 'email': v[2],
          if (v[3].trim().isNotEmpty) 'avatar': v[3],
        },
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      'Xoá người dùng?',
      'Xoá vĩnh viễn ${str(_u['email'])} cùng toàn bộ bình luận, phiên, lịch sử xem, tìm kiếm, thông báo. Không thể hoàn tác.',
      ok: 'Xoá vĩnh viễn',
    );
    if (!ok || !mounted) return;
    final r = await runAction(
      () => AdminApi.I.post('m/users/${widget.userId}/delete/'),
    );
    if (r != null && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết người dùng'),
          actions: [
            if (_d != null && s.can('users.edit'))
              IconButton(
                tooltip: 'Sửa',
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined),
              ),
            if (_d != null)
              PopupMenuButton<String>(
                onSelected: (v) async {
                  switch (v) {
                    case 'raw':
                      showJsonSheet(context, 'Document người dùng', _u);
                    case 'verify':
                      await _act(
                        () => AdminApi.I.post(
                          'm/users/${widget.userId}/update/',
                          body: {
                            'isEmailVerified': _u['isEmailVerified'] != true,
                          },
                        ),
                      );
                    case 'sessions':
                      if (await confirm(
                        context,
                        'Thu hồi tất cả phiên?',
                        'Người dùng sẽ bị đăng xuất khỏi mọi thiết bị.',
                      )) {
                        await _act(
                          () => AdminApi.I.post(
                            'm/users/${widget.userId}/revoke-sessions/',
                          ),
                        );
                      }
                    case 'delete':
                      await _delete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'raw',
                    child: Text('Xem dữ liệu gốc (JSON)'),
                  ),
                  if (s.can('users.edit'))
                    PopupMenuItem(
                      value: 'verify',
                      child: Text(
                        _u['isEmailVerified'] == true
                            ? 'Bỏ xác minh email'
                            : 'Đánh dấu đã xác minh',
                      ),
                    ),
                  if (s.can('sessions.delete'))
                    const PopupMenuItem(
                      value: 'sessions',
                      child: Text('Đăng xuất mọi thiết bị'),
                    ),
                  if (s.can('users.delete'))
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Xoá người dùng',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                ],
              ),
          ],
        ),
        body: _d == null
            ? (_error != null
                  ? ErrorView(_error!, onRetry: _load)
                  : const Center(child: CircularProgressIndicator()))
            : RefreshIndicator(onRefresh: _load, child: _body(s)),
      ),
    );
  }

  Widget _body(Session s) {
    final u = _u;
    final d = _d!;
    final banned = u['isBanned'] == true;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Avatar(
            url: str(u['avatar']),
            name: str(u['name'], str(u['email'])),
            size: 84,
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            str(u['name'], '(chưa đặt tên)'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        Center(
          child: Text(
            str(u['email']),
            style: const TextStyle(color: AppColors.dim),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            if (banned)
              const Pill('Bị cấm', color: AppColors.danger, icon: Icons.block),
            Pill(
              u['isEmailVerified'] == true
                  ? 'Email đã xác minh'
                  : 'Email chưa xác minh',
              color: u['isEmailVerified'] == true
                  ? AppColors.info
                  : AppColors.warning,
            ),
            Pill(u['authType'] == 'google' ? 'Google' : 'Email/mật khẩu'),
            if ((d['reports_against'] ?? 0) > 0)
              Pill(
                '${d['reports_against']} báo cáo',
                color: AppColors.warning,
                icon: Icons.flag,
              ),
          ],
        ),
        if (banned)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Lý do: ${str(u['banReason'], '—')}\nBởi: ${str(u['bannedBy'], '—')} · ${fmtDate(u['bannedAt'])}\n'
              'Hết hạn: ${u['banExpiresAt'] == null ? 'vĩnh viễn' : fmtDate(u['banExpiresAt'])}',
              style: const TextStyle(height: 1.5),
            ),
          ),
        if (s.can('users.edit'))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: banned
                ? OutlinedButton.icon(
                    onPressed: () => _act(
                      () => AdminApi.I.post(
                        'user-ban/',
                        body: {'user_id': widget.userId, 'action': 'unban'},
                      ),
                    ),
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Gỡ cấm'),
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    onPressed: _ban,
                    icon: const Icon(Icons.block),
                    label: const Text('Cấm người dùng'),
                  ),
          ),
        const SectionTitle('Thông tin'),
        KV('ID', idOf(u)),
        KV('Username', str(u['username'], '—')),
        KV('Ngày tạo', fmtDate(u['createdAt'])),
        KV('Cập nhật', fmtDate(u['updatedAt'])),
        KV('Watchlist', '${(u['watchlist'] as List?)?.length ?? 0} phim'),
        KV(
          'Bạn bè',
          '${u['friends_count'] ?? 0} · lời mời ${u['friendRequests_count'] ?? 0}',
        ),
        KV('Bình luận', fmtNum(d['comments_total'])),
        KV('Đang xem', fmtNum(d['progress_total'])),
        SectionTitle('Phiên đăng nhập (${asList(d['sessions']).length})'),
        if (asList(d['sessions']).isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Không có', style: TextStyle(color: AppColors.dim)),
          ),
        for (final se in asList(d['sessions']))
          ListTile(
            dense: true,
            leading: Icon(
              str(se['deviceType']).contains('mobile')
                  ? Icons.phone_android
                  : Icons.computer,
            ),
            title: Text(
              [
                str(se['deviceName']),
                str(se['browser']),
                str(se['os']),
              ].where((e) => e.isNotEmpty).join(' · ').ifEmpty('Thiết bị'),
            ),
            subtitle: Text(
              '${str(se['ipAddress'], str(se['ip'], ''))} · ${timeAgo(se['lastActive'])}',
            ),
            trailing: s.can('sessions.delete')
                ? IconButton(
                    tooltip: 'Thu hồi',
                    icon: const Icon(Icons.logout, color: AppColors.danger),
                    onPressed: () => _act(
                      () => AdminApi.I.post(
                        'm/users/${widget.userId}/revoke-sessions/',
                        body: {'session_id': idOf(se)},
                      ),
                    ),
                  )
                : null,
            onTap: () => showJsonSheet(context, 'Phiên', se),
          ),
        SectionTitle(
          'Bình luận gần đây',
          trailing: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CollectionScreen(
                  collection: 'comments',
                  label: 'Bình luận của ${str(u['name'])}',
                  userId: widget.userId,
                ),
              ),
            ),
            child: const Text('Tất cả'),
          ),
        ),
        for (final c in asList(d['comments']))
          ListTile(
            dense: true,
            title: Text(
              str(c['content']),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${str(c['type'])} #${str(c['movieId'])} · ${timeAgo(c['createdAt'])}',
            ),
            trailing: c['isDeleted'] == true
                ? const Pill('Đã ẩn', color: AppColors.danger)
                : null,
          ),
        const SectionTitle('Đang xem'),
        for (final p in asList(d['progress']))
          ListTile(
            dense: true,
            leading: const Icon(Icons.play_circle_outline),
            title: Text(str(p['title'], '#${str(p['contentId'])}')),
            subtitle: Text(
              [
                if (p['isTVShow'] == true)
                  'S${p['season'] ?? '?'}E${p['episode'] ?? '?'}',
                if (p['currentTime'] != null && p['duration'] != null)
                  '${((p['currentTime'] as num) / 60).round()}/${((p['duration'] as num) / 60).round()} phút',
                timeAgo(p['lastWatched']),
              ].join(' · '),
            ),
          ),
        if (asList(d['friends']).isNotEmpty) ...[
          const SectionTitle('Bạn bè'),
          for (final f in asList(d['friends']))
            ListTile(
              dense: true,
              leading: Avatar(
                url: str(f['avatar']),
                name: str(f['name']),
                size: 32,
              ),
              title: Text(str(f['name'])),
              subtitle: Text(str(f['email'])),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserDetailScreen(userId: idOf(f)),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
