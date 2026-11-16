import 'package:flutter_test/flutter_test.dart';
import 'package:moviesaw_admin/core/api.dart';
import 'package:moviesaw_admin/core/format.dart';
import 'package:moviesaw_admin/state/session.dart';

void main() {
  test('normalizeOrigin accepts bare host, trailing slash and /dashboard', () {
    expect(AdminApi.normalizeOrigin('admin.example.com'), 'https://admin.example.com');
    expect(AdminApi.normalizeOrigin('http://10.0.2.2:8000/'), 'http://10.0.2.2:8000');
    expect(AdminApi.normalizeOrigin('https://x.io/dashboard/'), 'https://x.io');
  });

  test('idOf handles string and \$oid ids', () {
    expect(idOf({'_id': 'abc'}), 'abc');
    expect(idOf({'_id': {r'$oid': 'def'}}), 'def');
    expect(idOf({'id': 5}), '5');
  });

  test('parseDate treats naive datetimes as UTC', () {
    final d = parseDate('2026-01-02T03:04:05')!;
    expect(d.toUtc(), DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(parseDate('2026-01-02T03:04:05Z')!.toUtc(), DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(parseDate(null), isNull);
  });

  test('Admin permissions drive Session.can', () {
    final s = Session()
      ..admin = Admin({
        'username': 'mod',
        'role': 'moderator',
        'permissions': ['users.view', 'comments.delete'],
      });
    expect(s.can('users.view'), isTrue);
    expect(s.can('settings.edit'), isFalse);
  });
}
