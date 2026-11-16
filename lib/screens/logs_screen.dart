import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../widgets/common.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key, this.admin});
  final String? admin;
  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final _list = GlobalKey<PagedListState>();
  String _q = '';

  Future<({List<Map<String, dynamic>> rows, bool hasMore, int? total})> _fetch(
    int page,
  ) async {
    final r = await AdminApi.I.get(
      'm/audit-logs/',
      query: {'page': page, 'q': _q, 'admin': widget.admin},
    );
    return (
      rows: asList(r['rows']),
      hasMore: r['has_more'] == true,
      total: r['total'] as int?,
    );
  }

  IconData _icon(String action) {
    if (action.contains('delete')) return Icons.delete_outline;
    if (action.contains('ban')) return Icons.block;
    if (action.contains('login') || action.contains('logout')) {
      return Icons.login;
    }
    if (action.contains('edit') || action.contains('update')) {
      return Icons.edit_outlined;
    }
    if (action.contains('create')) return Icons.add_circle_outline;
    return Icons.bolt;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.admin == null
              ? 'Nhật ký thao tác'
              : 'Nhật ký · ${widget.admin}',
        ),
      ),
      body: PagedList(
        key: _list,
        fetch: _fetch,
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SearchField(
            hint: 'Hành động, admin, đối tượng',
            onChanged: (v) {
              _q = v;
              _list.currentState?.refresh();
            },
          ),
        ),
        itemBuilder: (context, a, _) {
          final action = str(a['action']);
          return ListTile(
            dense: true,
            leading: Icon(
              _icon(action),
              color: action.contains('delete') || action.contains('ban')
                  ? AppColors.danger
                  : AppColors.dim,
            ),
            title: Text('${str(a['admin'])} · $action'),
            subtitle: Text(
              '${str(a['target_type'])} ${str(a['target_id'])}\n${fmtDate(a['timestamp'])} · ${str(a['ip'])}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            onTap: () => showJsonSheet(context, action, a),
          );
        },
      ),
    );
  }
}

class ErrorLogsScreen extends StatefulWidget {
  const ErrorLogsScreen({super.key});
  @override
  State<ErrorLogsScreen> createState() => _ErrorLogsScreenState();
}

class _ErrorLogsScreenState extends State<ErrorLogsScreen> {
  final _list = GlobalKey<PagedListState>();
  String _level = '';

  Future<({List<Map<String, dynamic>> rows, bool hasMore, int? total})> _fetch(
    int page,
  ) async {
    final r = await AdminApi.I.get(
      'm/error-logs/',
      query: {'page': page, 'level': _level},
    );
    return (
      rows: asList(r['rows']),
      hasMore: r['has_more'] == true,
      total: r['total'] as int?,
    );
  }

  Future<void> _clear() async {
    final v = await promptFields(
      context,
      'Xoá nhật ký lỗi',
      ['Chỉ xoá log cũ hơn N ngày (0 = xoá hết)'],
      initial: ['7'],
      ok: 'Xoá',
    );
    if (v == null) return;
    final r = await runAction(
      () => AdminApi.I.post(
        'm/error-logs/',
        body: {'older_than_days': int.tryParse(v[0]) ?? 7},
      ),
    );
    if (r != null) _list.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = context.watch<Session>().can('error_logs.delete');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhật ký lỗi'),
        actions: [
          if (canDelete)
            IconButton(
              onPressed: _clear,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Dọn log',
            ),
        ],
      ),
      body: PagedList(
        key: _list,
        fetch: _fetch,
        emptyText: 'Không có lỗi nào 🎉',
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '', label: Text('Tất cả')),
              ButtonSegment(value: 'critical', label: Text('Critical')),
              ButtonSegment(value: 'error', label: Text('Error')),
              ButtonSegment(value: 'warning', label: Text('Warning')),
            ],
            selected: {_level},
            showSelectedIcon: false,
            onSelectionChanged: (v) {
              setState(() => _level = v.first);
              _list.currentState?.refresh();
            },
          ),
        ),
        itemBuilder: (context, e, _) => ListTile(
          dense: true,
          leading: Icon(
            Icons.error_outline,
            color: e['level'] == 'warning'
                ? AppColors.warning
                : AppColors.danger,
          ),
          title: Text(
            str(e['message']),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${str(e['method'])} ${str(e['path'])} · ${timeAgo(e['timestamp'])}',
          ),
          onTap: () => showJsonSheet(context, 'Lỗi', e),
        ),
      ),
    );
  }
}
