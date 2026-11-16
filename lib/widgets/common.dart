import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/theme.dart';

final messengerKey = GlobalKey<ScaffoldMessengerState>();

void toast(String msg, {bool error = false}) {
  messengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : AppColors.surface2,
        duration: Duration(seconds: error ? 4 : 2),
      ),
    );
}

/// Runs an API action, shows its message / error, returns the response or null.
Future<Map<String, dynamic>?> runAction(
  Future<Map<String, dynamic>> Function() fn, {
  String? success,
}) async {
  try {
    final r = await fn();
    toast(success ?? (r['message']?.toString() ?? 'Đã thực hiện'));
    return r;
  } on ApiException catch (e) {
    toast(e.message, error: true);
  } catch (e) {
    toast('$e', error: true);
  }
  return null;
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String ok = 'Xác nhận',
  bool danger = true,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger ? AppColors.danger : AppColors.primary,
          ),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Dialog with one or more text fields; returns values or null when cancelled.
Future<List<String>?> promptFields(
  BuildContext context,
  String title,
  List<String> labels, {
  List<String>? initial,
  String ok = 'Lưu',
  List<bool>? multiline,
}) async {
  final ctrls = [
    for (var i = 0; i < labels.length; i++)
      TextEditingController(text: initial?[i] ?? ''),
  ];
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: ctrls[i],
                  maxLines: (multiline?[i] ?? false) ? 4 : 1,
                  decoration: InputDecoration(labelText: labels[i]),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Huỷ'),
        ),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  final values = ctrls.map((e) => e.text).toList();
  for (final c in ctrls) {
    c.dispose();
  }
  return r == true ? values : null;
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.dim),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ],
      ),
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView(this.message, {super.key, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: AppColors.dim)),
        ],
      ),
    ),
  );
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color = AppColors.dim, this.icon});
  final String label;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.url, this.name = '', this.size = 40});
  final String? url;
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primary.withValues(alpha: 0.3),
      child: Text(
        initial,
        style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w700),
      ),
    );
    final u = url ?? '';
    if (u.startsWith('data:image')) {
      try {
        final bytes = base64Decode(u.substring(u.indexOf(',') + 1));
        return ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        return fallback;
      }
    }
    if (!u.startsWith('http')) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: u,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => fallback,
        placeholder: (_, _) => fallback,
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.dim, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class KV extends StatelessWidget {
  const KV(this.k, this.v, {super.key, this.copy = false});
  final String k;
  final String v;
  final bool copy;
  @override
  Widget build(BuildContext context) => InkWell(
    onLongPress: () {
      Clipboard.setData(ClipboardData(text: v));
      toast('Đã sao chép');
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              k,
              style: const TextStyle(color: AppColors.dim, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(v, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    ),
  );
}

/// Search box with debounce.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Tìm kiếm...',
  });
  final ValueChanged<String> onChanged;
  final String hint;
  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _c = TextEditingController();
  Timer? _t;
  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _c,
    textInputAction: TextInputAction.search,
    onSubmitted: widget.onChanged,
    onChanged: (v) {
      _t?.cancel();
      _t = Timer(
        const Duration(milliseconds: 450),
        () => widget.onChanged(v.trim()),
      );
      setState(() {});
    },
    decoration: InputDecoration(
      hintText: widget.hint,
      prefixIcon: const Icon(Icons.search),
      suffixIcon: _c.text.isEmpty
          ? null
          : IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _c.clear();
                widget.onChanged('');
                setState(() {});
              },
            ),
    ),
  );
}

typedef PageFetcher =
    Future<({List<Map<String, dynamic>> rows, bool hasMore, int? total})>
    Function(int page);

/// Infinite scrolling list with pull-to-refresh, driven by a page fetcher.
class PagedList extends StatefulWidget {
  const PagedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.header,
    this.emptyText = 'Không có dữ liệu',
    this.separated = true,
    this.onTotal,
  });
  final PageFetcher fetch;
  final Widget Function(BuildContext, Map<String, dynamic>, int) itemBuilder;
  final Widget? header;
  final String emptyText;
  final bool separated;
  final ValueChanged<int?>? onTotal;

  @override
  State<PagedList> createState() => PagedListState();
}

