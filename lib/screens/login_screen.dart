import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../state/session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _server = TextEditingController(text: AdminApi.I.origin);
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _otp = TextEditingController();
  bool _need2fa = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_server, _user, _pass, _otp]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_server.text.trim().isEmpty ||
        _user.text.trim().isEmpty ||
        _pass.text.isEmpty) {
      setState(
        () => _error = 'Nhập đủ địa chỉ server, tên đăng nhập và mật khẩu',
      );
      return;
    }
    if (_need2fa && _otp.text.trim().isEmpty) {
      setState(() => _error = 'Nhập mã 2FA (6 số) hoặc mã dự phòng');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final needs = await context.read<Session>().login(
        _server.text,
        _user.text.trim(),
        _pass.text,
        otp: _need2fa ? _otp.text.trim() : null,
      );
      if (needs && mounted) setState(() => _need2fa = true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          if (e.data?['requires_2fa'] == true) _need2fa = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'MovieSaw Admin',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Đăng nhập bằng tài khoản quản trị (admin_dashboard)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.dim),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _server,
                      keyboardType: TextInputType.url,
                      enabled: !_need2fa,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ server admin',
                        hintText: 'https://admin.example.com',
                        prefixIcon: Icon(Icons.dns_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _user,
                      enabled: !_need2fa,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Tên đăng nhập',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      enabled: !_need2fa,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    if (_need2fa) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _otp,
                        autofocus: true,
                        keyboardType: TextInputType.visiblePassword,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        onSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Mã 2FA / mã dự phòng',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_need2fa ? 'Xác thực' : 'Đăng nhập'),
                    ),
                    if (_need2fa)
                      TextButton(
                        onPressed: () => setState(() {
                          _need2fa = false;
                          _otp.clear();
                          _error = null;
                        }),
                        child: const Text('Quay lại'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
