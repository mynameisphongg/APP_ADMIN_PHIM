import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'user_detail_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _list = GlobalKey<PagedListState>();
  String _search = '';
  String _verified = '';
  String _banned = '';
  String _auth = '';
  String _sort = '';
  int? _total;
  Map<String, dynamic> _stats = {};

  Future<({List<Map<String, dynamic>> rows, bool hasMore, int? total})> _fetch(
    int page,
  ) async {
    final r = await AdminApi.I.get(
      'm/users/',
      query: {
        'page': page,
        'limit': 25,
        'search': _search,
        'verified': _verified,
        'banned': _banned,
        'auth_type': _auth,
        'sort': _sort,
      },
    );
    if (page == 1 && mounted) setState(() => _stats = asMap(r['stats']));
    return (
      rows: asList(r['rows']),
      hasMore: r['has_more'] == true,
      total: r['total'] as int?,
    );
  }

  void _reload() => _list.currentState?.refresh();

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Người dùng${_total != null ? ' · ${fmtNum(_total)}' : ''}',
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Sắp xếp',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (v) {
              setState(() => _sort = v);
              _reload();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: '', child: Text('Mới nhất')),
              PopupMenuItem(value: 'oldest', child: Text('Cũ nhất')),
              PopupMenuItem(value: 'name', child: Text('Tên A→Z')),
              PopupMenuItem(value: 'email', child: Text('Email A→Z')),
            ],
          ),
        ],
      ),
      body: PagedList(
        key: _list,
        fetch: _fetch,
        onTotal: (t) => setState(() => _total = t),
        emptyText: 'Không tìm thấy người dùng',
        header: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SearchField(
                hint: 'Tên, email, username hoặc ID',
                onChanged: (v) {
                  _search = v;
                  _reload();
                },
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _chip(
                    'Bị cấm (${fmtNum(_stats['banned'])})',
                    _banned == 'true',
                    () {
                      setState(() => _banned = _banned == 'true' ? '' : 'true');
                      _reload();
                    },
                  ),
                  _chip(
                    'Đã xác minh (${fmtNum(_stats['verified'])})',
                    _verified == 'true',
                    () {
                      setState(
                        () => _verified = _verified == 'true' ? '' : 'true',
                      );
                      _reload();
                    },
                  ),
                  _chip('Chưa xác minh', _verified == 'false', () {
                    setState(
                      () => _verified = _verified == 'false' ? '' : 'false',
                    );
                    _reload();
                  }),
                  _chip(
                    'Google (${fmtNum(_stats['google'])})',
                    _auth == 'google',
                    () {
                      setState(() => _auth = _auth == 'google' ? '' : 'google');
                      _reload();
                    },
                  ),
                  _chip('Email', _auth == 'email', () {
                    setState(() => _auth = _auth == 'email' ? '' : 'email');
                    _reload();
                  }),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
        itemBuilder: (context, u, _) => UserTile(
          user: u,
          onTap: () async {
            final changed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => UserDetailScreen(userId: idOf(u)),
              ),
            );
            if (changed == true) _reload();
          },
        ),
      ),
    );
  }
}

class UserTile extends StatelessWidget {
  const UserTile({super.key, required this.user, this.onTap});
  final Map<String, dynamic> user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final u = user;
    return ListTile(
      onTap: onTap,
      leading: Avatar(
        url: str(u['avatar']),
        name: str(u['name'], str(u['email'])),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              str(u['name'], '(chưa đặt tên)'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (u['isEmailVerified'] == true) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified, size: 15, color: AppColors.info),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(str(u['email']), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (u['isBanned'] == true)
                const Pill(
                  'Bị cấm',
                  color: AppColors.danger,
                  icon: Icons.block,
                ),
              Pill(
                u['authType'] == 'google' ? 'Google' : 'Email',
                color: AppColors.dim,
              ),
              if (u['watchlist_count'] != null)
                Pill(
                  '${u['watchlist_count']} watchlist',
                  color: AppColors.muted,
                ),
              Pill(timeAgo(u['createdAt']), color: AppColors.muted),
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
