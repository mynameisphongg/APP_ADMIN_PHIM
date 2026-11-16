import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../widgets/common.dart';

// ── Broadcast notification ────────────────────────────────────────────
class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});
  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  final _title = TextEditingController(text: 'Thông báo hệ thống');
  final _msg = TextEditingController();
  final _targets = TextEditingController();
  String _type = 'version_updated';
  String _mode = 'all';
  bool _push = true;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _msg.dispose();
    _targets.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_msg.text.trim().isEmpty) {
      toast('Nhập nội dung thông báo', error: true);
      return;
    }
    final who = _mode == 'all' ? 'TẤT CẢ người dùng' : 'các người dùng đã chọn';
    if (!await confirm(
      context,
      'Gửi thông báo?',
      'Thông báo sẽ được gửi tới $who${_push ? ' kèm push notification' : ''}.',
      ok: 'Gửi',
      danger: false,
    )) {
      return;
    }
    setState(() => _busy = true);
    final r = await runAction(
      () => AdminApi.I.post(
        'm/broadcast/',
        body: {
          'type': _type,
          'title': _title.text,
          'message': _msg.text,
          'target_mode': _mode,
          'target_users': _targets.text,
          'send_expo_push': _push,
        },
      ),
    );
    if (mounted) setState(() => _busy = false);
    if (r != null) _msg.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gửi thông báo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Loại'),
            items: const [
              DropdownMenuItem(
                value: 'version_updated',
                child: Text('Cập nhật phiên bản'),
              ),
              DropdownMenuItem(value: 'system', child: Text('Hệ thống')),
              DropdownMenuItem(value: 'maintenance', child: Text('Bảo trì')),
              DropdownMenuItem(
                value: 'new_content',
                child: Text('Nội dung mới'),
              ),
              DropdownMenuItem(
                value: 'promotion',
                child: Text('Khuyến mãi / sự kiện'),
              ),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Tiêu đề'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _msg,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Nội dung'),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'all',
                label: Text('Tất cả'),
                icon: Icon(Icons.groups),
              ),
              ButtonSegment(
                value: 'specific',
                label: Text('Chọn người'),
                icon: Icon(Icons.person),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
          if (_mode == 'specific') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _targets,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Email hoặc ID người dùng (phân tách bằng dấu phẩy / xuống dòng)',
              ),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _push,
            onChanged: (v) => setState(() => _push = v),
            title: const Text('Gửi push notification (Expo)'),
            subtitle: const Text('Tới các thiết bị đã đăng ký push'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _busy ? null : _send,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('Gửi thông báo'),
          ),
        ],
      ),
    );
  }
}

