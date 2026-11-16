import 'package:intl/intl.dart';

DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  if (v is Map && v[r'$date'] != null) return parseDate(v[r'$date']);
  if (v is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      v > 1e12 ? v.toInt() : (v * 1000).toInt(),
    );
  }
  final s = v.toString();
  if (s.isEmpty) return null;
  var d = DateTime.tryParse(s);
  // Naive datetimes from Django/Mongo are UTC.
  if (d != null && !d.isUtc && !RegExp(r'(Z|[+-]\d\d:?\d\d)$').hasMatch(s)) {
    d = DateTime.utc(
      d.year,
      d.month,
      d.day,
      d.hour,
      d.minute,
      d.second,
      d.millisecond,
    );
  }
  return d?.toLocal();
}

String fmtDate(dynamic v, {bool time = true}) {
  final d = parseDate(v);
  if (d == null) return '—';
  return DateFormat(time ? 'dd/MM/yyyy HH:mm' : 'dd/MM/yyyy').format(d);
}

String timeAgo(dynamic v) {
  final d = parseDate(v);
  if (d == null) return '—';
  final diff = DateTime.now().difference(d);
  if (diff.isNegative) return fmtDate(v);
  if (diff.inSeconds < 60) return 'vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  if (diff.inDays < 30) return '${diff.inDays} ngày trước';
  return fmtDate(v, time: false);
}

final _num = NumberFormat.decimalPattern('vi');

String fmtNum(dynamic v) {
  if (v == null) return '0';
  if (v is num) return _num.format(v);
  final n = num.tryParse(v.toString());
  return n == null ? v.toString() : _num.format(n);
}

String str(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  final s = v.toString();
  return s.isEmpty ? fallback : s;
}

/// Mongo `_id` may come as a string or `{"$oid": ...}`.
String idOf(Map m) {
  final v = m['_id'] ?? m['id'];
  if (v is Map && v[r'$oid'] != null) return v[r'$oid'].toString();
  return str(v);
}

Map<String, dynamic> asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> asList(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];
