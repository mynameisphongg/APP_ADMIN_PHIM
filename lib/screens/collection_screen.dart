import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'user_detail_screen.dart';

const collectionIcons = <String, IconData>{
  'users': Icons.people_alt_outlined,
  'sessions': Icons.devices_outlined,
  'comments': Icons.forum_outlined,
  'userreports': Icons.flag_outlined,
  'watchprogresses': Icons.play_circle_outline,
  'streamhistories': Icons.stream,
  'searchhistories': Icons.manage_search,
  'notifications': Icons.notifications_none,
  'passwordresettokens': Icons.password,
  'blacklistedtokens': Icons.key_off_outlined,
  'gameprofiles': Icons.sports_esports_outlined,
  'gamehistories': Icons.history,
  'dailychallenges': Icons.emoji_events_outlined,
  'dailysubmissions': Icons.assignment_turned_in_outlined,
  'systemsettings': Icons.tune,
};

/// Index of every MongoDB collection the admin may view.
class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});
  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  late Future<Map<String, dynamic>> _f = AdminApi.I.get('m/collections/');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dữ liệu MongoDB')),
      body: FutureBuilder(
        future: _f,
        builder: (c, snap) {
          if (snap.hasError) {
            return ErrorView(
              '${snap.error}',
              onRetry: () =>
                  setState(() => _f = AdminApi.I.get('m/collections/')),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = asList(snap.data!['rows']);
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _f = AdminApi.I.get('m/collections/'));
              await _f;
            },
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) =>
                  const Divider(indent: 16, endIndent: 16),
              itemBuilder: (c, i) {
                final r = rows[i];
                return ListTile(
                  leading: Icon(collectionIcons[r['key']] ?? Icons.storage),
                  title: Text(str(r['label'])),
                  subtitle: Text(str(r['key'])),
                  trailing: Text(
                    fmtNum(r['count']),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CollectionScreen(
                        collection: str(r['key']),
                        label: str(r['label']),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Generic browser for one collection: search, infinite scroll, JSON detail, delete.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({
    super.key,
    required this.collection,
    required this.label,
    this.userId,
  });
  final String collection;
  final String label;
  final String? userId;
  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _list = GlobalKey<PagedListState>();
  String _q = '';
  bool _canDelete = false;
  int? _total;
  final _selected = <String>{};

  Future<({List<Map<String, dynamic>> rows, bool hasMore, int? total})> _fetch(
    int page,
  ) async {
    final r = await AdminApi.I.get(
      'm/collections/${widget.collection}/',
      query: {'page': page, 'limit': 30, 'q': _q, 'user_id': widget.userId},
    );
    if (mounted && page == 1) {
      setState(() => _canDelete = r['can_delete'] == true);
    }
    return (
      rows: asList(r['rows']),
      hasMore: r['has_more'] == true,
      total: r['total'] as int?,
    );
  }

  bool get _deletable =>
      _canDelete &&
      widget.collection != 'users' &&
      widget.collection != 'systemsettings';

  Future<void> _delete(List<String> ids) async {
    if (!await confirm(
      context,
      'Xoá ${ids.length} bản ghi?',
      'Xoá vĩnh viễn khỏi "${widget.label}". Không thể hoàn tác.',
    )) {
      return;
    }
    final r = await runAction(
      () => AdminApi.I.post(
        'm/collections/${widget.collection}/delete/',
        body: {'ids': ids},
      ),
    );
    if (r != null) {
      _selected.clear();
      _list.currentState?.removeWhere((e) => ids.contains(idOf(e)));
    }
  }

  String _title(Map<String, dynamic> r) {
    for (final k in [
      'title',
      'name',
      'content',
      'message',
      'email',
      'username',
      'displayName',
      'key',
      'reason',
      'deviceName',
    ]) {
      final v = r[k];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    if (r['history'] is List && (r['history'] as List).isNotEmpty) {
      final h = (r['history'] as List).first;
      return 'Tìm: ${h is Map ? h['query'] : h}';
    }
    return idOf(r);
  }

  String _subtitle(Map<String, dynamic> r) {
    final parts = <String>[];
    for (final k in [
      'type',
      'status',
      'server',
      'browser',
      'os',
      'ipAddress',
      'rating',
      'date',
    ]) {
      final v = r[k];
      if (v != null && v.toString().isNotEmpty && v is! Map && v is! List) {
        parts.add('$k: $v');
      }
      if (parts.length >= 3) break;
    }
    final date =
        r['updatedAt'] ??
        r['lastActive'] ??
        r['lastWatched'] ??
        r['createdAt'] ??
        r['updated_at'] ??
        r['lastCreatedAt'];
    if (date != null) parts.add(timeAgo(date));
    return parts.join(' · ');
  }

  String? _userRef(Map<String, dynamic> r) {
    for (final k in ['userId', 'user_id', 'user', 'recipient']) {
      final v = r[k];
      if (v is String && v.length == 24) return v;
      if (v is Map && v['_id'] is String) return v['_id'];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.label}${_total != null ? ' · ${fmtNum(_total)}' : ''}',
        ),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              tooltip: 'Xoá đã chọn',
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: () => _delete(_selected.toList()),
            ),
        ],
      ),
      body: PagedList(
        key: _list,
        fetch: _fetch,
        onTotal: (t) => setState(() => _total = t),
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SearchField(
            hint: 'Tìm kiếm hoặc dán ObjectId',
            onChanged: (v) {
              _q = v;
              _selected.clear();
              _list.currentState?.refresh();
            },
          ),
        ),
        itemBuilder: (context, r, _) {
          final id = idOf(r);
          final sel = _selected.contains(id);
          final uid = _userRef(r);
          return ListTile(
            selected: sel,
            selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
            leading: sel
                ? const CircleAvatar(child: Icon(Icons.check))
                : CircleAvatar(
                    backgroundColor: AppColors.surface2,
                    child: Icon(
                      collectionIcons[widget.collection] ??
                          Icons.description_outlined,
                      size: 20,
                    ),
                  ),
            title: Text(
              _title(r),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _subtitle(r),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onLongPress: _deletable
                ? () => setState(
                    () => sel ? _selected.remove(id) : _selected.add(id),
                  )
                : null,
            onTap: _selected.isNotEmpty
                ? () => setState(
                    () => sel ? _selected.remove(id) : _selected.add(id),
                  )
                : () => showJsonSheet(
                    context,
                    _title(r),
                    r,
                    actions: [
                      if (uid != null)
                        IconButton(
                          tooltip: 'Xem người dùng',
                          icon: const Icon(Icons.person_search),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => UserDetailScreen(userId: uid),
                              ),
                            );
                          },
                        ),
                      if (widget.collection == 'users')
                        IconButton(
                          tooltip: 'Mở hồ sơ',
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => UserDetailScreen(userId: id),
                              ),
                            );
                          },
                        ),
                      if (_deletable)
                        IconButton(
                          tooltip: 'Xoá',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.danger,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _delete([id]);
                          },
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