// ── Platform settings ─────────────────────────────────────────────────
const _settingLabels = {
  'registration_enabled': 'Cho phép đăng ký tài khoản mới',
  'watch_rooms_enabled': 'Bật phòng xem chung',
  'max_rooms': 'Số phòng xem chung tối đa',
  'cache_ttl_seconds': 'TTL cache TMDB (giây)',
  'broadcast_template': 'Tiêu đề thông báo mặc định',
  'maintenance_mode': 'Chế độ bảo trì (chặn app/web)',
  'max_comments_per_user': 'Số bình luận tối đa / người / ngày',
};

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, dynamic>>? _rows;
  final _values = <String, dynamic>{};
  bool _canEdit = false;
  bool _dirty = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await AdminApi.I.get('m/settings/');
      final rows = asList(r['rows']);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _canEdit = r['can_edit'] == true;
        _values
          ..clear()
          ..addEntries(
            rows.map((e) => MapEntry(e['key'].toString(), e['value'])),
          );
        _dirty = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _save() async {
    if (_values['maintenance_mode'] == true &&
        !await confirm(
          context,
          'Bật chế độ bảo trì?',
          'Người dùng sẽ không truy cập được app/web cho tới khi tắt.',
        )) {
      return;
    }
    setState(() => _saving = true);
    final r = await runAction(
      () => AdminApi.I.post('m/settings/', body: _values),
    );
    if (mounted) setState(() => _saving = false);
    if (r != null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cấu hình nền tảng'),
        actions: [
          if (_canEdit)
            TextButton(
              onPressed: _dirty && !_saving ? _save : null,
              child: Text(_saving ? 'Đang lưu...' : 'Lưu'),
            ),
        ],
      ),
      body: _rows == null
          ? (_error != null
                ? ErrorView(_error!, onRetry: _load)
                : const Center(child: CircularProgressIndicator()))
          : ListView(
              children: [
                if (!_canEdit)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Bạn chỉ có quyền xem.',
                      style: TextStyle(color: AppColors.warning),
                    ),
                  ),
                for (final r in _rows!) _tile(r),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Thay đổi được đồng bộ vào MongoDB (systemsettings) để server Node đọc trực tiếp.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tile(Map<String, dynamic> r) {
    final key = r['key'].toString();
    final label = _settingLabels[key] ?? key;
    final desc = str(r['description']);
    final v = _values[key];
    void set(dynamic nv) => setState(() {
      _values[key] = nv;
      _dirty = true;
    });
    if (r['type'] == 'bool') {
      return SwitchListTile(
        value: v == true,
        onChanged: _canEdit ? set : null,
        title: Text(label),
        subtitle: Text(
          desc,
          style: const TextStyle(fontSize: 12, color: AppColors.dim),
        ),
        activeThumbColor: key == 'maintenance_mode' ? AppColors.danger : null,
      );
    }
    return ListTile(
      title: Text(label),
      subtitle: Text(
        '$desc\nHiện tại: $v',
        style: const TextStyle(fontSize: 12, color: AppColors.dim),
      ),
      isThreeLine: true,
      trailing: _canEdit ? const Icon(Icons.edit_outlined) : null,
      onTap: !_canEdit
          ? null
          : () async {
              final res = await promptFields(
                context,
                label,
                ['Giá trị'],
                initial: ['$v'],
              );
              if (res == null) return;
              if (r['type'] == 'int') {
                final n = int.tryParse(res[0].trim());
                if (n == null) {
                  toast('Phải là số nguyên', error: true);
                  return;
                }
                set(n);
              } else {
                set(res[0]);
              }
            },
    );
  }
}

