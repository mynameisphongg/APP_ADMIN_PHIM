import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../widgets/common.dart';
import 'admins_screen.dart';
import 'collection_screen.dart';
import 'logs_screen.dart';
import 'system_screens.dart';

class _Item {
  const _Item(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.perm,
    this.builder,
  );
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String perm;
  final Widget Function() builder;
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final admin = s.admin!;
    final groups = <(String, List<_Item>)>[
      (
        'Nội dung & cộng đồng',
        [
          _Item(
            'Gửi thông báo',
            'Broadcast tới người dùng + push',
            Icons.campaign_outlined,
            AppColors.accent,
            'notifications.edit',
            () => const BroadcastScreen(),
          ),
          _Item(
            'Lịch sử xem',
            'Watch progress',
            Icons.play_circle_outline,
            AppColors.success,
            'watch_progress.view',
            () => const CollectionScreen(
              collection: 'watchprogresses',
              label: 'Lịch sử xem',
            ),
          ),
          _Item(
            'Lịch sử tìm kiếm',
            'Search history',
            Icons.manage_search,
            AppColors.info,
            'search_history.view',
            () => const CollectionScreen(
              collection: 'searchhistories',
              label: 'Lịch sử tìm kiếm',
            ),
          ),
          _Item(
            'Lịch sử stream',
            'Nguồn phát đã dùng',
            Icons.stream,
            AppColors.info,
            'stream_history.view',
            () => const CollectionScreen(
              collection: 'streamhistories',
              label: 'Lịch sử stream',
            ),
          ),
          _Item(
            'Thông báo đã gửi',
            'Notifications',
            Icons.notifications_none,
            AppColors.dim,
            'notifications.view',
            () => const CollectionScreen(
              collection: 'notifications',
              label: 'Thông báo',
            ),
          ),
          _Item(
            'Phiên đăng nhập',
            'Sessions của người dùng',
            Icons.devices_outlined,
            AppColors.dim,
            'sessions.view',
            () => const CollectionScreen(
              collection: 'sessions',
              label: 'Phiên đăng nhập',
            ),
          ),
          _Item(
            'Game',
            'Hồ sơ & trận đấu',
            Icons.sports_esports_outlined,
            AppColors.warning,
            'games.view',
            () => const CollectionScreen(
              collection: 'gameprofiles',
              label: 'Hồ sơ game',
            ),
          ),
          _Item(
            'Thử thách hằng ngày',
            'Daily challenge',
            Icons.emoji_events_outlined,
            AppColors.warning,
            'daily_challenge.view',
            () => const CollectionScreen(
              collection: 'dailychallenges',
              label: 'Daily challenge',
            ),
          ),
        ],
      ),
      (
        'Hệ thống',
        [
          _Item(
            'Server phát phim',
            'VidSrc, KKPhim, NguonC',
            Icons.dns_outlined,
            AppColors.success,
            'servers.view',
            () => const ServersScreen(),
          ),
          _Item(
            'Cache Upstash',
            'Xem / xoá cache TMDB',
            Icons.memory,
            AppColors.info,
            'cache.view',
            () => const CacheScreen(),
          ),
          _Item(
            'Cấu hình nền tảng',
            'Bảo trì, đăng ký, giới hạn',
            Icons.tune,
            AppColors.primary,
            'settings.view',
            () => const SettingsScreen(),
          ),
          _Item(
            'Dữ liệu MongoDB',
            'Duyệt mọi collection',
            Icons.storage,
            AppColors.dim,
            'dashboard.view',
            () => const CollectionsScreen(),
          ),
          _Item(
            'Token & reset mật khẩu',
            'Password reset / blacklist',
            Icons.key_outlined,
            AppColors.dim,
            'tokens.view',
            () => const CollectionScreen(
              collection: 'passwordresettokens',
              label: 'Token reset mật khẩu',
            ),
          ),
        ],
      ),
      (
        'Quản trị',
        [
          _Item(
            'Quản trị viên',
            'Tài khoản admin & phân quyền',
            Icons.admin_panel_settings_outlined,
            AppColors.primary,
            'admins.view',
            () => const AdminsScreen(),
          ),
          _Item(
            'Nhật ký thao tác',
            'Audit log',
            Icons.receipt_long_outlined,
            AppColors.accent,
            'audit_logs.view',
            () => const AuditLogsScreen(),
          ),
          _Item(
            'Nhật ký lỗi',
            'Error log của admin server',
            Icons.bug_report_outlined,
            AppColors.danger,
            'error_logs.view',
            () => const ErrorLogsScreen(),
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                leading: Avatar(
                  url: admin.raw['avatar']?.toString(),
                  name: admin.username,
                  size: 46,
                ),
                title: Text(
                  admin.username,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${admin.role}${admin.totp ? ' · 2FA bật' : ' · 2FA tắt'}\n${AdminApi.I.origin}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Phiên đăng nhập app',
                  icon: const Icon(Icons.phonelink_lock_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyTokensScreen()),
                  ),
                ),
              ),
            ),
          ),
          for (final g in groups)
            if (g.$2.any((i) => s.can(i.perm))) ...[
              SectionTitle(g.$1),
              for (final i in g.$2.where((i) => s.can(i.perm)))
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: i.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(i.icon, color: i.color, size: 22),
                  ),
                  title: Text(i.title),
                  subtitle: Text(
                    i.subtitle,
                    style: const TextStyle(color: AppColors.dim, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => i.builder())),
                ),
            ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: () async {
                if (await confirm(
                  context,
                  'Đăng xuất?',
                  'Token của thiết bị này sẽ bị thu hồi.',
                  ok: 'Đăng xuất',
                )) {
                  if (context.mounted) await context.read<Session>().logout();
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
            ),
          ),
        ],
      ),
    );
  }
}
