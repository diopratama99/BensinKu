import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Masthead
                  Row(
                    children: [
                      Text('BENSINKU',
                          style: AppEditorial.mono(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          )),
                      const SizedBox(width: 10),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppEditorial.butter,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('VOL.01 · LOGIN',
                          style: AppEditorial.eyebrow()),
                    ],
                  ),
                  const SizedBox(height: 60),
                  Text(
                    'Masuk ke akun.',
                    style: AppEditorial.mono(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Catat ulang pengisian, lihat statistik bulan ini.',
                    style: AppEditorial.sans(
                      fontSize: 13,
                      color: AppEditorial.inkSoft,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Container(height: 1, color: AppEditorial.ink),
                  const SizedBox(height: 28),

                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    style:
                        AppEditorial.mono(fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      labelText: 'EMAIL',
                      hintText: 'contoh@email.com',
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    style:
                        AppEditorial.mono(fontSize: 15, fontWeight: FontWeight.w500),
                    onSubmitted: (_) => _busy ? null : _signIn(),
                    decoration: InputDecoration(
                      labelText: 'PASSWORD',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppEditorial.inkSoft,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ForgotPasswordPage(),
                        ),
                      ),
                      child: const Text('LUPA PASSWORD?'),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    _ErrorBox(message: _error!),
                  ],

                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _signIn,
                    child: _busy
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppEditorial.canvas,
                            ),
                          )
                        : const Text('MASUK →'),
                  ),
                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('belum punya akun? ',
                          style: AppEditorial.sans(
                            fontSize: 13,
                            color: AppEditorial.inkSoft,
                          )),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SignUpPage(),
                          ),
                        ),
                        child: Text(
                          'daftar.',
                          style: AppEditorial.mono(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ).copyWith(
                            decoration: TextDecoration.underline,
                            decorationColor: AppEditorial.ink,
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppEditorial.rust, width: 1),
        borderRadius: BorderRadius.circular(AppEditorial.rTiny),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppEditorial.rust, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppEditorial.sans(
                fontSize: 12.5,
                color: AppEditorial.rust,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