// ── Stream servers ────────────────────────────────────────────────────
class ServersScreen extends StatefulWidget {
  const ServersScreen({super.key});
  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() => _busy = true);
    try {
      final r = await AdminApi.I.get(
        'm/servers/',
        query: {if (refresh) 'refresh': '1'},
      );
      if (mounted) {
        setState(() {
          _d = r;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    setState(() => _busy = true);
    final r = await runAction(
      () => AdminApi.I.get('servers/vidsrc/scan/'),
      success: 'Đã quét lại domain VidSrc',
    );
    if (r != null) await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _select(String domain) async {
    if (!await confirm(
      context,
      'Đổi domain VidSrc?',
      'Server 2 sẽ dùng $domain cho mọi người dùng.',
      ok: 'Đổi',
      danger: false,
    )) {
      return;
    }
    final r = await runAction(
      () => AdminApi.I.post(
        'servers/vidsrc/select/',
        form: true,
        body: {'domain': domain},
      ),
      success: 'Đã chọn $domain',
    );
    if (r != null) await _load();
  }

  Future<void> _toggleAuto(bool v) async {
    final r = await runAction(
      () => AdminApi.I.post(
        'servers/vidsrc/toggle-auto/',
        form: true,
        body: {'auto': '$v'},
      ),
      success: v ? 'Bật tự động chọn domain' : 'Tắt tự động chọn domain',
    );
    if (r != null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server phát phim'),
        actions: [
          IconButton(
            onPressed: _busy ? null : () => _load(refresh: true),
            icon: const Icon(Icons.network_ping),
            tooltip: 'Ping lại',
          ),
        ],
      ),
      body: _d == null
          ? (_error != null
                ? ErrorView(_error!, onRetry: _load)
                : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: _body(),
            ),
    );
  }

  Widget _body() {
    final clusters = asMap(_d!['clusters']);
    final vid = asMap(_d!['vidsrc']);
    final scraped = asMap(vid['scraped_domains']);
    final canEdit = _d!['can_edit'] == true;
    final active = str(vid['active_domain']);
    final domains = [
      ...asList(scraped['active_group']),
      ...asList(scraped['old_group']),
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (_busy) const LinearProgressIndicator(),
        const SectionTitle('Tình trạng cụm server'),
        for (final e in clusters.entries)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Card(
              child: ListTile(
                leading: Icon(
                  asMap(e.value)['ok'] == true
                      ? Icons.check_circle
                      : Icons.error,
                  color: asMap(e.value)['ok'] == true
                      ? AppColors.success
                      : AppColors.danger,
                ),
                title: Text(str(asMap(e.value)['name'], e.key)),
                subtitle: Text(
                  '${str(asMap(e.value)['endpoint'])}\n${str(asMap(e.value)['protocol'])} · ${str(asMap(e.value)['quality'])}',
                ),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${asMap(e.value)['latency'] ?? '-'} ms',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${asMap(e.value)['status'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.dim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SectionTitle(
          'VidSrc (Server 2)',
          trailing: canEdit
              ? TextButton.icon(
                  onPressed: _busy ? null : _scan,
                  icon: const Icon(Icons.radar),
                  label: const Text('Quét'),
                )
              : null,
        ),
        KV('Domain đang dùng', active.isEmpty ? '—' : active),
        KV(
          'Lần quét cuối',
          str(vid['last_scraped'], str(scraped['scraped_at'], '—')),
        ),
        KV(
          'Dự phòng',
          (vid['backup_domains'] as List? ?? []).join(', ').isEmpty
              ? '—'
              : (vid['backup_domains'] as List).join(', '),
        ),
        SwitchListTile(
          value: vid['auto_update'] == true,
          onChanged: canEdit ? _toggleAuto : null,
          title: const Text('Tự động chọn domain nhanh nhất'),
          subtitle: const Text('Quét lại mỗi 20 phút'),
        ),
        if (domains.isNotEmpty) const SectionTitle('Domain khả dụng'),
        for (final dm in domains)
          ListTile(
            dense: true,
            leading: Icon(
              dm['ok'] == true ? Icons.circle : Icons.circle_outlined,
              size: 14,
              color: dm['ok'] == true ? AppColors.success : AppColors.danger,
            ),
            title: Text(str(dm['url'])),
            subtitle: Text(
              '${dm['latency'] ?? '-'} ms · ${str(dm['status'])}${dm['error'] != null ? ' · ${dm['error']}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: str(dm['url']) == active
                ? const Pill('Đang dùng', color: AppColors.success)
                : (canEdit && dm['ok'] == true
                      ? TextButton(
                          onPressed: () => _select(str(dm['url'])),
                          child: const Text('Dùng'),
                        )
                      : null),
          ),
      ],
    );
  }
}

// ── Upstash cache ─────────────────────────────────────────────────────
class CacheScreen extends StatefulWidget {
  const CacheScreen({super.key});
  @override
  State<CacheScreen> createState() => _CacheScreenState();
}

class _CacheScreenState extends State<CacheScreen> {
  final _list = GlobalKey<PagedListState>();
  String _q = '';
  String _cat = '';
  Map<String, dynamic> _stats = {};
  List<String> _cats = [];
  int? _total;

  Future<({List<Map<String, dynamic>> rows, bool hasMore, int? total})> _fetch(
    int page,
  ) async {
    final r = await AdminApi.I.get(
      'cache/list/',
      query: {
        'page': page,
        'q': _q,
        'category': _cat,
        if (page == 1) 'refresh': '1',
      },
    );
    final keys = asList(r['keys']);
    if (mounted && page == 1) {
      setState(() {
        _stats = asMap(r['stats']);
        _cats = ((r['categories'] as List?) ?? [])
            .map((e) => e.toString())
            .toList();
        _total = r['total'] as int?;
      });
    }
    return (
      rows: keys,
      hasMore: page < ((r['total_pages'] as int?) ?? 1),
      total: r['total'] as int?,
    );
  }

  Future<void> _flush() async {
    if (!await confirm(
      context,
      'Xoá toàn bộ cache TMDB?',
      'Server sẽ phải gọi lại TMDB cho mọi trang — tạm thời chậm hơn.',
    )) {
      return;
    }
    final r = await runAction(
      () => AdminApi.I.post('cache/', body: {'action': 'flush'}),
    );
    if (r != null) _list.currentState?.refresh();
  }

  Future<void> _view(String key) async {
    try {
      final r = await AdminApi.I.post(
        'cache/',
        body: {'action': 'get', 'key': key},
      );
      if (mounted) {
        showJsonSheet(
          context,
          key,
          r['data'],
          actions: [
            if (context.read<Session>().can('cache.delete'))
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: () {
                  Navigator.pop(context);
                  _delete(key);
                },
              ),
          ],
        );
      }
    } on ApiException catch (e) {
      toast(e.message, error: true);
    }
  }

  Future<void> _delete(String key) async {
    final r = await runAction(
      () => AdminApi.I.post('cache/', body: {'action': 'delete', 'key': key}),
    );
    if (r != null) _list.currentState?.removeWhere((e) => e['key'] == key);
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = context.watch<Session>().can('cache.delete');
    return Scaffold(
      appBar: AppBar(
        title: Text('Cache${_total != null ? ' · ${fmtNum(_total)}' : ''}'),
        actions: [
          if (canDelete)
            IconButton(
              tooltip: 'Xoá toàn bộ',
              onPressed: _flush,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: PagedList(
        key: _list,
        fetch: _fetch,
        emptyText: 'Không có key nào',
        header: Column(
          children: [
            if (_stats.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Dung lượng ${_stats['storage_used']} / ${_stats['storage_max']} · ${fmtNum(_stats['commands'])} lệnh',
                  style: const TextStyle(color: AppColors.dim, fontSize: 12),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: SearchField(
                hint: 'Lọc theo key',
                onChanged: (v) {
                  _q = v;
                  _list.currentState?.refresh();
                },
              ),
            ),
            if (_cats.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final c in ['', ..._cats])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(c.isEmpty ? 'Tất cả' : c),
                          selected: _cat == c,
                          onSelected: (_) {
                            setState(() => _cat = c);
                            _list.currentState?.refresh();
                          },
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        itemBuilder: (context, k, _) => ListTile(
          dense: true,
          title: Text(
            str(k['endpoint'], str(k['key'])),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              str(k['category']),
              if (k['ttl'] != null) 'TTL ${k['ttl']}s',
              str(k['params']),
            ].where((e) => e.isNotEmpty).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _view(str(k['key'])),
          trailing: canDelete
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _delete(str(k['key'])),
                )
              : null,
        ),
      ),
    );
  }
}

// ── My app sessions (tokens) ──────────────────────────────────────────
class MyTokensScreen extends StatefulWidget {
  const MyTokensScreen({super.key});
  @override
  State<MyTokensScreen> createState() => _MyTokensScreenState();
}

class _MyTokensScreenState extends State<MyTokensScreen> {
  late Future<Map<String, dynamic>> _f = AdminApi.I.get('m/tokens/');

  void _reload() => setState(() => _f = AdminApi.I.get('m/tokens/'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phiên đăng nhập app'),
        actions: [
          TextButton(
            onPressed: () async {
              if (await confirm(
                context,
                'Đăng xuất thiết bị khác?',
                'Mọi phiên app khác của bạn sẽ bị thu hồi.',
              )) {
                await runAction(
                  () =>
                      AdminApi.I.post('m/tokens/', body: {'all_others': true}),
                  success: 'Đã thu hồi',
                );
                _reload();
              }
            },
            child: const Text('Thu hồi khác'),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _f,
        builder: (c, snap) {
          if (snap.hasError) {
            return ErrorView('${snap.error}', onRetry: _reload);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = asList(snap.data!['rows']);
          return ListView(
            children: [
              for (final t in rows)
                ListTile(
                  leading: Icon(
                    t['current'] == true
                        ? Icons.smartphone
                        : Icons.devices_other,
                    color: t['current'] == true ? AppColors.success : null,
                  ),
                  title: Text(
                    '${str(t['device'], 'Thiết bị')}${t['current'] == true ? ' (máy này)' : ''}',
                  ),
                  subtitle: Text(
                    '${str(t['ip'], '?')} · dùng ${timeAgo(t['last_used_at'] ?? t['created_at'])}\nHết hạn ${fmtDate(t['expires_at'])}',
                  ),
                  isThreeLine: true,
                  trailing: t['current'] == true
                      ? null
                      : IconButton(
                          icon: const Icon(
                            Icons.logout,
                            color: AppColors.danger,
                          ),
                          onPressed: () async {
                            await runAction(
                              () => AdminApi.I.post(
                                'm/tokens/',
                                body: {'id': t['id']},
                              ),
                              success: 'Đã thu hồi',
                            );
                            _reload();
                          },
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}
