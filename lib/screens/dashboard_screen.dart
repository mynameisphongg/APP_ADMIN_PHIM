import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../widgets/common.dart';
import 'user_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await AdminApi.I.get(
        'overview/',
        query: {if (force) 'refresh': '1'},
      );
      if (mounted) setState(() => _data = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<Session>().admin;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tổng quan'),
            Text(
              'Xin chào ${admin?.username ?? ''} · ${admin?.role ?? ''}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.dim,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loading ? null : () => _load(force: true),
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _data == null
          ? (_error != null
                ? ErrorView(_error!, onRetry: _load)
                : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: () => _load(force: true),
              child: _body(_data!),
            ),
    );
  }

  Widget _body(Map<String, dynamic> d) {
    final mongo = asMap(d['mongo']);
    final counts = asMap(mongo['counts']);
    final stats = asMap(mongo['stats']);
    final weekly = asList(mongo['weekly_activity']);
    final health = asMap(d['server_health']);
    final arena = asMap(d['arena_health']);
    final growth = (stats['weekly_growth_pct'] as num?) ?? 0;

    final cards = <(String, dynamic, IconData, Color)>[
      (
        'Người dùng',
        counts['users'],
        Icons.people_alt_rounded,
        AppColors.primary,
      ),
      ('Bình luận', counts['comments'], Icons.forum_rounded, AppColors.accent),
      (
        'Phiên đăng nhập',
        counts['sessions'],
        Icons.devices_rounded,
        AppColors.info,
      ),
      (
        'Lượt xem (progress)',
        counts['watchprogresses'],
        Icons.play_circle_fill_rounded,
        AppColors.success,
      ),
      (
        'Báo cáo vi phạm',
        counts['userreports'],
        Icons.flag_rounded,
        AppColors.warning,
      ),
      (
        'Thông báo',
        counts['notifications'],
        Icons.notifications_rounded,
        AppColors.dim,
      ),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (mongo['error'] != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'MongoDB: ${mongo['error']}',
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              for (final c in cards)
                StatCard(
                  label: c.$1,
                  value: fmtNum(c.$2),
                  icon: c.$3,
                  color: c.$4,
                ),
            ],
          ),
        ),
        const SectionTitle('Người dùng'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  _mini(
                    'Đã xác minh',
                    stats['verified_users'],
                    AppColors.success,
                  ),
                  _mini(
                    'Chưa xác minh',
                    stats['unverified_users'],
                    AppColors.warning,
                  ),
                  _mini('Bị cấm', stats['banned_users'], AppColors.danger),
                ],
              ),
            ),
          ),
        ),
        SectionTitle(
          'Hoạt động 7 ngày',
          trailing: Pill(
            '${growth >= 0 ? '+' : ''}$growth% so với tuần trước',
            color: growth >= 0 ? AppColors.success : AppColors.danger,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: _WeeklyChart(weekly),
            ),
          ),
        ),
        const SectionTitle('Trạng thái hệ thống'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Column(
              children: [
                _health(
                  'API server (Node)',
                  health['ok'] == true,
                  health['ok'] == true
                      ? 'HTTP ${health['status_code']}'
                      : str(health['error'], 'offline'),
                ),
                const Divider(),
                _health(
                  'MongoDB',
                  mongo['enabled'] == true && mongo['error'] == null,
                  mongo['error']?.toString() ?? 'kết nối OK',
                ),
                const Divider(),
                _health(
                  'Game / Arena server',
                  arena['ok'] != false && arena['error'] == null,
                  str(arena['error'], 'online'),
                ),
              ],
            ),
          ),
        ),
        const SectionTitle('Người dùng mới'),
        for (final u in asList(mongo['recent_users']))
          ListTile(
            leading: Avatar(
              url: str(u['avatar']),
              name: str(u['name'], str(u['email'])),
            ),
            title: Text(str(u['name'], '(chưa đặt tên)')),
            subtitle: Text(str(u['email'])),
            trailing: Text(
              timeAgo(u['createdAt']),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UserDetailScreen(userId: idOf(u)),
              ),
            ),
          ),
        const SectionTitle('Bình luận gần đây'),
        for (final c in asList(mongo['recent_comments']))
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: Text(
              str(c['content']),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${str(asMap(c['user'])['name'], 'Ẩn danh')} · ${str(c['type'])} #${str(c['movieId'])}',
            ),
            trailing: c['isDeleted'] == true
                ? const Pill('Đã ẩn', color: AppColors.danger)
                : null,
          ),
        const SectionTitle('Nội dung được xem nhiều'),
        for (final m in asList(mongo['trending_media']))
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: str(m['poster_path']).isEmpty
                  ? const SizedBox(
                      width: 36,
                      height: 54,
                      child: ColoredBox(color: AppColors.surface2),
                    )
                  : Image.network(
                      'https://image.tmdb.org/t/p/w92${m['poster_path']}',
                      width: 36,
                      height: 54,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const SizedBox(width: 36, height: 54),
                    ),
            ),
            title: Text(str(m['title'], '#${m['_id']}')),
            subtitle: Text(m['isTVShow'] == true ? 'Phim bộ' : 'Phim lẻ'),
            trailing: Text(
              '${fmtNum(m['views'])} lượt',
              style: const TextStyle(color: AppColors.dim),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Django ${asMap(d['system_info'])['django_version'] ?? ''} · ${AdminApi.I.origin}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _mini(String label, dynamic v, Color color) => Expanded(
    child: Column(
      children: [
        Text(
          fmtNum(v),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.dim, fontSize: 12)),
      ],
    ),
  );

  Widget _health(String name, bool ok, String detail) => ListTile(
    dense: true,
    leading: Icon(
      ok ? Icons.check_circle : Icons.error,
      color: ok ? AppColors.success : AppColors.danger,
    ),
    title: Text(name),
    subtitle: Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
  );
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart(this.days);
  final List<Map<String, dynamic>> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const Text(
        'Chưa có dữ liệu',
        style: TextStyle(color: AppColors.dim),
      );
    }
    final maxTotal = days
        .map((d) => (d['total'] as num?) ?? 0)
        .fold<num>(1, (a, b) => b > a ? b : a);
    const series = [
      ('new_users', 'Người dùng mới', AppColors.primary),
      ('comments', 'Bình luận', AppColors.accent),
      ('watches', 'Lượt xem', AppColors.info),
    ];
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in days)
                Expanded(
                  child: Tooltip(
                    message:
                        '${d['date']}\n${series.map((s) => '${s.$2}: ${d[s.$1] ?? 0}').join('\n')}',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${d['total'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.dim,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 18,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (final s in series.reversed)
                                Container(
                                  height:
                                      104 *
                                      (((d[s.$1] as num?) ?? 0) / maxTotal),
                                  color: s.$3,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final d in days)
              Expanded(
                child: Center(
                  child: Text(
                    str(d['label']),
                    style: const TextStyle(fontSize: 11, color: AppColors.dim),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          children: [
            for (final s in series)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.$3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    s.$2,
                    style: const TextStyle(fontSize: 12, color: AppColors.dim),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
