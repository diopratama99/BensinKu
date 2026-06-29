import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../services/google_auth_service.dart';
import 'forgot_password_page.dart';
import 'sign_up_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    if (email.isEmpty) {
      setState(() => _error = 'Email wajib diisi');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Password wajib diisi');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('email not confirmed')) {
        setState(() => _error =
            'Email belum diverifikasi. Cek inbox/spam.');
      } else if (msg.contains('invalid login') ||
          msg.contains('invalid credentials')) {
        setState(() => _error = 'Email atau password salah.');
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await GoogleAuthService.signIn();
      // res == null → user cancelled the picker; stay silent.
      // On success, _AuthGate reacts to the session change and routes on.
      if (res == null && mounted) {
        setState(() => _busy = false);
      }
    } on GoogleAuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand lockup
                  const AuthBrandMark(),
                  const SizedBox(height: 24),

                  // Hero illustration
                  AspectRatio(
                    aspectRatio: 1080 / 720,
                    child: Image.asset(
                      'assets/illustrations/auth_pump.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Masuk ke akun',
                    style: AppEditorial.heading(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Catat ulang pengisian, lihat statistik bulan ini.',
                    style: AppEditorial.sans(
                      fontSize: 13.5,
                      color: AppEditorial.inkSoft,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppEditorial.cream,
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rCard),
                      boxShadow: AppEditorial.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'contoh@email.com',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _busy ? null : _signIn(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? PhosphorIconsRegular.eyeSlash
                                    : PhosphorIconsRegular.eye,
                                color: AppEditorial.inkSoft,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ForgotPasswordPage(),
                              ),
                            ),
                            child: const Text('Lupa password?'),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 6),
                          _ErrorBox(message: _error!),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _busy ? null : _signIn,
                          child: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                )
                              : const Text('Masuk'),
                        ),

                        // Google sign-in — only shown when configured.
                        if (GoogleAuthService.isConfigured) ...[
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(
                                    color: AppEditorial.hairline),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Text('atau',
                                    style: AppEditorial.sans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppEditorial.inkMuted,
                                    )),
                              ),
                              const Expanded(
                                child: Divider(
                                    color: AppEditorial.hairline),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _GoogleButton(
                            onPressed: _busy ? null : _signInWithGoogle,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Belum punya akun? ',
                          style: AppEditorial.sans(
                            fontSize: 13.5,
                            color: AppEditorial.inkSoft,
                          )),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SignUpPage(),
                          ),
                        ),
                        child: Text(
                          'Daftar',
                          style: AppEditorial.sans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppEditorial.brandDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wordmark BensinKu — ikon pompa dalam kotak rounded brandTint.
class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key, this.center = false});

  final bool center;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment:
          center ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppEditorial.brandTint,
            borderRadius: BorderRadius.circular(AppEditorial.rTiny),
          ),
          child: const Icon(
            PhosphorIconsRegular.gasPump,
            color: AppEditorial.brandDeep,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'BensinKu',
          style: AppEditorial.heading(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppEditorial.hairline, width: 1.4),
        padding: const EdgeInsets.symmetric(vertical: 15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Simple "G" mark — avoids bundling a logo asset.
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppEditorial.canvasSoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              'G',
              style: AppEditorial.heading(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppEditorial.brandDeep,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('Lanjut dengan Google'),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppEditorial.rustSoft,
        borderRadius: BorderRadius.circular(AppEditorial.rTiny),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(PhosphorIconsRegular.warningCircle,
              color: AppEditorial.rust, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppEditorial.sans(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppEditorial.rust,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
