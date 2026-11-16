import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../widgets/common.dart';
import 'user_detail_screen.dart';

class ModerationScreen extends StatelessWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final tabs = [
      if (s.can('reports.view')) ('Báo cáo', const ReportsTab()),
      if (s.can('comments.view')) ('Bình luận', const CommentsTab()),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kiểm duyệt'),
          bottom: TabBar(tabs: [for (final t in tabs) Tab(text: t.$1)]),
        ),
        body: TabBarView(children: [for (final t in tabs) t.$2]),
      ),
    );
  }
}

// ── Comments ──────────────────────────────────────────────────────────
class CommentsTab extends StatefulWidget {
  const CommentsTab({super.key});
  @override
  State<CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<CommentsTab>
    with AutomaticKeepAliveClientMixin {
  final _list = GlobalKey<PagedListState>();
  String _search = '';
  String _status = '';
  final _selected = <String>{};

  @override
  bool get wantKeepAlive => true;

  Future<({List<Map<String, dynamic>> rows, bool hasMore, int? total})> _fetch(
    int page,
  ) async {
    final r = await AdminApi.I.get(
      'm/comments/',
      query: {'page': page, 'limit': 25, 'search': _search, 'status': _status},
    );
    return (
      rows: asList(r['rows']),
      hasMore: r['has_more'] == true,
      total: r['total'] as int?,
    );
  }

  void _reload() {
    _selected.clear();
    _list.currentState?.refresh();
  }

  Future<void> _single(Map<String, dynamic> c, String action) async {
    final id = idOf(c);
    if (action == 'delete' &&
        !await confirm(
          context,
          'Xoá bình luận?',
          'Xoá vĩnh viễn bình luận này và các trả lời của nó.',
        )) {
      return;
    }
    final r = await runAction(
      () => AdminApi.I.post('mongo/comments/$id/$action/'),
    );
    if (r == null) return;
    if (action == 'delete') {
      _list.currentState?.removeWhere((e) => idOf(e) == id);
    } else {
      c['isDeleted'] = action == 'hide';
      _list.currentState?.update();
    }
  }

  Future<void> _bulk(String action) async {
    if (_selected.isEmpty) return;
    if (action == 'delete' &&
        !await confirm(
          context,
          'Xoá ${_selected.length} bình luận?',
          'Không thể hoàn tác.',
        )) {
      return;
    }
    final r = await runAction(
      () => AdminApi.I.post(
        'bulk-action/',
        body: {
          'collection': 'comments',
          'action': action,
          'ids': _selected.toList(),
        },
      ),
      success: 'Đã cập nhật ${_selected.length} bình luận',
    );
    if (r != null) _reload();
  }

  void _menu(Map<String, dynamic> c) {
    final s = context.read<Session>();
    final hidden = c['isDeleted'] == true;
    final user = asMap(c['user']);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                str(c['content']),
                style: const TextStyle(fontSize: 15),
              ),
            ),
            if (s.can('comments.edit'))
              ListTile(
                leading: Icon(hidden ? Icons.visibility : Icons.visibility_off),
                title: Text(hidden ? 'Khôi phục (hiện lại)' : 'Ẩn bình luận'),
                onTap: () {
                  Navigator.pop(sheet);
                  _single(c, hidden ? 'restore' : 'hide');
                },
              ),
            if (s.can('comments.delete'))
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Xoá vĩnh viễn',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () {
                  Navigator.pop(sheet);
                  _single(c, 'delete');
                },
              ),
            if (user.isNotEmpty && s.can('users.view'))
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(
                  'Xem người viết: ${str(user['name'], str(user['email']))}',
                ),
                onTap: () {
                  Navigator.pop(sheet);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserDetailScreen(userId: idOf(user)),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.data_object),
              title: const Text('Dữ liệu gốc'),
              onTap: () {
                Navigator.pop(sheet);
                showJsonSheet(context, 'Bình luận', c);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = context.watch<Session>();
    return Column(
      children: [
        Expanded(
          child: PagedList(
            key: _list,
            fetch: _fetch,
            emptyText: 'Không có bình luận',
            header: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: SearchField(
                    hint: 'Tìm nội dung bình luận',
                    onChanged: (v) {
                      _search = v;
                      _reload();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '', label: Text('Tất cả')),
                      ButtonSegment(value: 'visible', label: Text('Đang hiện')),
                      ButtonSegment(value: 'hidden', label: Text('Đã ẩn')),
                    ],
                    selected: {_status},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) {
                      setState(() => _status = v.first);
                      _reload();
                    },
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
            itemBuilder: (context, c, _) {
              final id = idOf(c);
              final user = asMap(c['user']);
              final sel = _selected.contains(id);
              return ListTile(
                selected: sel,
                selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                onTap: _selected.isNotEmpty
                    ? () => setState(
                        () => sel ? _selected.remove(id) : _selected.add(id),
                      )
                    : () => _menu(c),
                onLongPress: () => setState(
                  () => sel ? _selected.remove(id) : _selected.add(id),
                ),
                leading: sel
                    ? const CircleAvatar(child: Icon(Icons.check))
                    : Avatar(
                        url: str(user['avatar']),
                        name: str(user['name'], '?'),
                      ),
                title: Text(
                  str(c['content']),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    decoration: c['isDeleted'] == true
                        ? TextDecoration.lineThrough
                        : null,
                    color: c['isDeleted'] == true ? AppColors.dim : null,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        str(user['name'], 'Ẩn danh'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      Pill(
                        '${c['type'] == 'tv' ? 'TV' : 'Phim'} #${str(c['movieId'])}',
                      ),
                      if (c['parentId'] != null)
                        const Pill('Trả lời', color: AppColors.info),
                      if (c['isDeleted'] == true)
                        const Pill('Đã ẩn', color: AppColors.danger),
                      Text(
                        '♥ ${(c['likes'] as List?)?.length ?? c['likes'] ?? 0} · ${timeAgo(c['createdAt'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_selected.isNotEmpty)
          Material(
            color: AppColors.surface2,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => setState(_selected.clear),
                    icon: const Icon(Icons.close),
                  ),
                  Text('${_selected.length} đã chọn'),
                  const Spacer(),
                  if (s.can('comments.edit')) ...[
                    TextButton(
                      onPressed: () => _bulk('hide'),
                      child: const Text('Ẩn'),
                    ),
                    TextButton(
                      onPressed: () => _bulk('restore'),
                      child: const Text('Hiện'),
                    ),
                  ],
                  if (s.can('comments.delete'))
                    TextButton(
                      onPressed: () => _bulk('delete'),
                      child: const Text(
                        'Xoá',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Reports ───────────────────────────────────────────────────────────
const _reportStatus = {
  'pending': ('Chờ xử lý', AppColors.warning),
  'reviewing': ('Đang xem xét', AppColors.info),
  'resolved': ('Đã xử lý', AppColors.success),
  'dismissed': ('Bỏ qua', AppColors.muted),
};

const _reasonLabels = {
  'spam': 'Spam',
  'harassment': 'Quấy rối',
  'hate_speech': 'Thù ghét',
  'spoiler': 'Spoiler',
  'inappropriate': 'Không phù hợp',
  'other': 'Khác',
};

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});
  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab>
    with AutomaticKeepAliveClientMixin {
  final _list = GlobalKey<PagedListState>();
  String _status = 'pending';
  Map<String, dynamic> _counts = {};

  @override
  bool get wantKeepAlive => true;

  Future<({List<Map<String, dynamic>> rows, bool hasMore, int? total})> _fetch(
    int page,
  ) async {
    final r = await AdminApi.I.get(
      'm/reports/',
      query: {'page': page, 'limit': 20, 'status': _status},
    );
    if (page == 1 && mounted) setState(() => _counts = asMap(r['counts']));
    return (
      rows: asList(r['rows']),
      hasMore: r['has_more'] == true,
      total: r['total'] as int?,
    );
  }

  Future<void> _action(
    Map<String, dynamic> rep,
    String action, {
    Map<String, dynamic> extra = const {},
  }) async {
    final r = await runAction(
      () => AdminApi.I.post(
        'm/reports/${idOf(rep)}/action/',
        body: {'action': action, ...extra},
      ),
    );
    if (r != null) _list.currentState?.refresh();
  }

  Future<void> _banAuthor(Map<String, dynamic> rep) async {
    final v = await promptFields(
      context,
      'Cấm tác giả',
      ['Lý do', 'Số giờ (0 = vĩnh viễn)'],
      initial: [
        _reasonLabels[rep['reasonCategory']] ?? str(rep['reason']),
        '0',
      ],
      ok: 'Cấm',
    );
    if (v == null) return;
    await _action(
      rep,
      'ban_author',
      extra: {
        'ban_reason': v[0],
        'ban_duration_hours': int.tryParse(v[1]) ?? 0,
        'hide_comment': true,
      },
    );
  }

  void _open(Map<String, dynamic> rep) {
    final s = context.read<Session>();
    final comment = asMap(rep['comment']);
    final canEdit = s.can('reports.edit');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheet) {
        void go(String action) {
          Navigator.pop(sheet);
          _action(rep, action);
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _reasonLabels[rep['reasonCategory']] ??
                            str(rep['reasonCategory'], 'Báo cáo'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${str(rep['reporterName'], 'Ẩn danh')} báo cáo ${str(rep['reportedUserName'], 'người dùng')} · ${timeAgo(rep['createdAt'])}',
                        style: const TextStyle(color: AppColors.dim),
                      ),
                      if (str(rep['reason']).isNotEmpty ||
                          str(rep['details']).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          [
                            str(rep['reason']),
                            str(rep['details']),
                          ].where((e) => e.isNotEmpty).join('\n'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          str(
                            comment['content'],
                            str(rep['targetDetail'], '(nội dung không còn)'),
                          ),
                          style: TextStyle(
                            decoration: comment['isDeleted'] == true
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (str(rep['resolvedBy']).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Xử lý bởi ${rep['resolvedBy']} · ${str(rep['actionTaken'])} · ${str(rep['resolutionNote'])}',
                          style: const TextStyle(
                            color: AppColors.dim,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (canEdit) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.visibility_off),
                    title: const Text('Ẩn bình luận & đóng báo cáo'),
                    onTap: () => go('hide_comment'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.restore),
                    title: const Text('Khôi phục bình luận'),
                    onTap: () => go('restore_comment'),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    title: const Text(
                      'Xoá bình luận',
                      style: TextStyle(color: AppColors.danger),
                    ),
                    onTap: () => go('delete_comment'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.block, color: AppColors.danger),
                    title: const Text(
                      'Cấm tác giả',
                      style: TextStyle(color: AppColors.danger),
                    ),
                    onTap: () {
                      Navigator.pop(sheet);
                      _banAuthor(rep);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.manage_search),
                    title: const Text('Đánh dấu đang xem xét'),
                    onTap: () => go('reviewing'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: const Text('Đánh dấu đã xử lý'),
                    onTap: () => go('resolved'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.do_not_disturb_on_outlined),
                    title: const Text('Bỏ qua báo cáo'),
                    onTap: () => go('dismissed'),
                  ),
                ],
                if (str(rep['reportedUserId']).isNotEmpty &&
                    s.can('users.view'))
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Xem người bị báo cáo'),
                    onTap: () {
                      Navigator.pop(sheet);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserDetailScreen(
                            userId: str(rep['reportedUserId']),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PagedList(
      key: _list,
      fetch: _fetch,
      emptyText: 'Không có báo cáo',
      header: SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          children: [
            for (final e in [
              ..._reportStatus.entries.map((e) => (e.key, e.value.$1)),
              ('', 'Tất cả'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    e.$1.isEmpty ? e.$2 : '${e.$2} (${_counts[e.$1] ?? 0})',
                  ),
                  selected: _status == e.$1,
                  onSelected: (_) {
                    setState(() => _status = e.$1);
                    _list.currentState?.refresh();
                  },
                ),
              ),
          ],
        ),
      ),
      itemBuilder: (context, rep, _) {
        final st = _reportStatus[rep['status']] ?? ('?', AppColors.dim);
        final comment = asMap(rep['comment']);
        return ListTile(
          onTap: () => _open(rep),
          leading: const CircleAvatar(
            backgroundColor: AppColors.surface2,
            child: Icon(Icons.flag, color: AppColors.warning),
          ),
          title: Text(
            str(comment['content'], str(rep['targetDetail'], '(nội dung)')),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Pill(st.$1, color: st.$2),
                Pill(
                  _reasonLabels[rep['reasonCategory']] ??
                      str(rep['reasonCategory'], 'khác'),
                  color: AppColors.accent,
                ),
                Text(
                  '${str(rep['reportedUserName'], '?')} · ${timeAgo(rep['createdAt'])}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