class PagedListState extends State<PagedList> {
  final items = <Map<String, dynamic>>[];
  final _scroll = ScrollController();
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
    });
    refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    _gen++;
    setState(() {
      items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    await _loadMore();
  }

  void removeWhere(bool Function(Map<String, dynamic>) test) =>
      setState(() => items.removeWhere(test));
  void update() => setState(() {});

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final gen = _gen;
    setState(() => _loading = true);
    try {
      final r = await widget.fetch(_page + 1);
      if (!mounted || gen != _gen) return;
      setState(() {
        _page++;
        items.addAll(r.rows);
        _hasMore = r.hasMore && r.rows.isNotEmpty;
        _loading = false;
      });
      if (_page == 1) widget.onTotal?.call(r.total);
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    Widget body;
    if (items.isEmpty && _loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (items.isEmpty && _error != null) {
      body = ErrorView(_error!, onRetry: refresh);
    } else if (items.isEmpty) {
      body = ListView(
        children: [const SizedBox(height: 80), EmptyView(widget.emptyText)],
      );
    } else {
      final count = items.length + 1;
      Widget tail(BuildContext c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : _error != null
              ? TextButton(
                  onPressed: _loadMore,
                  child: Text('Lỗi: $_error — thử lại'),
                )
              : Text(
                  _hasMore ? '' : 'Đã hết · ${items.length} mục',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
        ),
      );
      body = widget.separated
          ? ListView.separated(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: count,
              separatorBuilder: (_, i) => i < items.length - 1
                  ? const Divider(indent: 16, endIndent: 16)
                  : const SizedBox(),
              itemBuilder: (c, i) => i == items.length
                  ? tail(c)
                  : widget.itemBuilder(c, items[i], i),
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: count,
              itemBuilder: (c, i) => i == items.length
                  ? tail(c)
                  : widget.itemBuilder(c, items[i], i),
            );
    }
    return Column(
      children: [
        ?header,
        Expanded(
          child: RefreshIndicator(onRefresh: refresh, child: body),
        ),
      ],
    );
  }
}

/// Collapsible JSON tree for raw Mongo documents.
class JsonView extends StatelessWidget {
  const JsonView(this.data, {super.key});
  final dynamic data;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: _entries(data, 0),
  );

  List<Widget> _entries(dynamic v, int depth) {
    if (v is Map) {
      return [
        for (final e in v.entries) _node(e.key.toString(), e.value, depth),
      ];
    }
    if (v is List) {
      return [for (var i = 0; i < v.length; i++) _node('[$i]', v[i], depth)];
    }
    return [Text('$v')];
  }

  Widget _node(String key, dynamic value, int depth) {
    final pad = EdgeInsets.only(left: 12.0 * depth);
    if (value is Map || value is List) {
      final len = value is Map ? value.length : (value as List).length;
      return Padding(
        padding: pad,
        child: ExpansionTile(
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding: EdgeInsets.zero,
          shape: const Border(),
          title: Text(
            '$key  ${value is Map ? '{$len}' : '[$len]'}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.info,
              fontFamily: 'monospace',
            ),
          ),
          children: _entries(value, depth + 1),
        ),
      );
    }
    final color = value == null
        ? AppColors.muted
        : value is bool
        ? AppColors.warning
        : value is num
        ? AppColors.success
        : AppColors.text;
    return Padding(
      padding: pad.add(const EdgeInsets.symmetric(horizontal: 4, vertical: 4)),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$key: ',
              style: const TextStyle(color: AppColors.dim),
            ),
            TextSpan(
              text: value is String ? '"$value"' : '$value',
              style: TextStyle(color: color),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
      ),
    );
  }
}

Future<void> showJsonSheet(
  BuildContext context,
  String title,
  dynamic data, {
  List<Widget> actions = const [],
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (c, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Sao chép JSON',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text: const JsonEncoder.withIndent('  ').convert(data),
                      ),
                    );
                    toast('Đã sao chép JSON');
                  },
                ),
                ...actions,
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(12),
              children: [JsonView(data)],
            ),
          ),
        ],
      ),
    ),
  );
}
