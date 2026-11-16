import 'package:material_ui/material_ui.dart';

import '../core/api.dart';

class Admin {
  Admin(this.raw);
  final Map<String, dynamic> raw;
  String get username => raw['username']?.toString() ?? '';
  String get role => raw['role']?.toString() ?? '';
  String get email => raw['email']?.toString() ?? '';
  bool get isSuper => raw['is_super_admin'] == true;
  bool get totp => raw['totp_enabled'] == true;
  Set<String> get perms => {
    ...((raw['permissions'] as List?) ?? const []).map((e) => e.toString()),
  };
}

class Session extends ChangeNotifier {
  Admin? admin;
  bool ready = false;

  bool get loggedIn => admin != null;
  bool can(String perm) => admin?.perms.contains(perm) ?? false;

  Future<void> init() async {
    AdminApi.I.onUnauthorized = _drop;
    await AdminApi.I.load();
    if (AdminApi.I.hasToken) {
      try {
        final r = await AdminApi.I.get('m/me/');
        admin = Admin(Map<String, dynamic>.from(r['admin']));
      } on ApiException catch (e) {
        if (e.status == 401 || e.status == 403) await AdminApi.I.setToken(null);
      } catch (_) {}
    }
    ready = true;
    notifyListeners();
  }

  /// Returns true when the server asks for a 2FA code.
  Future<bool> login(
    String origin,
    String username,
    String password, {
    String? otp,
  }) async {
    await AdminApi.I.setOrigin(origin);
    await AdminApi.I.setToken(null);
    final r = await AdminApi.I.post(
      'm/auth/login/',
      body: {
        'username': username,
        'password': password,
        if (otp != null && otp.isNotEmpty) 'otp': otp,
        'device': 'MovieSaw Admin App',
      },
    );
    if (r['requires_2fa'] == true && r['token'] == null) return true;
    await AdminApi.I.setToken(r['token'].toString());
    admin = Admin(Map<String, dynamic>.from(r['admin']));
    notifyListeners();
    return false;
  }

  Future<void> refreshMe() async {
    final r = await AdminApi.I.get('m/me/');
    admin = Admin(Map<String, dynamic>.from(r['admin']));
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await AdminApi.I.post('m/auth/logout/');
    } catch (_) {}
    await _drop();
  }

  Future<void> _drop() async {
    await AdminApi.I.setToken(null);
    if (admin != null) {
      admin = null;
      notifyListeners();
    }
  }
}
